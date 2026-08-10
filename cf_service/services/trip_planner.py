"""
services/trip_planner.py
TripPlannerService – orchestrates the full planning pipeline:

  [Filtering]   fetch_places_required_filter → filter_places_with_fallback
  [Module 1]    fetch tags + user interest → rank_places_by_tag_match
  [CF Blend]    fetch_user_factors/fetch_place_factors → dot-product via
                compute_cf_scores_from_factors → dynamic alpha blend → re-sort
                (reads cf_user_factors/cf_place_factors, not cf_score_cache —
                see module1_repository.py)
  [Diversity]   apply_diversity_selection (slot-based subcategory allocation)
  [Module 2]    build_module2_result (K-Means + Greedy Repair)
  [Module 3]    optimize_day_route (SA with schedule-aware cost + time windows,
                Haversine only — see schedule_builder.py)
  [Travel data] fetch_travel_matrix_both_vehicles (Goong Distance Matrix,
                car + bike) — called ONCE per day AFTER SA has picked the
                final route, never inside the SA loop. Bike travel times
                rebuild the day's final start_time/end_time (via a second
                build_day_schedule() call with travel_time_fn overridden);
                car is display-only. If any edge for either vehicle comes
                back non-OK, the whole day falls back to the original
                Haversine-based schedule from Module 3 (all-or-nothing per
                day — never mixes Goong and Haversine within one day).
                See services/goong_client.py.
  [Persist]     save_plan (also persists per-edge car/bike travel time &
                distance, see db/queries_plan.py)

Trip-level interest (optional):
  If interest_option_ids is supplied, trip_planner fetches the matching
  trip_interest_option rows and their tag/subcategory mappings, blends them
  with the user's onboarding-level interest state via build_effective_interest_state(),
  and passes trip_selected_options + trip_option_subcategory_rows to
  apply_diversity_selection() for subcategory-slot boosting.
  If interest_option_ids is absent or empty, the pipeline is identical to
  the previous behaviour (onboarding-level only).
"""

import asyncio
import datetime
import json
import time

from db.place_repository import fetch_places_near_point, fetch_places_required_filter
from db.queries_plan import save_plan
from services.filters import filter_places_with_fallback
from services.module1_algorithm import (
    build_effective_interest_state,
    build_trip_interest_profile,
    build_user_interest_state_from_rows,
    compute_alpha,
    rank_places_by_tag_match,
)
from services.module1_diversity import apply_diversity_selection
from services.module1_repository import (
    attach_place_tags_to_places,
    build_tag_map,
    compute_cf_scores_from_factors,
    fetch_active_tags,
    fetch_already_rated_places,
    fetch_place_factors,
    fetch_place_tags_for_places,
    fetch_trip_interest_option_subcategories,
    fetch_trip_interest_option_tags,
    fetch_trip_interest_options_by_ids,
    fetch_user_factors,
    fetch_user_interest_tags,
    fetch_user_onboarding_choices,
    fetch_user_travel_profile,
)
from services.goong_client import fetch_travel_matrix_both_vehicles
from services.module2_algorithm import build_module2_result
from services.module3_optimizer import optimize_day_route
# _travel_min (Haversine) is reused as the per-edge fallback for the rare
# "structural" edges Goong data can't cover — see _build_goong_travel_time_fn()
# below. Not exposing a public wrapper in schedule_builder.py for this, since
# this pipeline stage was added without touching that module.
from services.schedule_builder import build_day_schedule, _travel_min


class NoTripCandidatesError(Exception):
    """Raised when a saved trip contains no persistable place."""


def _fetch_initial_inputs(
    supabase,
    id_user: str,
    id_province: str | None,
    target_lat: float | None,
    target_lng: float | None,
):
    """Run blocking reads sequentially on one worker for one sync client."""
    if target_lat is not None and target_lng is not None:
        places = fetch_places_near_point(
            supabase, target_lat, target_lng
        )
    else:
        places = fetch_places_required_filter(supabase, id_province)
    profile = fetch_user_travel_profile(supabase, id_user)
    return places, profile


