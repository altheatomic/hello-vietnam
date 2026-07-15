"""
services/module1_repository.py
Supabase-py DB functions for Module 1 (planning pipeline) and
the user interest write pipeline (Phase 2).

Planning pipeline reads:
  fetch_active_tags, build_tag_map
  fetch_place_tags_for_places, attach_place_tags_to_places
  fetch_user_interest_tags, fetch_user_travel_profile
  fetch_user_onboarding_choices
  fetch_already_rated_places
  fetch_cf_scores_for_user

Write pipeline (Phase 2):
  replace_user_interest_tags, upsert_user_interest_tags
  upsert_user_travel_profile
  fetch_trip_plan, fetch_trip_interest_choices
  fetch_trip_interest_option_tags, fetch_trip_interest_option_subcategories
"""

from __future__ import annotations

from typing import Any


# ── Tag master data ───────────────────────────────────────────────────────────

def fetch_active_tags(supabase: Any) -> list[dict]:
    response = (
        supabase
        .table("tag")
        .select("id_tag, tag_code, tag_name, tag_group, description, is_active")
        .eq("is_active", True)
        .execute()
    )
    return response.data or []


def build_tag_map(tags: list[dict]) -> dict[str, dict]:
    return {tag["tag_code"]: tag for tag in tags if tag.get("tag_code")}


# ── Place tags ────────────────────────────────────────────────────────────────

def fetch_place_tags_for_places(
    supabase: Any,
    place_ids: list[str],
    chunk_size: int = 100,
) -> list[dict]:
    if not place_ids:
        return []

    rows: list[dict] = []
    for start in range(0, len(place_ids), chunk_size):
        chunk = place_ids[start:start + chunk_size]
        response = (
            supabase
            .table("place_tag")
            .select(
                """
                id_place,
                id_tag,
                confidence_score,
                source,
                tag (
                    id_tag,
                    tag_code,
                    tag_name,
                    tag_group
                )
                """
            )
            .in_("id_place", chunk)
            .execute()
        )
        rows.extend(response.data or [])
    return rows


def attach_place_tags_to_places(
    places: list[dict],
    place_tag_rows: list[dict],
) -> list[dict]:
    rows_by_place_id: dict[str, list[dict]] = {}
    for row in place_tag_rows:
        place_id = row.get("id_place")
        if not place_id:
            continue
        rows_by_place_id.setdefault(str(place_id), []).append(row)

    enriched = []
    for place in places:
        enriched_place = dict(place)
        enriched_place["place_tag"] = rows_by_place_id.get(str(place.get("id_place")), [])
        enriched.append(enriched_place)
    return enriched


# ── User profile ──────────────────────────────────────────────────────────────

def fetch_user_interest_tags(supabase: Any, user_id: str) -> list[dict]:
    response = (
        supabase
        .table("user_interest_tag")
        .select(
            """
            id_user,
            id_tag,
            initial_weight,
            behavior_score,
            behavior_weight,
            final_weight,
            positive_behavior_count,
            negative_behavior_count,
            behavior_count,
            source,
            tag (
                id_tag,
                tag_code,
                tag_name,
                tag_group
            )
            """
        )
        .eq("id_user", user_id)
        .execute()
    )
    return response.data or []


def fetch_user_travel_profile(supabase: Any, user_id: str) -> dict | None:
    response = (
        supabase
        .table("user_travel_profile")
        .select("id_user, companion_style, budget_level, pace_level, created_at, updated_at")
        .eq("id_user", user_id)
        .limit(1)
        .execute()
    )
    rows = response.data or []
    return rows[0] if rows else None


def fetch_user_onboarding_choices(supabase: Any, user_id: str) -> list[dict]:
    response = (
        supabase
        .table("user_onboarding_choice")
        .select("id_user, screen_code, option_code, created_at, updated_at")
        .eq("id_user", user_id)
        .execute()
    )
    return response.data or []


# ── CF scores ─────────────────────────────────────────────────────────────────

def fetch_cf_scores_for_user(
    supabase: Any,
    user_id: str,
    place_ids: list[str],
) -> dict[str, float]:
    """
    Fetch CF scores for a specific user and the given place IDs.
    Uses place_ids (already fetched) instead of province_id to avoid
    a second province query.
    """
    if not place_ids:
        return {}

    chunk_size = 200
    result: dict[str, float] = {}

    for start in range(0, len(place_ids), chunk_size):
        chunk = place_ids[start:start + chunk_size]
        response = (
            supabase
            .table("cf_score_cache")
            .select("id_place, score")
            .eq("id_user", user_id)
            .in_("id_place", chunk)
            .execute()
        )
        for r in (response.data or []):
            result[str(r["id_place"])] = float(r["score"])

    return result


