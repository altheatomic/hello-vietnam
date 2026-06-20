"""
db/queries_plan.py
Save / load trip plan using supabase-py (sync).

Table column notes (from migration 20260606000100_plan_trip_schema.sql):
  plan.city_province = uuid FK to city_province(id_city)  ← stores id_province value
  plan.duration      = text (number of days as string)
  plan_component.cb_score = numeric ← stores tag_match value from new pipeline
"""

import uuid
import datetime
from typing import Any


def save_plan(
    supabase: Any,
    id_user: str,
    id_province: str,
    n_days: int,
    start_at: datetime.date,
    days: list,
) -> str:
    id_plan = str(uuid.uuid4())
    end_at = start_at + datetime.timedelta(days=n_days - 1)

    supabase.table("plan").insert({
        "id_plan": id_plan,
        "id_user": id_user,
        "duration": str(n_days),
        "start_at": start_at.isoformat(),
        "end_at": end_at.isoformat(),
        "city_province": id_province,
    }).execute()

    rows = []
    for day in days:
        for place in day["places"]:
            rows.append({
                "id_component": str(uuid.uuid4()),
                "id_plan": id_plan,
                "day": day["day"],
                "time_part": place.get("slot"),
                "id_place": place["id_place"],
                "visit_order": place.get("order"),
                "slot": place.get("slot"),
                "estimated_travel_minutes": place.get("estimated_travel_minutes"),
                "cb_score": place.get("tag_match"),   # tag_match stored in cb_score column
                "cf_score": place.get("cf_score"),
                "final_score": place.get("final_score"),
            })

    if rows:
        supabase.table("plan_component").insert(rows).execute()

    return id_plan


def get_plan(supabase: Any, id_plan: str) -> dict:
    plan_resp = (
        supabase
        .table("plan")
        .select("id_plan, duration, start_at, end_at, city_province, created_at")
        .eq("id_plan", id_plan)
        .limit(1)
        .execute()
    )
    plan_rows = plan_resp.data or []
    if not plan_rows:
        return {}
    plan_row = plan_rows[0]

    components_resp = (
        supabase
        .table("plan_component")
        .select(
            """
            day,
            slot,
            visit_order,
            estimated_travel_minutes,
            cb_score,
            cf_score,
            final_score,
            place (
                id_place,
                name,
                latitude,
                longitude
            )
            """
        )
        .eq("id_plan", id_plan)
        .order("day")
        .order("visit_order")
        .execute()
    )
    component_rows = components_resp.data or []

    days_map: dict[int, list] = {}
    for r in component_rows:
        d = int(r["day"])
        place_data = r.get("place") or {}
        days_map.setdefault(d, []).append({
            "day": d,
            "slot": r.get("slot"),
            "visit_order": r.get("visit_order"),
            "estimated_travel_minutes": r.get("estimated_travel_minutes"),
            "tag_match": r.get("cb_score"),   # cb_score column stores tag_match value
            "cf_score": r.get("cf_score"),
            "final_score": r.get("final_score"),
            "id_place": place_data.get("id_place"),
            "name": place_data.get("name"),
            "latitude": place_data.get("latitude"),
            "longitude": place_data.get("longitude"),
        })

    return {
        "id_plan": str(plan_row["id_plan"]),
        "start_at": str(plan_row["start_at"]),
        "end_at": str(plan_row["end_at"]),
        "city_province": str(plan_row.get("city_province") or ""),
        "created_at": str(plan_row["created_at"]),
        "days": [
            {"day": d, "places": places}
            for d, places in sorted(days_map.items())
        ],
    }


def mark_plan_saved(
    supabase: Any,
    id_plan: str,
    id_user: str,
    custom_title: str = None,
) -> dict:
    update_data: dict = {"status": "saved"}
    if custom_title:
        update_data["custom_title"] = custom_title

    resp = (
        supabase
        .table("plan")
        .update(update_data)
        .eq("id_plan", id_plan)
        .eq("id_user", id_user)
        .execute()
    )
    if not (resp.data or []):
        return {}
    return {"id_plan": id_plan, "status": "saved"}


def fetch_saved_plans(supabase: Any, id_user: str) -> list:
    plans_resp = (
        supabase
        .table("plan")
        .select("id_plan, custom_title, duration, start_at, end_at, city_province, created_at")
        .eq("id_user", id_user)
        .eq("status", "saved")
        .order("created_at", desc=True)
        .limit(50)
        .execute()
    )
    plans = plans_resp.data or []
    if not plans:
        return []

    plan_ids = [str(p["id_plan"]) for p in plans]

    stops_resp = (
        supabase
        .table("plan_component")
        .select("id_component, id_plan, day, slot, visit_order, place(id_place, name)")
        .in_("id_plan", plan_ids)
        .eq("day", 1)
        .order("visit_order")
        .execute()
    )
    stops_by_plan: dict = {}
    for s in (stops_resp.data or []):
        pid = str(s["id_plan"])
        place_data = s.get("place") or {}
        stops_by_plan.setdefault(pid, []).append({
            "id": str(s["id_component"]),
            "slot": s.get("slot") or "",
            "time_label": _slot_to_time(s.get("slot") or ""),
            "title": place_data.get("name") or "",
            "note": "",
        })

    result = []
    for p in plans:
        pid = str(p["id_plan"])
        result.append({
            "id_plan": pid,
            "custom_title": p.get("custom_title"),
            "duration": p.get("duration") or "",
            "start_at": str(p["start_at"]),
            "end_at": str(p["end_at"]),
            "province_name": "",  # join not needed for display; can be added later
            "created_at": str(p["created_at"]),
            "stops": stops_by_plan.get(pid, []),
        })
    return result


def _slot_to_time(slot: str) -> str:
    return {
        "morning": "08:00",
        "afternoon": "13:00",
        "evening": "17:00",
        "lunch": "12:00",
    }.get(slot.lower(), "09:00")


def list_plans(supabase: Any, id_user: str) -> list:
    resp = (
        supabase
        .table("plan")
        .select("id_plan, duration, start_at, end_at, city_province, created_at")
        .eq("id_user", id_user)
        .order("created_at", desc=True)
        .limit(50)
        .execute()
    )
    return [
        {
            "id_plan": str(r["id_plan"]),
            "duration": r.get("duration"),
            "start_at": str(r["start_at"]),
            "end_at": str(r["end_at"]),
            "city_province": str(r.get("city_province") or ""),
            "created_at": str(r["created_at"]),
        }
        for r in (resp.data or [])
    ]
