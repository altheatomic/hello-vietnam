"""
Run the end-to-end trip pipeline:
1. Filtering
2. Module 1: TagMatch ranking
3. Module 1: slot-based diversity by subcategory
4. Module 2: K-means + Greedy Repair day grouping
"""

from __future__ import annotations

from pathlib import Path
import sys
from typing import TextIO

from filters import calculate_total_days, filter_places_with_fallback
from module1_algorithm import (
    build_effective_interest_state,
    build_onboarding_profile,
    build_trip_interest_profile,
    build_user_interest_rows_from_state,
    merge_user_interest_state,
    rank_places_by_tag_match,
)
from module1_diversity import apply_diversity_selection
from module1_repository import (
    attach_place_tags_to_places,
    build_tag_map,
    fetch_active_tags,
    fetch_trip_interest_choices,
    fetch_trip_interest_option_subcategories,
    fetch_trip_interest_option_tags,
    fetch_trip_plan,
    fetch_user_onboarding_choices,
    fetch_place_tags_for_places,
    fetch_user_interest_tags,
    fetch_user_travel_profile,
    upsert_user_interest_tags,
)
from module2_algorithm import build_module2_result
from pipeline_input import get_pipeline_input
from place_repository import fetch_places_required_filter
from supabase_client import get_supabase_client


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


INPUT_FILE = Path(__file__).with_name("pipeline_input.py")
OUTPUT_FILE = Path(__file__).with_name("KQ.txt")


class TeeStream:
    def __init__(self, *streams: TextIO) -> None:
        self.streams = streams

    def write(self, data: str) -> int:
        for stream in self.streams:
            stream.write(data)
        return len(data)

    def flush(self) -> None:
        for stream in self.streams:
            stream.flush()


def print_section(title: str) -> None:
    print("=" * 100)
    print(title)
    print("=" * 100)


def print_step(step_number: int, title: str, purpose: str) -> None:
    print("=" * 100)
    print(f"BƯỚC {step_number}: {title}")
    print("=" * 100)
    print(f"Mục tiêu: {purpose}")
    print()


def print_key_value_block(title: str, data: dict) -> None:
    print(title)
    print("-" * 100)

    for key, value in data.items():
        print(f"  {key}: {value}")

    print()


def format_place_line(index: int, place: dict) -> str:
    parts = [
        f"{index}. {place.get('name')}",
        f"id_place={place.get('id_place')}",
        f"subcategory={place.get('subcategory_name') or (place.get('place_subcategory') or {}).get('name')}",
        f"rating={place.get('average_rating')}",
        f"review_count={place.get('review_count')}",
        f"duration={place.get('estimated_duration_minutes')}",
    ]

    if place.get("tag_match") is not None:
        parts.append(f"tag_match={place.get('tag_match')}")

    if place.get("module1_score") is not None:
        parts.append(f"module1_score={place.get('module1_score')}")

    if place.get("maximum_price") is not None:
        parts.append(f"max_price={place.get('maximum_price')}")

    return " | ".join(parts)


def print_place_preview(title: str, places: list[dict], limit: int) -> None:
    print(title)
    print("-" * 100)

    if not places:
        print("  No places")
        print()
        return

    for index, place in enumerate(places[:limit], start=1):
        print("  " + format_place_line(index, place))

    if len(places) > limit:
        print(f"  ... and {len(places) - limit} more places")

    print()


def write_full_places(output_file: TextIO, title: str, places: list[dict]) -> None:
    output_file.write("=" * 100 + "\n")
    output_file.write(f"{title}: {len(places)}\n")
    output_file.write("=" * 100 + "\n")

    if not places:
        output_file.write("No places\n\n")
        return

    for index, place in enumerate(places, start=1):
        output_file.write(format_place_line(index, place) + "\n")
        if place.get("address"):
            output_file.write(f"    address={place.get('address')}\n")
        if place.get("warnings"):
            output_file.write(f"    warnings={place.get('warnings')}\n")

    output_file.write("\n")


