"""
services/trip_planner.py
TripPlannerService – orchestrates the full planning pipeline:

  [Filtering]   fetch_places_required_filter → filter_places_with_fallback
  [Module 1]    fetch tags + user interest → rank_places_by_tag_match
  [CF Blend]    fetch_cf_scores_for_user → dynamic alpha blend → re-sort
  [Diversity]   apply_diversity_selection (slot-based subcategory allocation)
  [Module 2]    build_module2_result (K-Means + Greedy Repair)
  [Module 3]    optimize_day_route (SA with schedule-aware cost + time windows)
  [Persist]     save_plan

Trip-level interest (optional):
  If interest_option_ids is supplied, trip_planner fetches the matching
  trip_interest_option rows and their tag/subcategory mappings, blends them
  with the user's onboarding-level interest state via build_effective_interest_state(),
  and passes trip_selected_options + trip_option_subcategory_rows to
  apply_diversity_selection() for subcategory-slot boosting.
  If interest_option_ids is absent or empty, the pipeline is identical to
  the previous behaviour (onboarding-level only).
"""

import datetime

from db.place_repository import fetch_places_required_filter
from db.queries_plan import save_plan
from services.filters import filter_places_with_fallback
from services.module1_algorithm import (
    build_effective_interest_state,
    build_trip_interest_profile,
    build_user_interest_state_from_rows,
    rank_places_by_tag_match,
)
from services.module1_diversity import apply_diversity_selection
from services.module1_repository import (
    attach_place_tags_to_places,
    build_tag_map,
    fetch_active_tags,
    fetch_already_rated_places,
    fetch_cf_scores_for_user,
    fetch_place_tags_for_places,
    fetch_trip_interest_option_subcategories,
    fetch_trip_interest_option_tags,
    fetch_trip_interest_options_by_ids,
    fetch_user_interest_tags,
    fetch_user_onboarding_choices,
    fetch_user_travel_profile,
)
from services.module2_algorithm import build_module2_result
from services.module3_optimizer import optimize_day_route


def _compute_alpha(cf_scores: dict, total_places: int) -> float:
    if total_places == 0:
        return 1.0
    coverage = len(cf_scores) / total_places
    if coverage == 0:    return 1.0
    if coverage < 0.10:  return 0.7
    if coverage < 0.30:  return 0.5
    return 0.3


def _derive_start_point(places: list) -> dict:
    if not places:
        return {"latitude": 16.0, "longitude": 108.0}
    avg_lat = sum(float(p["latitude"])  for p in places) / len(places)
    avg_lon = sum(float(p["longitude"]) for p in places) / len(places)
    return {"latitude": avg_lat, "longitude": avg_lon}


def _format_place(place: dict, order: int) -> dict:
    return {
        "type":                       "place",
        "order":                      order,
        "id_place":                   str(place["id_place"]),
        "name":                       place.get("name"),
        "slot":                       place.get("slot"),
        "start_time":                 place.get("start_time"),
        "end_time":                   place.get("end_time"),
        "warning":                    place.get("warning"),
        "timespan":                   place.get("timespan"),
        "timeclose":                  place.get("timeclose"),
        "latitude":                   place.get("latitude"),
        "longitude":                  place.get("longitude"),
        "estimated_travel_minutes":   place.get("estimated_travel_minutes"),
        "estimated_duration_minutes": place.get("estimated_duration_minutes"),
        "tag_match":                  place.get("tag_match"),
        "cf_score":                   place.get("cf_score"),
        "final_score":                place.get("final_score"),
    }


def _format_lunch_break(entry: dict) -> dict:
    return {
        "type":       "lunch_break",
        "start_time": entry.get("start_time"),
        "end_time":   entry.get("end_time"),
        "slot":       entry.get("slot"),
    }


