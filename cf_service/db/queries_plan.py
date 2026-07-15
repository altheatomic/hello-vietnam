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
            if place.get("type") == "lunch_break" or "id_place" not in place:
                continue
            rows.append({
                "id_component": str(uuid.uuid4()),
                "id_plan": id_plan,
                "day": day["day"],
                "time_part": place.get("slot"),
                "id_place": place["id_place"],
                "visit_order": place.get("order"),
                "slot": place.get("slot"),
                "start_time": place.get("start_time"),
                "end_time": place.get("end_time"),
                "estimated_travel_minutes": place.get("estimated_travel_minutes"),
                "cb_score": place.get("tag_match"),   # tag_match stored in cb_score column
                "cf_score": place.get("cf_score"),
                "final_score": place.get("final_score"),
            })

    if rows:
        supabase.table("plan_component").insert(rows).execute()

    return id_plan


def get_plan(supabase: Any, id_plan: str, id_user: str | None = None) -> dict:
    query = (
        supabase
        .table("plan")
        .select("id_plan, duration, start_at, end_at, city_province, created_at")
        .eq("id_plan", id_plan)
    )
    if id_user:
        query = query.eq("id_user", id_user)
    plan_resp = query.limit(1).execute()
    plan_rows = plan_resp.data or []
    if not plan_rows:
        return {}
    plan_row = plan_rows[0]

    components_resp = (
        supabase
        .table("plan_component")
        .select(
            "day,slot,visit_order,start_time,end_time,estimated_travel_minutes,"
            "cb_score,cf_score,final_score,id_place"
        )
        .eq("id_plan", id_plan)
        .order("day")
        .order("visit_order")
        .execute()
    )
    component_rows = components_resp.data or []

    # Fetch localized place names/coords via the VIEW (PostgREST has no FK
    # metadata on VIEWs, so embedded syntax won't work — query separately).
    place_ids = list({str(r["id_place"]) for r in component_rows if r.get("id_place")})
    print(f"[getPlan] place_query_view=place_localized_en place_ids={place_ids}")
    place_map: dict[str, dict] = {}
    if place_ids:
        places_resp = (
            supabase
            .table("place_localized_en")
            .select("id_place,name,latitude,longitude,cover_image,gallery")
            .in_("id_place", place_ids)
            .execute()
        )
        raw_places = places_resp.data or []
        print(
            f"[getPlan] raw_first_place="
            f"{raw_places[0] if raw_places else None}"
        )
        for p in raw_places:
            place_map[str(p["id_place"])] = p

    start_date = plan_row["start_at"]
    if isinstance(start_date, datetime.date) and not isinstance(start_date, datetime.datetime):
        start_date_obj = start_date
    else:
        start_date_obj = datetime.datetime.fromisoformat(str(start_date)).date()

    days_map: dict[int, list] = {}
    for r in component_rows:
        d = int(r["day"])
        place_data = place_map.get(str(r.get("id_place") or ""), {})
        days_map.setdefault(d, []).append({
            "day": d,
            "order": r.get("visit_order"),
            "visit_order": r.get("visit_order"),
            "slot": r.get("slot"),
            "start_time": r.get("start_time"),
            "end_time": r.get("end_time"),
            "estimated_travel_minutes": r.get("estimated_travel_minutes"),
            "tag_match": r.get("cb_score"),
            "cf_score": r.get("cf_score"),
            "final_score": r.get("final_score"),
            "id_place": place_data.get("id_place"),
            "name": place_data.get("name"),
            "latitude": place_data.get("latitude"),
            "longitude": place_data.get("longitude"),
            "cover_image": place_data.get("cover_image"),
            "gallery": place_data.get("gallery") or [],
        })

    first_response_place = next(
        (places[0] for places in days_map.values() if places),
        None,
    )
    print(f"[getPlan] response_first_place={first_response_place}")

    return {
        "id_plan": str(plan_row["id_plan"]),
        "start_at": str(plan_row["start_at"]),
        "end_at": str(plan_row["end_at"]),
        "city_province": str(plan_row.get("city_province") or ""),
        "created_at": str(plan_row["created_at"]),
        "days": [
            {
                "day": d,
                "date": (start_date_obj + datetime.timedelta(days=d - 1)).isoformat(),
                "places": places,
            }
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


def clone_plan(supabase: Any, id_plan: str, id_user: str) -> dict:
    """Copy a shared plan into a new independent plan owned by id_user."""
    plan_resp = (
        supabase
        .table("plan")
        .select("id_plan,id_user,duration,start_at,end_at,city_province")
        .eq("id_plan", id_plan)
        .limit(1)
        .execute()
    )
    plan_rows = plan_resp.data or []
    if not plan_rows:
        return {}
    src = plan_rows[0]

    comp_resp = (
        supabase
        .table("plan_component")
        .select(
            "day,time_part,id_place,visit_order,slot,"
            "estimated_travel_minutes,cb_score,cf_score,final_score"
        )
        .eq("id_plan", id_plan)
        .execute()
    )
    src_components = comp_resp.data or []

    new_plan_id = str(uuid.uuid4())
    supabase.table("plan").insert({
        "id_plan":       new_plan_id,
        "id_user":       id_user,
        "duration":      src["duration"],
        "start_at":      str(src["start_at"]),
        "end_at":        str(src["end_at"]),
        "city_province": src.get("city_province"),
        "status":        "saved",
        "created_at":    datetime.datetime.utcnow().isoformat(),
    }).execute()

    if src_components:
        new_rows = [
            {
                "id_component":             str(uuid.uuid4()),
                "id_plan":                  new_plan_id,
                "day":                      r["day"],
                "time_part":                r.get("time_part"),
                "id_place":                 r["id_place"],
                "visit_order":              r.get("visit_order"),
                "slot":                     r.get("slot"),
                "estimated_travel_minutes": r.get("estimated_travel_minutes"),
                "cb_score":                 r.get("cb_score"),
                "cf_score":                 r.get("cf_score"),
                "final_score":              r.get("final_score"),
            }
            for r in src_components
        ]
        supabase.table("plan_component").insert(new_rows).execute()

    return {"id_plan": new_plan_id, "status": "saved"}


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