def write_places_grouped_by_subcategory(output_file: TextIO, title: str, places: list[dict]) -> None:
    output_file.write("=" * 100 + "\n")
    output_file.write(f"{title}\n")
    output_file.write("=" * 100 + "\n")

    if not places:
        output_file.write("No places\n\n")
        return

    grouped: dict[str, list[dict]] = {}
    for place in places:
        subcategory_name = str(place.get("subcategory_name") or (place.get("place_subcategory") or {}).get("name") or "Unknown")
        grouped.setdefault(subcategory_name, []).append(place)

    for subcategory_name in sorted(grouped.keys()):
        output_file.write(f"[{subcategory_name}] count={len(grouped[subcategory_name])}\n")
        for index, place in enumerate(grouped[subcategory_name], start=1):
            output_file.write("  " + format_place_line(index, place) + "\n")
        output_file.write("\n")


def write_user_interest_profile(output_file: TextIO, user_interest_state: dict[str, dict]) -> None:
    output_file.write("=" * 100 + "\n")
    output_file.write("FULL User interest profile\n")
    output_file.write("=" * 100 + "\n")

    for tag_code, info in sorted(
        user_interest_state.items(),
        key=lambda item: item[1]["final_weight"],
        reverse=True,
    ):
        output_file.write(
            f"{tag_code}: "
            f"initial_weight={info['initial_weight']}, "
            f"behavior_score={info['behavior_score']}, "
            f"behavior_weight={info['behavior_weight']}, "
            f"final_weight={info['final_weight']}\n"
        )

    output_file.write("\n")


def print_user_interest_preview(user_interest_state: dict[str, dict], limit: int = 10) -> None:
    print("Top user interest tags:")
    print("-" * 100)

    sorted_items = sorted(
        user_interest_state.items(),
        key=lambda item: item[1]["final_weight"],
        reverse=True,
    )

    for tag_code, info in sorted_items[:limit]:
        print(
            f"  {tag_code:<20}"
            f" initial={info['initial_weight']:<8}"
            f" behavior_score={info['behavior_score']:<8}"
            f" behavior_weight={info['behavior_weight']:<8}"
            f" final={info['final_weight']:<8}"
        )

    if len(sorted_items) > limit:
        print(f"  ... and {len(sorted_items) - limit} more tags")

    print()


def print_day_clusters_summary(title: str, day_clusters: list[dict]) -> None:
    print(title)
    print("-" * 100)

    if not day_clusters:
        print("  No day clusters")
        print()
        return

    for day_cluster in day_clusters:
        print(
            f"  Day {day_cluster['day']} | "
            f"date={day_cluster['date']} | "
            f"place_count={day_cluster.get('place_count', len(day_cluster.get('places') or []))} | "
            f"total_duration={day_cluster.get('total_duration_minutes', 0)} | "
            f"warnings={day_cluster.get('warnings') or []}"
        )
        for index, place in enumerate(day_cluster.get("places") or [], start=1):
            print("     " + format_place_line(index, place))

    print()


def write_day_clusters(output_file: TextIO, title: str, day_clusters: list[dict]) -> None:
    output_file.write("=" * 100 + "\n")
    output_file.write(f"{title}\n")
    output_file.write("=" * 100 + "\n")

    if not day_clusters:
        output_file.write("No day clusters\n\n")
        return

    for day_cluster in day_clusters:
        output_file.write(
            f"Day {day_cluster['day']} | "
            f"date={day_cluster['date']} | "
            f"cluster_label={day_cluster.get('cluster_label')} | "
            f"place_count={day_cluster.get('place_count', len(day_cluster.get('places') or []))} | "
            f"total_duration_minutes={day_cluster.get('total_duration_minutes', 0)} | "
            f"warnings={day_cluster.get('warnings') or []}\n"
        )

        for index, place in enumerate(day_cluster.get("places") or [], start=1):
            output_file.write("  " + format_place_line(index, place) + "\n")

        output_file.write("\n")


def write_text_line(output_file: TextIO, text: str) -> None:
    output_file.write(text + "\n")


def write_weight_map(output_file: TextIO, title: str, weight_map: dict[str, float]) -> None:
    output_file.write("=" * 100 + "\n")
    output_file.write(f"{title}\n")
    output_file.write("=" * 100 + "\n")

    if not weight_map:
        output_file.write("No weights\n\n")
        return

    for tag_code, weight in sorted(weight_map.items(), key=lambda item: item[1], reverse=True):
        output_file.write(f"{tag_code}: {round(float(weight), 6)}\n")

    output_file.write("\n")