class TripPlannerService:

    def __init__(self, supabase):
        self.supabase = supabase

    async def plan(
        self,
        id_user:             str,
        id_province:         str,
        n_days:              int,
        start_at:            datetime.date,
        sa_runs:             int        = 5,
        save:                bool       = True,
        interest_option_ids: list[str] | None = None,
    ) -> dict:
        supabase = self.supabase
        end_date = start_at + datetime.timedelta(days=n_days - 1)

        # ── [Filtering] ───────────────────────────────────────────────────────
        required_places = fetch_places_required_filter(supabase, id_province)
        user_profile = fetch_user_travel_profile(supabase, id_user)
        filtered_places, filter_report = filter_places_with_fallback(
            required_places, user_profile or {}, n_days
        )

        # ── [Module 1 – TagMatch] ─────────────────────────────────────────────
        tags = fetch_active_tags(supabase)
        tag_map = build_tag_map(tags)
        # {id_tag (str) → tag_code} for rows that only carry UUID (no nested tag object)
        id_tag_map = {
            str(tag["id_tag"]): tag["tag_code"]
            for tag in tags
            if tag.get("id_tag") and tag.get("tag_code")
        }

        place_ids = [str(p["id_place"]) for p in filtered_places]
        place_tag_rows = fetch_place_tags_for_places(supabase, place_ids)
        places_with_tags = attach_place_tags_to_places(filtered_places, place_tag_rows)

        interest_tag_rows = fetch_user_interest_tags(supabase, id_user)
        already_rated = fetch_already_rated_places(supabase, id_user)
        user_interest_state = build_user_interest_state_from_rows(
            interest_tag_rows, tag_map, id_tag_map
        )

        # ── [Trip-level interest blend] ───────────────────────────────────────
        # Default: onboarding-level only (identical behaviour to before)
        weight_field = "final_weight"
        trip_selected_options = None
        trip_option_subcategory_rows = None

        if interest_option_ids:
            options = fetch_trip_interest_options_by_ids(supabase, interest_option_ids)
            active_options = [o for o in options if o.get("is_active")]
            active_option_ids = [o["id_trip_interest_option"] for o in active_options]

            if active_options:
                # Build synthetic choice rows (no trip_plan FK needed)
                trip_interest_choice_rows = [
                    {
                        "id_trip_interest_option": o["id_trip_interest_option"],
                        "selection_order":         i + 1,
                        "source":                  "user_selected",
                        "trip_interest_option":    o,
                    }
                    for i, o in enumerate(active_options)
                ]

                option_tag_rows         = fetch_trip_interest_option_tags(supabase, active_option_ids)
                option_subcategory_rows = fetch_trip_interest_option_subcategories(supabase, active_option_ids)

                trip_profile = build_trip_interest_profile(
                    trip_interest_choice_rows, option_tag_rows,
                    id_tag_map=id_tag_map,
                )
                effective_result = build_effective_interest_state(
                    user_interest_state,
                    trip_profile["normalized_tag_weights"],
                    trip_profile["trip_tag_info_map"],
                )
                user_interest_state      = effective_result["effective_interest_state"]
                weight_field             = "effective_weight"
                trip_selected_options    = trip_interest_choice_rows
                trip_option_subcategory_rows = option_subcategory_rows

        # ── [Rank by tag match] ───────────────────────────────────────────────
        ranked = rank_places_by_tag_match(
            places_with_tags, user_interest_state,
            weight_field=weight_field,
            id_tag_map=id_tag_map,
        )
        ranked = [p for p in ranked if str(p["id_place"]) not in already_rated]

        # ── [CF Blend] ────────────────────────────────────────────────────────
        cf_scores = fetch_cf_scores_for_user(supabase, id_user, place_ids)
        alpha = _compute_alpha(cf_scores, len(filtered_places))

        for place in ranked:
            tag_match = float(place.get("tag_match") or 0.0)
            cf = cf_scores.get(str(place["id_place"]), 0.0)
            place["cf_score"]   = round(cf, 6)
            place["alpha_used"] = alpha
            place["final_score"] = round(alpha * tag_match + (1 - alpha) * cf, 6)

        ranked.sort(key=lambda p: -p["final_score"])

        # ── [Diversity] ───────────────────────────────────────────────────────
        onboarding_choices = fetch_user_onboarding_choices(supabase, id_user)
        user_selected_interests = [
            c["option_code"] for c in onboarding_choices if c.get("option_code")
        ]

        diversity_result = apply_diversity_selection(
            ranked, n_days, user_selected_interests,
            trip_selected_options=trip_selected_options,
            trip_option_subcategory_rows=trip_option_subcategory_rows,
        )
        top_places = diversity_result["diversified_top_k"]

        # ── [Module 2 – Greedy Repair] ────────────────────────────────────────
        pace_level = (user_profile or {}).get("pace_level")
        m2_result = build_module2_result(
            top_places,
            start_date=str(start_at),
            end_date=str(end_date),
            pace_level=pace_level,
        )
        day_clusters = m2_result["day_clusters"]

        # ── [Module 3 – Route optimization] ───────────────────────────────────
        start_point = _derive_start_point(top_places)
        days = []

        for day_cluster in day_clusters:
            day_places = day_cluster["places"]
            best_route, schedule_result = optimize_day_route(
                start_point, day_places, sa_runs=sa_runs
            )

            formatted   = []
            place_order = 1
            for entry in schedule_result["schedule"]:
                if entry.get("dropped"):
                    continue          # silently excluded — didn't fit the day
                if entry.get("type") == "lunch_break":
                    formatted.append(_format_lunch_break(entry))
                else:
                    formatted.append(_format_place(entry, order=place_order))
                    place_order += 1

            days.append({
                "day":    day_cluster["day"],
                "date":   day_cluster["date"],
                "places": formatted,
            })

            if best_route:
                start_point = best_route[-1]

        # ── [Persist] ─────────────────────────────────────────────────────────
        id_plan = None
        if save and days:
            id_plan = save_plan(supabase, id_user, id_province, n_days, start_at, days)

        return {
            "id_plan": id_plan,
            "days": days,
            "debug": {
                "filter_report":      filter_report,
                "cf_coverage":        round(len(cf_scores) / max(len(filtered_places), 1), 4),
                "alpha":              alpha,
                "weight_field":       weight_field,
                "trip_interest_used": bool(trip_selected_options),
                "m2_summary":         m2_result.get("summary"),
                "diversity_summary":  diversity_result.get("summary", {}).get("final_selected_count"),
            },
        }