def _fetch_cf_scores_via_factors(
    supabase, id_user: str, place_ids: list[str]
) -> dict[str, float]:
    """
    CF scores computed at request time from cf_user_factors/cf_place_factors,
    replacing the cf_score_cache read path (fetch_cf_scores_for_user).
    Returns {} — same as a full cache miss — when the user has no trained
    factors yet, so downstream compute_alpha()/dict.get(id, 0.0) behave
    exactly as they did on a cache miss. Does not raise.
    """
    user_factors = fetch_user_factors(supabase, id_user)
    if user_factors is None:
        return {}
    place_factors = fetch_place_factors(supabase, place_ids)
    return compute_cf_scores_from_factors(user_factors, place_factors)


def _fetch_module1_inputs(supabase, id_user: str, place_ids: list[str]):
    """Avoid concurrent use of the same synchronous Supabase client."""
    return (
        fetch_active_tags(supabase),
        fetch_place_tags_for_places(supabase, place_ids),
        fetch_user_interest_tags(supabase, id_user),
        fetch_already_rated_places(supabase, id_user),
        _fetch_cf_scores_via_factors(supabase, id_user, place_ids),
        fetch_user_onboarding_choices(supabase, id_user),
    )


def _fetch_trip_option_mappings(supabase, option_ids: list[str]):
    """Fetch related option metadata without sharing a client across threads."""
    return (
        fetch_trip_interest_option_tags(supabase, option_ids),
        fetch_trip_interest_option_subcategories(supabase, option_ids),
    )


def _derive_start_point(places: list) -> dict:
    if not places:
        return {"latitude": 16.0, "longitude": 108.0}
    avg_lat = sum(float(p["latitude"])  for p in places) / len(places)
    avg_lon = sum(float(p["longitude"]) for p in places) / len(places)
    return {"latitude": avg_lat, "longitude": avg_lon}


def _start_point_for_day(day_cluster: dict, fallback_places: list) -> dict:
    """
    Each day's start_point is now derived independently from that day's own
    cluster centroid — NOT chained from the previous day's optimized last
    stop (the old `start_point = best_route[-1]` carried across loop
    iterations). This is what makes the days independent of each other and
    safe to run concurrently (see the day loop in plan()).

    day_cluster["centroid"] is a (lat, lon) tuple already computed by
    Module 2 (module2_algorithm.py's compute_centroid()/build_initial_day_
    clusters()) and kept in sync with the day's final `places` by
    recompute_day_centroid() whenever greedy repair moves places between
    days — so by the time plan() reaches Module 3, it always reflects the
    places actually in this day_cluster.

    Falls back to _derive_start_point() (this day's own places, then the
    whole trip's top_places) only for the degenerate case of an empty day
    cluster, where compute_centroid() returns None.

    Trade-off accepted: day N no longer starts geographically near where
    day N-1's route ended — a soft continuity nicety, not a hard schedule
    rule enforced anywhere in schedule_builder.py — traded for running all
    days' SA + Goong concurrently instead of sequentially.
    """
    centroid = day_cluster.get("centroid")
    if centroid is not None:
        return {"latitude": centroid[0], "longitude": centroid[1]}
    day_places = day_cluster.get("places") or []
    if day_places:
        return _derive_start_point(day_places)
    return _derive_start_point(fallback_places)


# Same threshold used by test_module1_eval.py's ground-truth definition —
# high enough to drop noisy auto-tagged rows (e.g. Duong Dong Market's
# "beach" tag at confidence 0.40 — a real place_tag row, but not
# representative of what the place actually is) while keeping genuine tags
# (e.g. that same place's "culture"/"local_market"/"shopping" rows, all at
# confidence 1.0).
PLACE_TAG_CONFIDENCE_THRESHOLD = 0.7
# Caps the chip row in the UI — a heavily auto-tagged place can have 8+ rows
# past the confidence threshold; 4 keeps the detail page from overflowing
# while still showing enough to differentiate places (a market vs a beach).
MAX_PLACE_TAGS_RETURNED = 4