def resolve_user_profile(
    input_user_profile: dict,
    db_trip_plan: dict | None,
    db_travel_profile: dict | None,
    db_onboarding_choices: list[dict] | None = None,
) -> tuple[dict, dict]:
    user_profile = dict(input_user_profile)
    sources = {
        "trip_plan_source": "pipeline_input_fallback",
        "travel_profile_source": "pipeline_input_fallback",
        "onboarding_choice_source": "pipeline_input_fallback",
    }

    if db_trip_plan:
        for key in ("id_trip_plan", "id_user", "id_province", "start_date", "end_date"):
            db_value = db_trip_plan.get(key)
            if db_value is not None:
                user_profile[key] = db_value
        sources["trip_plan_source"] = "trip_plan"

    if db_travel_profile:
        for key in ("companion_style", "budget_level", "pace_level"):
            db_value = db_travel_profile.get(key)
            if db_value is not None:
                user_profile[key] = db_value
        sources["travel_profile_source"] = "user_travel_profile"

    onboarding_values = build_onboarding_inputs_from_choices(db_onboarding_choices or [])
    if onboarding_values["travel_styles"] or onboarding_values["topics"]:
        if onboarding_values["travel_styles"]:
            user_profile["travel_styles"] = onboarding_values["travel_styles"]
        if onboarding_values["topics"]:
            user_profile["topics"] = onboarding_values["topics"]
        sources["onboarding_choice_source"] = "user_onboarding_choice"

    return user_profile, sources


def normalize_onboarding_option(option_code: str) -> str:
    normalized = str(option_code or "").strip().lower()
    aliases = {
        "local_discovery": "Local Life",
    }

    if normalized in aliases:
        return aliases[normalized]

    return " ".join(part.capitalize() for part in normalized.split("_"))


def build_onboarding_inputs_from_choices(choice_rows: list[dict]) -> dict[str, list[str]]:
    travel_styles: list[str] = []
    topics: list[str] = []

    for row in choice_rows:
        screen_code = str(row.get("screen_code") or "").strip().lower()
        option_code = str(row.get("option_code") or "").strip()

        if not option_code:
            continue

        normalized_value = normalize_onboarding_option(option_code)

        if screen_code == "trip_style":
            travel_styles.append(normalized_value)
        elif screen_code == "specific_interest":
            topics.append(normalized_value)

    return {
        "travel_styles": travel_styles,
        "topics": topics,
    }


def build_user_selected_interests(user_profile: dict) -> list[str]:
    interests: list[str] = []

    for value in user_profile.get("travel_styles") or []:
        if value:
            interests.append(str(value))

    for value in user_profile.get("topics") or []:
        if value:
            interests.append(str(value))

    seen: set[str] = set()
    result: list[str] = []

    for interest in interests:
        normalized = interest.strip().lower()
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        result.append(interest)

    return result


def write_named_items(output_file: TextIO, title: str, items: list[dict]) -> None:
    output_file.write("=" * 100 + "\n")
    output_file.write(f"{title}: {len(items)}\n")
    output_file.write("=" * 100 + "\n")

    if not items:
        output_file.write("No items\n\n")
        return

    for index, item in enumerate(items, start=1):
        output_file.write(f"{index}. {item}\n")

    output_file.write("\n")


def format_repair_log(index: int, log: dict) -> str:
    parts = [f"{index}. action={log.get('action')}"]

    if log.get("day") is not None:
        parts.append(f"day={log.get('day')}")

    if log.get("target_day") is not None:
        parts.append(f"target_day={log.get('target_day')}")

    if log.get("place_name"):
        parts.append(f"place={log.get('place_name')}")

    if log.get("source"):
        parts.append(f"source={log.get('source')}")

    reason = log.get("reason") or {}
    if reason.get("trigger"):
        parts.append(f"trigger={reason.get('trigger')}")
    if reason.get("selected_add_score") is not None:
        parts.append(f"add_score={reason.get('selected_add_score')}")
    if reason.get("selected_move_score") is not None:
        parts.append(f"move_score={reason.get('selected_move_score')}")

    return " | ".join(parts)