# ── Already rated ─────────────────────────────────────────────────────────────

def fetch_already_rated_places(supabase: Any, user_id: str) -> set[str]:
    response = (
        supabase
        .table("rate_item")
        .select("id_item")
        .eq("id_user", user_id)
        .eq("item_type", "place")
        .execute()
    )
    return {str(r["id_item"]) for r in (response.data or [])}


# ── Trip interest options (request-scoped, no trip_plan FK required) ─────────

def fetch_trip_interest_options_by_ids(
    supabase: Any,
    option_ids: list[str],
    chunk_size: int = 100,
) -> list[dict]:
    """Fetch trip_interest_option rows directly by ID — used for
    request-scoped flow, bypasses trip_interest_choice table."""
    if not option_ids:
        return []
    rows: list[dict] = []
    for start_index in range(0, len(option_ids), chunk_size):
        chunk = option_ids[start_index:start_index + chunk_size]
        response = (
            supabase
            .table("trip_interest_option")
            .select(
                """
                id_trip_interest_option,
                option_code,
                display_name,
                display_order,
                is_active
                """
            )
            .in_("option_code", chunk)
            .execute()
        )
        rows.extend(response.data or [])
    return rows


# ── Write pipeline (Phase 2) ──────────────────────────────────────────────────

def replace_user_interest_tags(supabase: Any, user_id: str, rows: list[dict]) -> None:
    supabase.table("user_interest_tag").delete().eq("id_user", user_id).execute()
    if rows:
        supabase.table("user_interest_tag").insert(rows).execute()


def upsert_user_interest_tags(supabase: Any, rows: list[dict]) -> None:
    if not rows:
        return
    supabase.table("user_interest_tag").upsert(rows, on_conflict="id_user,id_tag").execute()


def upsert_user_travel_profile(supabase: Any, profile: dict) -> None:
    supabase.table("user_travel_profile").upsert(profile, on_conflict="id_user").execute()


def fetch_trip_plan(supabase: Any, trip_plan_id: str) -> dict | None:
    response = (
        supabase
        .table("trip_plan")
        .select(
            "id_trip_plan, id_user, id_province, start_date, end_date, total_days, status, created_at, updated_at"
        )
        .eq("id_trip_plan", trip_plan_id)
        .limit(1)
        .execute()
    )
    rows = response.data or []
    return rows[0] if rows else None


def fetch_trip_interest_choices(supabase: Any, trip_plan_id: str) -> list[dict]:
    response = (
        supabase
        .table("trip_interest_choice")
        .select(
            """
            id_trip_plan,
            id_trip_interest_option,
            selection_order,
            source,
            trip_interest_option (
                id_trip_interest_option,
                option_code,
                display_name,
                description,
                display_order,
                min_selection,
                max_selection,
                is_active
            )
            """
        )
        .eq("id_trip_plan", trip_plan_id)
        .execute()
    )
    return response.data or []


def fetch_trip_interest_option_tags(
    supabase: Any,
    option_ids: list[str],
    chunk_size: int = 100,
) -> list[dict]:
    if not option_ids:
        return []

    rows: list[dict] = []
    for start in range(0, len(option_ids), chunk_size):
        chunk = option_ids[start:start + chunk_size]
        response = (
            supabase
            .table("trip_interest_option_tag")
            .select(
                """
                id_trip_interest_option,
                id_tag,
                weight_level,
                raw_weight,
                is_active,
                tag (
                    id_tag,
                    tag_code,
                    tag_name,
                    tag_group
                )
                """
            )
            .in_("id_trip_interest_option", chunk)
            .execute()
        )
        rows.extend(response.data or [])
    return rows


def fetch_trip_interest_option_subcategories(
    supabase: Any,
    option_ids: list[str],
    chunk_size: int = 100,
) -> list[dict]:
    if not option_ids:
        return []

    rows: list[dict] = []
    for start in range(0, len(option_ids), chunk_size):
        chunk = option_ids[start:start + chunk_size]
        response = (
            supabase
            .table("trip_interest_option_subcategory")
            .select(
                """
                id_trip_interest_option,
                id_place_subcategory,
                priority_level,
                priority_weight,
                is_active,
                place_subcategory (
                    id_place_subcategory,
                    name,
                    place_category
                )
                """
            )
            .in_("id_trip_interest_option", chunk)
            .execute()
        )
        rows.extend(response.data or [])
    return rows
