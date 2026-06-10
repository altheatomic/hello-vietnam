"""
Repository helpers for Module 1:
- fetch active tags
- fetch place_tag rows for candidate places
- persist user travel profile and user_interest_tag
"""

from __future__ import annotations

from typing import Any


def fetch_active_tags(supabase: Any) -> list[dict]:
    response = (
        supabase
        .table("tag")
        .select(
            """
            id_tag,
            tag_code,
            tag_name,
            tag_group,
            description,
            is_active
            """
        )
        .eq("is_active", True)
        .execute()
    )

    return response.data or []


def build_tag_map(tags: list[dict]) -> dict[str, dict]:
    return {
        tag["tag_code"]: tag
        for tag in tags
        if tag.get("tag_code")
    }


def fetch_place_tags_for_places(
    supabase: Any,
    place_ids: list[str],
    chunk_size: int = 100,
) -> list[dict]:
    if not place_ids:
        return []

    rows: list[dict] = []

    for start_index in range(0, len(place_ids), chunk_size):
        chunk = place_ids[start_index:start_index + chunk_size]

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

        rows_by_place_id.setdefault(place_id, []).append(row)

    enriched_places = []

    for place in places:
        enriched_place = dict(place)
        enriched_place["place_tag"] = rows_by_place_id.get(place.get("id_place"), [])
        enriched_places.append(enriched_place)

    return enriched_places


def fetch_user_interest_tags(
    supabase: Any,
    user_id: str,
) -> list[dict]:
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


def fetch_user_travel_profile(
    supabase: Any,
    user_id: str,
) -> dict | None:
    response = (
        supabase
        .table("user_travel_profile")
        .select(
            """
            id_user,
            companion_style,
            budget_level,
            pace_level,
            created_at,
            updated_at
            """
        )
        .eq("id_user", user_id)
        .limit(1)
        .execute()
    )

    rows = response.data or []
    return rows[0] if rows else None


def fetch_user_onboarding_choices(
    supabase: Any,
    user_id: str,
) -> list[dict]:
    response = (
        supabase
        .table("user_onboarding_choice")
        .select(
            """
            id_user,
            screen_code,
            option_code,
            created_at,
            updated_at
            """
        )
        .eq("id_user", user_id)
        .execute()
    )

    return response.data or []


def replace_user_interest_tags(
    supabase: Any,
    user_id: str,
    rows: list[dict],
) -> None:
    (
        supabase
        .table("user_interest_tag")
        .delete()
        .eq("id_user", user_id)
        .execute()
    )

    if rows:
        (
            supabase
            .table("user_interest_tag")
            .insert(rows)
            .execute()
        )


def upsert_user_interest_tags(
    supabase: Any,
    rows: list[dict],
) -> None:
    if not rows:
        return

    (
        supabase
        .table("user_interest_tag")
        .upsert(rows, on_conflict="id_user,id_tag")
        .execute()
    )


def upsert_user_travel_profile(
    supabase: Any,
    profile: dict,
) -> None:
    (
        supabase
        .table("user_travel_profile")
        .upsert(profile, on_conflict="id_user")
        .execute()
    )