def _extract_place_tag_names(place: dict, id_tag_to_name: dict[str, str]) -> list[str]:
    """
    Real tag_name list for this place — NOT matched_user_tags (that's the
    subset that matched one specific user's interest weights; this is the
    place's own full tag set from place_tag, already attached in-memory by
    attach_place_tags_to_places() during Module 1, no extra DB query needed).
    Filtered to PLACE_TAG_CONFIDENCE_THRESHOLD, sorted by confidence_score
    descending, capped at MAX_PLACE_TAGS_RETURNED. Always returns a list
    (empty if the place has no tag past the threshold), never None.

    tag_name is read from the row's nested "tag" object when present, else
    falls back to id_tag_to_name[id_tag] — defense-in-depth, same pattern as
    the existing id_tag_map (see its comment above). fetch_place_tags_for_
    places() (module1_repository.py) used to return rows missing the nested
    "tag" embed due to a multi-line .select() string bug — now fixed at the
    source (select is single-line, verified live to return the embed
    correctly). This fallback is kept anyway rather than removed: id_tag is
    always present on these rows regardless of embed shape, so this costs
    nothing and protects against the same class of bug recurring upstream
    without a caller having to notice.
    """
    rows = place.get("place_tag") or []
    scored_names: list[tuple[float, str]] = []
    for row in rows:
        confidence = float(row.get("confidence_score") or 0.0)
        if confidence < PLACE_TAG_CONFIDENCE_THRESHOLD:
            continue
        tag_name = (row.get("tag") or {}).get("tag_name")
        if not tag_name:
            tag_name = id_tag_to_name.get(str(row.get("id_tag") or ""))
        if not tag_name:
            continue
        scored_names.append((confidence, tag_name))
    scored_names.sort(key=lambda item: item[0], reverse=True)
    return [name for _, name in scored_names[:MAX_PLACE_TAGS_RETURNED]]


def _format_place(place: dict, order: int, id_tag_to_name: dict[str, str]) -> dict:
    return {
        "type":                       "place",
        "order":                      order,
        "id_place":                   str(place["id_place"]),
        "name":                       place.get("name"),
        "id_province":                place.get("id_province"),
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
        "travel_time_car_seconds":    place.get("travel_time_car_seconds"),
        "travel_time_bike_seconds":   place.get("travel_time_bike_seconds"),
        "travel_distance_car_meters": place.get("travel_distance_car_meters"),
        "travel_distance_bike_meters": place.get("travel_distance_bike_meters"),
        "minimum_price":              place.get("minimum_price"),
        "maximum_price":              place.get("maximum_price"),
        "cover_image":                place.get("cover_image"),
        "gallery":                    place.get("gallery"),
        "tag_match":                  place.get("tag_match"),
        "cf_score":                   place.get("cf_score"),
        "final_score":                place.get("final_score"),
        "tags":                       _extract_place_tag_names(place, id_tag_to_name),
    }


def _build_edge_lookups(best_route: list[dict], car_matrix: list[dict], bike_matrix: list[dict]):
    """
    Build {(id_place_a, id_place_b): edge_dict} lookups from Goong's
    per-vehicle edge lists, keyed to match the consecutive pairs of
    best_route the matrices were fetched for.
    """
    car_lookup: dict[tuple, dict] = {}
    bike_lookup: dict[tuple, dict] = {}
    for a, b, car_edge, bike_edge in zip(best_route, best_route[1:], car_matrix, bike_matrix):
        key = (str(a.get("id_place")), str(b.get("id_place")))
        car_lookup[key] = car_edge
        bike_lookup[key] = bike_edge
    return car_lookup, bike_lookup


def _build_goong_travel_time_fn(bike_lookup: dict):
    """
    travel_time_fn for build_day_schedule(), backed by Goong bike data.

    build_day_schedule() can call travel_time_fn(prev, place) for pairs NOT
    present in bike_lookup — this happens for two structural reasons, not
    Goong failures:
      1. The very first scheduled place of the day: prev is start_point
         (not a best_route member — no id_place, or not part of this day's
         route), so no Goong edge exists for it.
      2. A "skip" edge after a place got dropped mid-route (visit_end >
         day_end): build_day_schedule keeps `prev` at the last actually
         committed place, so the next travel_time_fn call uses a
         (prev, place) pair that isn't adjacent in best_route, and Goong was
         only fetched for adjacent best_route pairs.
    Both cases fall back to Haversine (_travel_min) for just that one edge —
    this is NOT the same as the day-level "all-or-nothing" fallback, which
    only applies when the Goong API itself fails/returns non-OK for an edge
    that IS in best_route.
    """
    def travel_time_fn(prev: dict, place: dict) -> float:
        key = (str(prev.get("id_place")), str(place.get("id_place")))
        edge = bike_lookup.get(key)
        if edge is not None:
            # round(), not a bare division: travel_time_fn is a shared
            # interface (see schedule_builder._simulate_place_step) — both
            # implementations (Haversine's _travel_min() below, and this one)
            # must return the same type (int, whole minutes), or any caller
            # of build_day_schedule() that stores minutes into an `int`
            # column (e.g. plan_component.estimated_travel_minutes) breaks
            # depending on which travel_time_fn happened to run.
            return round(edge["duration_seconds"] / 60)
        return _travel_min(prev, place)

    return travel_time_fn