def print_repair_log_preview(title: str, repair_logs: list[dict], limit: int) -> None:
    print(title)
    print("-" * 100)

    if not repair_logs:
        print("  No repair actions")
        print()
        return

    for index, log in enumerate(repair_logs[:limit], start=1):
        print("  " + format_repair_log(index, log))
        reason = log.get("reason") or {}
        if reason:
            print(f"     reason={reason}")

    if len(repair_logs) > limit:
        print(f"  ... and {len(repair_logs) - limit} more repair actions")

    print()


def write_repair_logs(output_file: TextIO, title: str, repair_logs: list[dict]) -> None:
    output_file.write("=" * 100 + "\n")
    output_file.write(f"{title}: {len(repair_logs)}\n")
    output_file.write("=" * 100 + "\n")

    if not repair_logs:
        output_file.write("No repair actions\n\n")
        return

    for index, log in enumerate(repair_logs, start=1):
        output_file.write(format_repair_log(index, log) + "\n")
        output_file.write(f"    reason={log.get('reason') or {}}\n")

    output_file.write("\n")


def run_report(output_file: TextIO) -> None:
    pipeline_input = get_pipeline_input()
    input_user_profile = pipeline_input["user_profile"]
    run_settings = pipeline_input["run_settings"]

    supabase = get_supabase_client()
    db_trip_plan = None
    if input_user_profile.get("id_trip_plan"):
        db_trip_plan = fetch_trip_plan(
            supabase=supabase,
            trip_plan_id=str(input_user_profile["id_trip_plan"]),
        )
    resolved_user_id = str(
        (db_trip_plan or {}).get("id_user")
        or input_user_profile["id_user"]
    )
    db_travel_profile = fetch_user_travel_profile(
        supabase=supabase,
        user_id=resolved_user_id,
    )
    db_onboarding_choices = fetch_user_onboarding_choices(
        supabase=supabase,
        user_id=resolved_user_id,
    )
    trip_interest_choice_rows: list[dict] = []
    trip_interest_option_tag_rows: list[dict] = []
    trip_interest_option_subcategory_rows: list[dict] = []
    if db_trip_plan:
        trip_interest_choice_rows = fetch_trip_interest_choices(
            supabase=supabase,
            trip_plan_id=str(db_trip_plan["id_trip_plan"]),
        )
        selected_option_ids = [
            str(row.get("id_trip_interest_option"))
            for row in trip_interest_choice_rows
            if row.get("id_trip_interest_option")
        ]
        trip_interest_option_tag_rows = fetch_trip_interest_option_tags(
            supabase=supabase,
            option_ids=selected_option_ids,
        )
        trip_interest_option_subcategory_rows = fetch_trip_interest_option_subcategories(
            supabase=supabase,
            option_ids=selected_option_ids,
        )
    user_profile, profile_sources = resolve_user_profile(
        input_user_profile=input_user_profile,
        db_trip_plan=db_trip_plan,
        db_travel_profile=db_travel_profile,
        db_onboarding_choices=db_onboarding_choices,
    )
    total_days = calculate_total_days(
        user_profile["start_date"],
        user_profile["end_date"],
    )

    print_section("TRIP PIPELINE: FILTERING -> MODULE 1 -> MODULE 2")
    print_key_value_block(
        title="Input management:",
        data={
            "input_file": str(INPUT_FILE),
            "output_file": str(OUTPUT_FILE),
            "trip_plan_source": profile_sources["trip_plan_source"],
            "travel_profile_source": profile_sources["travel_profile_source"],
            "onboarding_choice_source": profile_sources["onboarding_choice_source"],
        },
    )

    print_step(
        step_number=1,
        title="Đọc Input User Profile",
        purpose="Nạp toàn bộ cấu hình chuyến đi và sở thích người dùng từ một file duy nhất để chạy pipeline đồng bộ.",
    )
    print_key_value_block(
        title="Kết quả bước 1:",
        data={
            "id_trip_plan": user_profile.get("id_trip_plan"),
            "id_user": user_profile["id_user"],
            "id_province": user_profile["id_province"],
            "start_date": user_profile["start_date"],
            "end_date": user_profile["end_date"],
            "total_days": total_days,
            "budget_level": user_profile.get("budget_level"),
            "companion_style": user_profile.get("companion_style"),
            "pace_level": user_profile.get("pace_level"),
            "travel_styles": user_profile.get("travel_styles"),
            "topics": user_profile.get("topics"),
            "behavior_count": user_profile.get("behavior_count"),
            "place_fetch_limit": run_settings.get("place_fetch_limit"),
            "db_trip_plan_found": db_trip_plan is not None,
            "db_user_travel_profile_found": db_travel_profile is not None,
            "db_user_onboarding_choice_count": len(db_onboarding_choices),
            "db_trip_interest_choice_count": len(trip_interest_choice_rows),
        },
    )

    print_step(
        step_number=2,
        title="Lọc Candidate Places",
        purpose="Áp dụng required filters ở DB, sau đó chạy optional filters và fallback để tạo candidate pool đầu vào cho Module 1.",
    )
    required_places = fetch_places_required_filter(
        supabase=supabase,
        province_id=user_profile["id_province"],
        limit=run_settings["place_fetch_limit"],
    )
    final_places, filter_report = filter_places_with_fallback(
        required_places=required_places,
        user_profile=user_profile,
        total_days=total_days,
    )
    print_key_value_block(title="Kết quả bước 2:", data=filter_report)
    print_place_preview(
        title=f"Preview Candidate places after filtering/fallback: {len(final_places)}",
        places=final_places,
        limit=run_settings["terminal_candidate_preview_limit"],
    )
    write_full_places(
        output_file=output_file,
        title="FULL Candidate places after filtering/fallback",
        places=final_places,
    )

    print_step(
        step_number=3,
        title="Xây Dựng Hồ Sơ Sở Thích User",
        purpose="Map onboarding thành raw weights, chuẩn hóa thành initial weights và chuẩn bị dữ liệu user_interest_tag cho Module 1.",
    )
    tag_map = build_tag_map(fetch_active_tags(supabase))
    onboarding_profile = build_onboarding_profile(
        travel_styles=user_profile.get("travel_styles"),
        companion_style=user_profile.get("companion_style"),
        topics=user_profile.get("topics"),
    )
    existing_user_interest_rows = fetch_user_interest_tags(
        supabase=supabase,
        user_id=user_profile["id_user"],
    )
    persistence_mode = "insert_first_time" if not existing_user_interest_rows else "update_existing_state"
    user_interest_state, effective_behavior_count = merge_user_interest_state(
        initial_weights=onboarding_profile["initial_weights"],
        tag_map=tag_map,
        existing_rows=existing_user_interest_rows,
        behavior_count=int(user_profile.get("behavior_count") or 0),
    )
    rows, missing_tag_codes = build_user_interest_rows_from_state(
        id_user=user_profile["id_user"],
        user_interest_state=user_interest_state,
    )
    upsert_user_interest_tags(
        supabase=supabase,
        rows=rows,
    )
    print_key_value_block(
        title="Kết quả bước 3:",
        data={
            "active_tag_count": len(tag_map),
            "raw_tag_count": len(onboarding_profile["raw_weights"]),
            "existing_user_interest_tag_count": len(existing_user_interest_rows),
            "persistence_mode": persistence_mode,
            "input_behavior_count": int(user_profile.get("behavior_count") or 0),
            "effective_behavior_count": effective_behavior_count,
            "positive_behavior_count": max(
                int(info.get("positive_behavior_count") or 0)
                for info in user_interest_state.values()
            ) if user_interest_state else 0,
            "negative_behavior_count": max(
                int(info.get("negative_behavior_count") or 0)
                for info in user_interest_state.values()
            ) if user_interest_state else 0,
            "user_interest_tag_rows_ready_to_upsert": len(rows),
            "user_interest_tag_rows_upserted": len(rows),
            "missing_tag_code_count": len(missing_tag_codes),
        },
    )
    print_user_interest_preview(user_interest_state)
    write_user_interest_profile(output_file=output_file, user_interest_state=user_interest_state)

    print_step(
        step_number=4,
        title="Trip Planner Interest",
        purpose="Doc trip_interest_choice va mapping tag de tao trip_weight, sau do ket hop voi user_interest_tag thanh effective_interest_weight.",
    )
    trip_interest_profile = build_trip_interest_profile(
        trip_interest_choice_rows=trip_interest_choice_rows,
        trip_interest_option_tag_rows=trip_interest_option_tag_rows,
    )
    effective_interest_result = build_effective_interest_state(
        user_interest_state=user_interest_state,
        trip_weight_map=trip_interest_profile["normalized_tag_weights"],
        trip_tag_info_map=trip_interest_profile["trip_tag_info_map"],
    )
    effective_interest_state = effective_interest_result["effective_interest_state"]
    print_key_value_block(
        title="Ket qua buoc 4:",
        data={
            "selected_trip_interest_option_count": len(trip_interest_profile["selected_options"]),
            "trip_raw_tag_count": len(trip_interest_profile["raw_tag_weights"]),
            "trip_normalized_tag_count": len(trip_interest_profile["normalized_tag_weights"]),
            "effective_interest_tag_count": len(effective_interest_result["effective_weight_map"]),
            "effective_interest_alpha": effective_interest_result["alpha"],
            "effective_interest_beta": effective_interest_result["beta"],
        },
    )
    write_named_items(
        output_file=output_file,
        title="FULL Selected trip interest options",
        items=trip_interest_profile["selected_options"],
    )
    write_weight_map(
        output_file=output_file,
        title="FULL Trip raw tag weights",
        weight_map=trip_interest_profile["raw_tag_weights"],
    )
    write_weight_map(
        output_file=output_file,
        title="FULL Trip normalized tag weights",
        weight_map=trip_interest_profile["normalized_tag_weights"],
    )
    write_weight_map(
        output_file=output_file,
        title="FULL Effective interest weights",
        weight_map=effective_interest_result["effective_weight_map"],
    )

    print_step(
        step_number=5,
        title="Tính TagMatch Và Xếp Hạng Địa Điểm",
        purpose="Lấy place_tag cho candidate places, tính TagMatch với hồ sơ sở thích user và xếp hạng giảm dần theo module1_score.",
    )
    place_ids = [
        place["id_place"]
        for place in final_places
        if place.get("id_place")
    ]
    place_tag_rows = fetch_place_tags_for_places(
        supabase=supabase,
        place_ids=place_ids,
    )
    enriched_places = attach_place_tags_to_places(final_places, place_tag_rows)
    ranked_places = rank_places_by_tag_match(
        places=enriched_places,
        user_interest_state=effective_interest_state,
        weight_field="effective_weight",
    )
    places_with_tags = [place for place in ranked_places if place.get("place_tag")]
    places_without_tags = [place for place in ranked_places if not place.get("place_tag")]
    print_key_value_block(
        title="Kết quả bước 5:",
        data={
            "candidate_place_count": len(ranked_places),
            "place_tag_row_count": len(place_tag_rows),
            "places_with_tags": len(places_with_tags),
            "places_without_tags": len(places_without_tags),
        },
    )
    print_place_preview(
        title="Preview Top places by TagMatch:",
        places=ranked_places,
        limit=run_settings["terminal_ranked_preview_limit"],
    )
    if places_without_tags:
        print_place_preview(
            title="Preview Places without any place_tag rows:",
            places=places_without_tags,
            limit=run_settings["terminal_candidate_preview_limit"],
        )
    write_full_places(
        output_file=output_file,
        title="FULL Ranked places by Module 1 score",
        places=ranked_places,
    )

    print_step(
        step_number=6,
        title="Diversity Slot-Based Theo Subcategory",
        purpose="Khong lay top global sau TagMatch. He thong xep hang trong tung subcategory, cap slot cho tung subcategory, roi lay top place theo slot de tao final candidate pool cho Module 2.",
    )
    user_selected_interests = build_user_selected_interests(user_profile)
    diversity_result = apply_diversity_selection(
        ranked_places=ranked_places,
        total_days=total_days,
        user_selected_interests=user_selected_interests,
        trip_selected_options=trip_interest_profile["selected_options"],
        trip_option_subcategory_rows=trip_interest_option_subcategory_rows,
    )
    diversified_top_k = diversity_result["diversified_top_k"]
    diversity_config = diversity_result["config"]
    diversity_summary = diversity_result["summary"]
    print_key_value_block(
        title="Ket qua buoc 6 - Diversity config:",
        data={
            "user_selected_interests": user_selected_interests,
            "priority_source": diversity_config.get("priority_source"),
            "selected_trip_interest_options": diversity_config.get("selected_trip_interest_options"),
            "profile": diversity_config["profile"],
            "top_k_for_module2": diversity_config["top_k"],
            "related_place_category_count": diversity_config["related_place_category_count"],
            "related_subcategory_count": diversity_config["related_subcategory_count"],
            "max_per_subcategory": diversity_config["max_per_subcategory"],
            "max_per_place_category": diversity_config["max_per_place_category"],
            "relaxed_max_per_subcategory": diversity_config["relaxed_max_per_subcategory"],
            "relaxed_max_per_place_category": diversity_config["relaxed_max_per_place_category"],
            "score_floor": diversity_config["score_floor"],
            "score_floor_ratio": diversity_config["score_floor_ratio"],
        },
    )
    print_key_value_block(
        title="Ket qua buoc 6 - Diversity summary:",
        data={
            "ranked_pool_count": len(ranked_places),
            "final_diversified_count": len(diversified_top_k),
            "global_baseline_top_k_count": diversity_config["top_k"],
            "global_baseline_avg_score": diversity_summary["avg_score_before"],
            "final_diversified_avg_score": diversity_summary["avg_score_after"],
            "min_expected_avg_score": diversity_summary["avg_score_after_min_expected"],
            "score_quality_ok": diversity_summary["score_quality_ok"],
            "quota_quality_ok": diversity_summary["quota_quality_ok"],
            "coverage_quality_ok": diversity_summary["coverage_quality_ok"],
            "slot_allocation_ok": diversity_summary["slot_allocation_ok"],
            "related_subcategory_count_in_pool": len(diversity_config["related_subcategories_in_pool"]),
            "allocated_subcategory_count": len(diversity_summary["slot_by_subcategory"]),
            "coverage_addition_count": len(diversity_summary["coverage_additions"]),
            "fill_action_count": len(diversity_summary["fill_logs"]),
            "trip_priority_subcategory_count": len(diversity_summary["trip_priority_by_subcategory"]),
            "strict_subcategory_violation_count": len(diversity_summary["strict_quota_violations"]["subcategory_violations"]),
            "strict_place_category_violation_count": len(diversity_summary["strict_quota_violations"]["place_category_violations"]),
            "missing_coverable_interest_count": len(diversity_summary["missing_coverable_interests_after"]),
        },
    )
    print_place_preview(
        title=f"Preview Final diversified places passed to Module 2: {len(diversified_top_k)}",
        places=diversified_top_k,
        limit=run_settings["terminal_ranked_preview_limit"],
    )
    write_full_places(
        output_file=output_file,
        title="FULL Final diversified places after slot-based Diversity",
        places=diversified_top_k,
    )
    write_places_grouped_by_subcategory(
        output_file=output_file,
        title="FULL Final diversified places grouped by subcategory",
        places=diversified_top_k,
    )
    write_named_items(
        output_file=output_file,
        title="FULL Diversity coverage additions",
        items=diversity_summary["coverage_additions"],
    )
    write_named_items(
        output_file=output_file,
        title="FULL Diversity slot allocation logs",
        items=diversity_summary["allocation_logs"],
    )
    write_named_items(
        output_file=output_file,
        title="FULL Diversity fill logs",
        items=diversity_summary["fill_logs"],
    )
    write_text_line(output_file, "=" * 100)
    write_text_line(output_file, "FULL Diversity config")
    write_text_line(output_file, "=" * 100)
    for key, value in diversity_config.items():
        write_text_line(output_file, f"{key}: {value}")
    write_text_line(output_file, "")
    write_text_line(output_file, "=" * 100)
    write_text_line(output_file, "FULL Diversity summary")
    write_text_line(output_file, "=" * 100)
    for key, value in diversity_summary.items():
        write_text_line(output_file, f"{key}: {value}")
    write_text_line(output_file, "")

    print_step(
        step_number=7,
        title="Module 2 - Initial K-means Clustering",
        purpose="Nhan candidate pool sau Diversity, kiem tra du lieu, gan duration fallback va gom dia diem thanh cum ngay ban dau.",
    )
    module2_result = build_module2_result(
        top_places=diversified_top_k,
        start_date=user_profile["start_date"],
        end_date=user_profile["end_date"],
        pace_level=user_profile.get("pace_level"),
    )
    print_key_value_block(
        title="Kết quả bước 7:",
        data={
            **module2_result["limits"],
            **module2_result["summary"],
        },
    )
    print_day_clusters_summary(
        title="Preview Initial day clusters after K-means:",
        day_clusters=module2_result.get("initial_day_clusters") or [],
    )
    write_day_clusters(
        output_file=output_file,
        title="FULL Initial day clusters after K-means",
        day_clusters=module2_result.get("initial_day_clusters") or [],
    )
    write_full_places(
        output_file=output_file,
        title="FULL Initial backup places after K-means",
        places=module2_result.get("initial_backup_places") or [],
    )

    print_step(
        step_number=8,
        title="Module 2 - Greedy Repair Và Kết Quả Cuối",
        purpose="Sửa các ngày thiếu điểm, quá nhiều điểm hoặc quá tải thời gian, sau đó trả day_clusters, backup_places và optional_places cho bước tối ưu tiếp theo.",
    )
    print_day_clusters_summary(
        title="Kết quả bước 8 - Final day clusters after Greedy Repair:",
        day_clusters=module2_result["day_clusters"],
    )
    print_key_value_block(
        title="Kết quả bước 8 - Summary:",
        data={
            "main_day_cluster_count": len(module2_result["day_clusters"]),
            "selected_main_place_count": module2_result["summary"]["selected_main_place_count"],
            "backup_place_count": module2_result["summary"]["backup_place_count"],
            "optional_place_count": module2_result["summary"]["optional_place_count"],
            "rejected_place_count": module2_result["summary"]["rejected_place_count"],
            "repair_action_count": module2_result["summary"]["repair_action_count"],
        },
    )
    print_repair_log_preview(
        title="Giải thích Greedy Repair:",
        repair_logs=module2_result["repair_logs"],
        limit=run_settings["terminal_candidate_preview_limit"],
    )
    if module2_result["backup_places"]:
        print_place_preview(
            title="Preview Backup places:",
            places=module2_result["backup_places"],
            limit=run_settings["terminal_candidate_preview_limit"],
        )
    if module2_result["optional_places"]:
        print_place_preview(
            title="Preview Optional places:",
            places=module2_result["optional_places"],
            limit=run_settings["terminal_candidate_preview_limit"],
        )
    if module2_result["rejected_places"]:
        print_place_preview(
            title="Preview Rejected places before Module 2 clustering:",
            places=module2_result["rejected_places"],
            limit=run_settings["terminal_candidate_preview_limit"],
        )

    write_day_clusters(
        output_file=output_file,
        title="FULL Final day clusters after Greedy Repair",
        day_clusters=module2_result["day_clusters"],
    )
    write_repair_logs(
        output_file=output_file,
        title="FULL Greedy Repair explanation logs",
        repair_logs=module2_result["repair_logs"],
    )
    write_full_places(
        output_file=output_file,
        title="FULL Backup places after Module 2",
        places=module2_result["backup_places"],
    )
    write_full_places(
        output_file=output_file,
        title="FULL Optional places after Module 2",
        places=module2_result["optional_places"],
    )
    write_full_places(
        output_file=output_file,
        title="FULL Rejected places before Module 2 clustering",
        places=module2_result["rejected_places"],
    )

    print_section("PIPELINE FINISHED")
    print("Kết luận:")
    print(
        "Pipeline đã chạy liền mạch từ phần lọc -> Module 1 -> Diversity -> Module 2. "
        "File TXT lưu đầy đủ từng bước, mục tiêu của bước, và kết quả chi tiết."
    )
    print()

    write_text_line(output_file, "=" * 100)
    write_text_line(output_file, "KẾT LUẬN CUỐI")
    write_text_line(output_file, "=" * 100)
    write_text_line(
        output_file,
        "Pipeline đã chạy liền mạch từ Filtering -> Module 1 -> Diversity -> Module 2.",
    )
    write_text_line(
        output_file,
        "Các section phía trên đã ghi rõ từng bước làm gì và kết quả của bước đó.",
    )


def main() -> None:
    original_stdout = sys.stdout

    with OUTPUT_FILE.open("w", encoding="utf-8") as output_file:
        sys.stdout = TeeStream(original_stdout, output_file)

        try:
            run_report(output_file=output_file)
        finally:
            sys.stdout.flush()
            sys.stdout = original_stdout

    print(f"Saved output to: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