def _attach_travel_data(schedule: list[dict], car_lookup: dict, bike_lookup: dict) -> None:
    """
    Mutates each committed 'place' entry in `schedule` with
    travel_time_car_seconds / travel_time_bike_seconds /
    travel_distance_car_meters / travel_distance_bike_meters, sourced from
    the SAME lookups used to build the travel_time_fn passed to
    build_day_schedule() — so an entry only gets Goong numbers attached if
    Goong data was actually what produced its start_time/end_time. Structural
    edges (first place of the day, post-drop skip edges — see
    _build_goong_travel_time_fn docstring) are left with these 4 fields
    unset (None), since their schedule times came from the Haversine
    fallback, not Goong.

    prev tracking mirrors build_day_schedule(): only advances on committed
    (non-dropped) 'place' entries; lunch_break/dropped entries are skipped
    and don't reset it.
    """
    prev_committed_place = None
    for entry in schedule:
        if entry.get("type") != "place" or entry.get("dropped"):
            continue
        if prev_committed_place is not None:
            key = (str(prev_committed_place.get("id_place")), str(entry.get("id_place")))
            car_edge = car_lookup.get(key)
            bike_edge = bike_lookup.get(key)
            if car_edge is not None and bike_edge is not None:
                entry["travel_time_car_seconds"] = car_edge["duration_seconds"]
                entry["travel_distance_car_meters"] = car_edge["distance_meters"]
                entry["travel_time_bike_seconds"] = bike_edge["duration_seconds"]
                entry["travel_distance_bike_meters"] = bike_edge["distance_meters"]
        prev_committed_place = entry


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
        id_province:         str | None,
        n_days:              int,
        start_at:            datetime.date,
        sa_runs:             int        = 2,
        save:                bool       = True,
        interest_option_ids: list[str] | None = None,
        target_lat:          float | None     = None,
        target_lng:          float | None     = None,
    ) -> dict:
        supabase = self.supabase
        end_date = start_at + datetime.timedelta(days=n_days - 1)

        timing_ms: dict[str, float] = {}
        _t_start = time.perf_counter()

        # ── [Filtering] ───────────────────────────────────────────────────────
        required_places, user_profile = await asyncio.to_thread(
            _fetch_initial_inputs,
            supabase,
            id_user,
            id_province,
            target_lat,
            target_lng,
        )
        if target_lat is not None and target_lng is not None:
            print(f"[DEBUG] business trip: target=({target_lat},{target_lng}) "
                  f"candidates={len(required_places)}")
        filtered_places, filter_report = filter_places_with_fallback(
            required_places, user_profile or {}, n_days
        )

        # ── [Module 1 – TagMatch] ─────────────────────────────────────────────
        place_ids = [str(p["id_place"]) for p in filtered_places]
        (
            tags,
            place_tag_rows,
            interest_tag_rows,
            already_rated,
            cf_scores,
            onboarding_choices,
        ) = await asyncio.to_thread(
            _fetch_module1_inputs, supabase, id_user, place_ids
        )
        tag_map = build_tag_map(tags)
        # {id_tag (str) → tag_code} for rows that only carry UUID (no nested tag object)
        id_tag_map = {
            str(tag["id_tag"]): tag["tag_code"]
            for tag in tags
            if tag.get("id_tag") and tag.get("tag_code")
        }
        # {id_tag (str) → tag_name} — same fallback need as id_tag_map above,
        # for _extract_place_tag_names()'s display-name lookup.
        id_tag_to_name = {
            str(tag["id_tag"]): tag["tag_name"]
            for tag in tags
            if tag.get("id_tag") and tag.get("tag_name")
        }

        places_with_tags = attach_place_tags_to_places(filtered_places, place_tag_rows)

        user_interest_state = build_user_interest_state_from_rows(
            interest_tag_rows, tag_map, id_tag_map
        )

        # ── [Trip-level interest blend] ───────────────────────────────────────
        # Default: onboarding-level only (identical behaviour to before)
        weight_field = "final_weight"
        trip_selected_options = None
        trip_option_subcategory_rows = None

        if interest_option_ids:
            options = await asyncio.to_thread(
                fetch_trip_interest_options_by_ids, supabase, interest_option_ids
            )
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

                option_tag_rows, option_subcategory_rows = await asyncio.to_thread(
                    _fetch_trip_option_mappings, supabase, active_option_ids
                )

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

        timing_ms["data_fetch"] = round((time.perf_counter() - _t_start) * 1000, 1)
        _t_scoring0 = time.perf_counter()

        # ── [Rank by tag match] ───────────────────────────────────────────────
        ranked = rank_places_by_tag_match(
            places_with_tags, user_interest_state,
            weight_field=weight_field,
            id_tag_map=id_tag_map,
        )
        ranked = [p for p in ranked if str(p["id_place"]) not in already_rated]

        # ── [CF Blend] ────────────────────────────────────────────────────────
        alpha = compute_alpha(cf_scores, len(filtered_places))

        for place in ranked:
            tag_match = float(place.get("tag_match") or 0.0)
            cf = cf_scores.get(str(place["id_place"]), 0.0)
            place["cf_score"]   = round(cf, 6)
            place["alpha_used"] = alpha
            place["final_score"] = round(alpha * tag_match + (1 - alpha) * cf, 6)

        ranked.sort(key=lambda p: -p["final_score"])

        # ── [Diversity] ───────────────────────────────────────────────────────
        user_selected_interests = [
            c["option_code"] for c in onboarding_choices if c.get("option_code")
        ]

        diversity_result = apply_diversity_selection(
            ranked, n_days, user_selected_interests,
            trip_selected_options=trip_selected_options,
            trip_option_subcategory_rows=trip_option_subcategory_rows,
        )
        top_places = diversity_result["diversified_top_k"]

        timing_ms["scoring"] = round((time.perf_counter() - _t_scoring0) * 1000, 1)
        _t_m2_0 = time.perf_counter()

        # ── [Module 2 – Greedy Repair] ────────────────────────────────────────
        pace_level = (user_profile or {}).get("pace_level")
        m2_result = await asyncio.to_thread(
            build_module2_result,
            top_places,
            start_date=str(start_at),
            end_date=str(end_date),
            pace_level=pace_level,
        )
        day_clusters = m2_result["day_clusters"]

        timing_ms["module2_kmeans_repair"] = round((time.perf_counter() - _t_m2_0) * 1000, 1)
        _t_m3_0 = time.perf_counter()

        # ── [Module 3 – Route optimization] ───────────────────────────────────
        # Each day is now independent (start_point comes from that day's own
        # cluster centroid, not from the previous day's optimized last stop —
        # see _start_point_for_day()), so all days run concurrently via
        # asyncio.gather() instead of one-at-a-time. No shared mutable state
        # between days: each day_cluster["places"] is a disjoint set of place
        # dicts (Module 2's clustering assigns every place to exactly one
        # day), optimize_day_route() creates its own fresh random.Random(seed)
        # per call, and _build_edge_lookups()/_attach_travel_data() below
        # only ever touch this day's own best_route/schedule_result — nothing
        # here is a global or cross-day-shared object.
        async def _plan_one_day(day_cluster: dict) -> dict:
            day_places = day_cluster["places"]
            start_point = _start_point_for_day(day_cluster, top_places)

            best_route, schedule_result = await asyncio.to_thread(
                optimize_day_route,
                start_point, day_places, sa_runs=sa_runs
            )

            # ── [Travel data] Goong Distance Matrix, car + bike ─────────────────
            # Runs ONCE per day, after SA has already picked best_route — never
            # inside the SA loop (which stays on Haversine, see
            # schedule_builder.route_cost_with_schedule). All-or-nothing per
            # day: if any edge for either vehicle comes back non-OK, the day
            # keeps the Haversine-based schedule_result from optimize_day_route
            # untouched (never mixes Goong and Haversine within one day).
            if len(best_route) >= 2:
                matrices = await fetch_travel_matrix_both_vehicles(best_route)
                goong_ok = all(e["status"] == "OK" for e in matrices["car"]) and \
                           all(e["status"] == "OK" for e in matrices["bike"])
                if goong_ok:
                    car_lookup, bike_lookup = _build_edge_lookups(
                        best_route, matrices["car"], matrices["bike"]
                    )
                    goong_travel_time_fn = _build_goong_travel_time_fn(bike_lookup)
                    # Recompute the day's final schedule with real bike travel
                    # times (replaces the Haversine-based schedule_result from
                    # optimize_day_route above).
                    schedule_result = build_day_schedule(
                        best_route, start_point=start_point,
                        travel_time_fn=goong_travel_time_fn,
                    )
                    _attach_travel_data(schedule_result["schedule"], car_lookup, bike_lookup)

            formatted   = []
            place_order = 1
            for entry in schedule_result["schedule"]:
                if entry.get("dropped"):
                    continue          # silently excluded — didn't fit the day
                if entry.get("type") == "lunch_break":
                    formatted.append(_format_lunch_break(entry))
                else:
                    formatted.append(_format_place(entry, order=place_order, id_tag_to_name=id_tag_to_name))
                    place_order += 1

            return {
                "day":    day_cluster["day"],
                "date":   day_cluster["date"],
                "places": formatted,
            }

        # asyncio.gather() preserves input order in its result list
        # regardless of which day finishes first — day_clusters[i] always
        # maps to days[i], so save_plan()'s day numbering stays correct.
        days = list(await asyncio.gather(
            *(_plan_one_day(day_cluster) for day_cluster in day_clusters)
        ))

        timing_ms["module3_sa_schedule"] = round((time.perf_counter() - _t_m3_0) * 1000, 1)
        _t_save_0 = time.perf_counter()

        # ── [Persist] ─────────────────────────────────────────────────────────
        real_place_count = sum(
            1
            for day in days
            for place in day.get("places", [])
            if place.get("type") != "lunch_break" and place.get("id_place")
        )
        print(json.dumps({
            "event": "trip_planner_pipeline_counts",
            "required_count": len(required_places),
            "filtered_count": len(filtered_places),
            "ranked_count": len(ranked),
            "candidate_count": m2_result.get("summary", {}).get("candidate_count", 0),
            "real_place_count": real_place_count,
        }, separators=(",", ":")))

        id_plan = None
        if save and real_place_count == 0:
            raise NoTripCandidatesError(
                "No eligible places were available for this trip."
            )
        if save:
            saved_plan = await asyncio.to_thread(
                save_plan, supabase, id_user, id_province, n_days, start_at,
                days, interest_option_ids
            )
            id_plan = saved_plan["id_plan"]
            custom_title = saved_plan["custom_title"]
        else:
            custom_title = None

        timing_ms["save_plan"] = round((time.perf_counter() - _t_save_0) * 1000, 1)
        timing_ms["total"] = round((time.perf_counter() - _t_start) * 1000, 1)

        print(f"[TIMING] plan() total={timing_ms['total']}ms "
              f"data_fetch={timing_ms['data_fetch']}ms "
              f"scoring={timing_ms['scoring']}ms "
              f"module2={timing_ms['module2_kmeans_repair']}ms "
              f"module3={timing_ms['module3_sa_schedule']}ms "
              f"save_plan={timing_ms['save_plan']}ms")

        return {
            "id_plan": id_plan,
            "custom_title": custom_title,
            "city_province": id_province,
            "days": days,
            "accommodation_recommendation": m2_result.get("accommodation_recommendation"),
            "debug": {
                "filter_report":      filter_report,
                # % of candidate places (filtered_places) for which the CF
                # model predicts POSITIVE affinity for this specific user
                # (cf_score > 0.5, the sigmoid midpoint / U·V=0 threshold) —
                # not merely "place has a trained embedding". The numerator
                # is filtered directly from filtered_places (not a separate
                # data source), so cf_coverage is always a subset count and
                # can never exceed 1.0.
                "cf_coverage":        round(
                    len([p for p in filtered_places
                         if cf_scores.get(str(p["id_place"]), 0.0) > 0.5])
                    / max(len(filtered_places), 1),
                    4,
                ),
                "alpha":              alpha,
                "weight_field":       weight_field,
                "trip_interest_used": bool(trip_selected_options),
                "m2_summary":         m2_result.get("summary"),
                "diversity_summary":  diversity_result.get("summary", {}).get("final_selected_count"),
                "timing_ms":          timing_ms,
            },
        }
