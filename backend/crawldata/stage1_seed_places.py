#!/usr/bin/env python3
"""
Seed stage-1 demo places for Hello Vietnam into Supabase.

Source strategy
- Uses OpenStreetMap Overpass API as the primary source for MVP/demo seed.
- Pulls places for 10 target cities/areas in Vietnam.
- Normalizes results into the `public.place` schema.
- Upserts into Supabase using deterministic UUIDs so reruns are idempotent.

Required env vars
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY   (recommended for bulk seed / bypass RLS)
- SUBCAT_RESTAURANT_ID
- SUBCAT_CAFE_ID
- SUBCAT_ATTRACTION_ID
- SUBCAT_SHOP_MARKET_ID

Optional env vars
- OVERPASS_URL                default: https://overpass-api.de/api/interpreter
- PLACE_STATUS_DEFAULT        default: active
- REQUEST_TIMEOUT_SECONDS     default: 90
- UPSERT_BATCH_SIZE           default: 200
- SLEEP_BETWEEN_QUERIES       default: 1.0

Install
    pip install supabase requests python-dotenv

Usage
    python stage1_seed_places.py --city all
    python stage1_seed_places.py --city hanoi --dry-run
    python stage1_seed_places.py --city all --export-json /tmp/place_seed.json

Notes
- This script intentionally uses bbox/radius-style Overpass queries and then limits in Python.
- OSM does not consistently provide ratings or photos, so those fields may remain null.
- `id_province`, `id_region`, `id_zone` are mapped to your project's uploaded CSV ids.
- Some city -> new province mappings are assumptions because your project uses a 34-province model.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import re
import time
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional, Tuple

import requests
from dotenv import load_dotenv
from supabase import create_client

from source_identity import legacy_place_uuid, source_external_id


load_dotenv()

OVERPASS_URL = os.getenv("OVERPASS_URL", "https://overpass-api.de/api/interpreter")
REQUEST_TIMEOUT_SECONDS = int(os.getenv("REQUEST_TIMEOUT_SECONDS", "90"))
UPSERT_BATCH_SIZE = int(os.getenv("UPSERT_BATCH_SIZE", "200"))
SLEEP_BETWEEN_QUERIES = float(os.getenv("SLEEP_BETWEEN_QUERIES", "1.0"))
PLACE_STATUS_DEFAULT = os.getenv("PLACE_STATUS_DEFAULT", "active")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

SUBCATEGORY_IDS = {
    "restaurant": os.getenv("SUBCAT_RESTAURANT_ID"),
    "cafe": os.getenv("SUBCAT_CAFE_ID"),
    "attraction": os.getenv("SUBCAT_ATTRACTION_ID"),
    "shop_market": os.getenv("SUBCAT_SHOP_MARKET_ID"),
}

REGIONS = {
    "DNB": {
        "id_region": "2fe32ad8-68d5-4aa7-b90a-e15c91f1192e",
        "id_zone": "60c29835-f8e0-4551-8e57-0b72c0c9e545",
    },
    "BTB": {
        "id_region": "6488aef5-8e4c-4e17-9243-fad552451f78",
        "id_zone": "b1f42ca3-cc45-42db-b654-b11053cbc1a5",
    },
    "DHNTB_TN": {
        "id_region": "6a427bfc-d1dd-4ef5-b3c8-342b1725232b",
        "id_zone": "b1f42ca3-cc45-42db-b654-b11053cbc1a5",
    },
    "DBSH": {
        "id_region": "78d956ba-ce79-47b6-9db3-49be0336f794",
        "id_zone": "d2ba2c6a-92c8-471d-8bc2-371f7278e808",
    },
    "TDMNPB": {
        "id_region": "ddb8364e-2824-4867-b920-b2c02083aa80",
        "id_zone": "d2ba2c6a-92c8-471d-8bc2-371f7278e808",
    },
    "DBSCL": {
        "id_region": "f483a1f6-f7b7-4925-bf8f-eb4e8b4b6681",
        "id_zone": "60c29835-f8e0-4551-8e57-0b72c0c9e545",
    },
}

PROVINCES = {
    "Hà Nội": {"id_province": "3355c4a1-ccb1-46be-99e5-046d5f55b891", "region_code": "DBSH"},
    "Hồ Chí Minh": {"id_province": "094014a7-b8f6-481a-bbce-5ed6cdd457c5", "region_code": "DNB"},
    "Đà Nẵng": {"id_province": "925a0422-ac39-4406-b0bb-8b9284cefb88", "region_code": "DHNTB_TN"},
    "Huế": {"id_province": "b5f3ef5e-dc49-4482-88e3-a8048cb32639", "region_code": "BTB"},
    # Assumption under the user's 34-province model: Hội An is stored under Đà Nẵng.
    "Hội An": {"id_province": "925a0422-ac39-4406-b0bb-8b9284cefb88", "region_code": "DHNTB_TN"},
    "Đà Lạt": {"id_province": "49fa7ad8-b892-494d-a712-bb49802200c1", "region_code": "DHNTB_TN"},
    "Nha Trang": {"id_province": "575ecef9-d2b5-4cc0-9777-87e5ecd19a93", "region_code": "DHNTB_TN"},
    # Assumption under the user's 34-province model: Phú Quốc is stored under An Giang.
    "Phú Quốc": {"id_province": "048f25d9-ff8c-4185-97b0-a0cabda5369d", "region_code": "DBSCL"},
    "Cần Thơ": {"id_province": "69e1a0ac-2830-48ac-8159-f37041b2f2a2", "region_code": "DBSCL"},
    "Hạ Long": {"id_province": "8f9d18e3-7e24-4e36-bf50-a3823c1f78df", "region_code": "DBSH"},
}


@dataclass(frozen=True)
class CityTarget:
    key: str
    display_name: str
    province_name: str
    lat: float
    lon: float
    radius_m: int
    target_counts: Dict[str, int]


CITY_TARGETS: Dict[str, CityTarget] = {
    "hanoi": CityTarget("hanoi", "Hà Nội", "Hà Nội", 21.028511, 105.804817, 18000, {"restaurant": 50, "cafe": 30, "attraction": 30, "shop_market": 20}),
    "hcmc": CityTarget("hcmc", "TP.HCM", "Hồ Chí Minh", 10.775659, 106.700424, 18000, {"restaurant": 50, "cafe": 30, "attraction": 30, "shop_market": 20}),
    "danang": CityTarget("danang", "Đà Nẵng", "Đà Nẵng", 16.054407, 108.202167, 14000, {"restaurant": 50, "cafe": 30, "attraction": 30, "shop_market": 20}),
    "hue": CityTarget("hue", "Huế", "Huế", 16.463713, 107.590866, 10000, {"restaurant": 50, "cafe": 30, "attraction": 30, "shop_market": 20}),
    "hoian": CityTarget("hoian", "Hội An", "Hội An", 15.880058, 108.338047, 7000, {"restaurant": 50, "cafe": 30, "attraction": 30, "shop_market": 20}),
    "dalat": CityTarget("dalat", "Đà Lạt", "Đà Lạt", 11.940419, 108.458313, 9000, {"restaurant": 50, "cafe": 30, "attraction": 30, "shop_market": 20}),
    "nhatrang": CityTarget("nhatrang", "Nha Trang", "Nha Trang", 12.238791, 109.196749, 10000, {"restaurant": 50, "cafe": 30, "attraction": 30, "shop_market": 20}),
    "phuquoc": CityTarget("phuquoc", "Phú Quốc", "Phú Quốc", 10.289879, 103.984019, 12000, {"restaurant": 50, "cafe": 30, "attraction": 30, "shop_market": 20}),
    "cantho": CityTarget("cantho", "Cần Thơ", "Cần Thơ", 10.045162, 105.746857, 12000, {"restaurant": 50, "cafe": 30, "attraction": 30, "shop_market": 20}),
    "halong": CityTarget("halong", "Hạ Long", "Hạ Long", 20.951698, 107.056681, 12000, {"restaurant": 50, "cafe": 30, "attraction": 30, "shop_market": 20}),
}


CATEGORY_QUERIES: Dict[str, Dict[str, Any]] = {
    "restaurant": {
        "subcategory_key": "restaurant",
        "tags": [("amenity", ["restaurant", "fast_food", "food_court"])],
        "sort_boost": ["name", "opening_hours", "website", "phone", "addr:street"],
    },
    "cafe": {
        "subcategory_key": "cafe",
        "tags": [("amenity", ["cafe", "ice_cream"])],
        "sort_boost": ["name", "opening_hours", "website", "phone", "addr:street"],
    },
    "attraction": {
        "subcategory_key": "attraction",
        "tags": [
            ("tourism", ["attraction", "museum", "gallery", "viewpoint", "zoo", "theme_park", "aquarium"]),
            ("historic", ["monument", "castle", "fort", "archaeological_site", "memorial"]),
            ("leisure", ["park", "garden"]),
        ],
        "sort_boost": ["name", "website", "wikimedia_commons", "image"],
    },
    "shop_market": {
        "subcategory_key": "shop_market",
        "tags": [
            ("amenity", ["marketplace"]),
            ("shop", ["mall", "gift", "department_store", "supermarket", "convenience", "souvenir"]),
        ],
        "sort_boost": ["name", "opening_hours", "website", "phone", "addr:street"],
    },
}


def require_env() -> None:
    missing = []
    if not SUPABASE_URL:
        missing.append("SUPABASE_URL")
    if not SUPABASE_KEY:
        missing.append("SUPABASE_SERVICE_ROLE_KEY")
    for key, value in SUBCATEGORY_IDS.items():
        if not value:
            missing.append(f"SUBCAT_{key.upper()}_ID")
    if missing:
        raise SystemExit("Missing required env vars: " + ", ".join(missing))


def backoff_sleep(attempt: int) -> None:
    time.sleep(min(10, (2 ** attempt) + random.random()))


def overpass_query(city: CityTarget, category: str) -> str:
    spec = CATEGORY_QUERIES[category]
    pieces: List[str] = []
    for key, values in spec["tags"]:
        for value in values:
            pieces.append(f'node["{key}"="{value}"](around:{city.radius_m},{city.lat},{city.lon});')
            pieces.append(f'way["{key}"="{value}"](around:{city.radius_m},{city.lat},{city.lon});')
            pieces.append(f'relation["{key}"="{value}"](around:{city.radius_m},{city.lat},{city.lon});')
    union = "\n  ".join(pieces)
    return f"""
[out:json][timeout:60];
(
  {union}
);
out center tags;
""".strip()


def fetch_overpass(city: CityTarget, category: str, retries: int = 4) -> List[Dict[str, Any]]:
    query = overpass_query(city, category)
    headers = {"Accept": "application/json"}
    for attempt in range(retries):
        try:
            response = requests.post(
                OVERPASS_URL,
                data=query.encode("utf-8"),
                headers=headers,
                timeout=REQUEST_TIMEOUT_SECONDS,
            )
            response.raise_for_status()
            payload = response.json()
            return payload.get("elements", [])
        except Exception as exc:
            if attempt == retries - 1:
                raise RuntimeError(f"Overpass failed for {city.key}/{category}: {exc}") from exc
            backoff_sleep(attempt)
    return []


def normalize_text(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    value = re.sub(r"\s+", " ", str(value)).strip()
    return value or None


def compose_address(tags: Dict[str, Any]) -> Optional[str]:
    parts = [
        tags.get("addr:housenumber"),
        tags.get("addr:street"),
        tags.get("addr:suburb"),
        tags.get("addr:district"),
        tags.get("addr:city"),
        tags.get("addr:province"),
    ]
    cleaned = [normalize_text(x) for x in parts if normalize_text(x)]
    if cleaned:
        return ", ".join(cleaned)
    return normalize_text(tags.get("addr:full"))


TIME_RE = re.compile(r"(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})")


def extract_time_range(opening_hours: Optional[str]) -> Tuple[Optional[str], Optional[str]]:
    if not opening_hours:
        return None, None
    match = TIME_RE.search(opening_hours)
    if not match:
        return None, None
    return match.group(1), match.group(2)


def clean_url(url: Optional[str]) -> Optional[str]:
    url = normalize_text(url)
    if not url:
        return None
    if url.startswith("http://") or url.startswith("https://"):
        return url
    if re.match(r"^[\w.-]+\.[a-z]{2,}(/.*)?$", url, re.I):
        return "https://" + url
    return None


def pick_cover_image(tags: Dict[str, Any]) -> Optional[str]:
    image = clean_url(tags.get("image"))
    if image:
        return image
    return None


def score_element(element: Dict[str, Any], city: CityTarget, category: str) -> float:
    tags = element.get("tags", {})
    score = 0.0
    if tags.get("name"):
        score += 10
    for key in CATEGORY_QUERIES[category]["sort_boost"]:
        if tags.get(key):
            score += 2
    lat = element.get("lat") or (element.get("center") or {}).get("lat")
    lon = element.get("lon") or (element.get("center") or {}).get("lon")
    if lat is not None and lon is not None:
        dist_km = haversine_km(city.lat, city.lon, float(lat), float(lon))
        score += max(0, 8 - min(dist_km, 8))
    t = tags.get("tourism")
    if category == "attraction" and t in {"museum", "attraction", "viewpoint"}:
        score += 3
    return score


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlon / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def dedupe_elements(elements: Iterable[Dict[str, Any]]) -> List[Dict[str, Any]]:
    seen: set[str] = set()
    deduped: List[Dict[str, Any]] = []
    for el in elements:
        key = f"{el.get('type')}:{el.get('id')}"
        if key in seen:
            continue
        seen.add(key)
        deduped.append(el)
    return deduped


def generate_description(display_name: str, city_name: str, category: str, address: Optional[str], tags: Dict[str, Any]) -> str:
    label_map = {
        "restaurant": "địa điểm ăn uống",
        "cafe": "quán cà phê",
        "attraction": "điểm tham quan",
        "shop_market": "địa điểm mua sắm hoặc chợ",
    }
    pieces = [f"{display_name} là {label_map.get(category, 'địa điểm')} tại {city_name}."]
    if address:
        pieces.append(f"Địa chỉ: {address}.")
    subtype = tags.get("cuisine") or tags.get("tourism") or tags.get("shop") or tags.get("amenity") or tags.get("historic")
    if subtype:
        pieces.append(f"Loại hình nổi bật: {str(subtype).replace('_', ' ')}.")
    if tags.get("opening_hours"):
        pieces.append("Địa điểm có thông tin giờ mở cửa trên nguồn OSM.")
    return " ".join(pieces)


def deterministic_place_uuid(source: str, source_place_id: str) -> str:
    # Keep the original UUID namespace for places already seeded before the
    # freshness migration. This makes a rerun update the existing row.
    external_id = source_place_id
    if not external_id.startswith(f"{source}:"):
        external_id = source_external_id(source, external_id)
    return legacy_place_uuid(source, external_id)


def normalize_element(city: CityTarget, category: str, element: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    tags = element.get("tags", {})
    name = normalize_text(tags.get("name"))
    if not name:
        return None

    province = PROVINCES[city.province_name]
    region = REGIONS[province["region_code"]]

    lat = element.get("lat") or (element.get("center") or {}).get("lat")
    lon = element.get("lon") or (element.get("center") or {}).get("lon")
    if lat is None or lon is None:
        return None

    opening_hours = normalize_text(tags.get("opening_hours"))
    timespan, timeclose = extract_time_range(opening_hours)
    address = compose_address(tags)
    website = clean_url(tags.get("contact:website") or tags.get("website"))
    phone = normalize_text(tags.get("contact:phone") or tags.get("phone"))
    cover_image = pick_cover_image(tags)
    gallery = [{"url": cover_image, "source": "osm"}] if cover_image else None
    average_rating = None
    if tags.get("stars"):
        try:
            average_rating = round(float(str(tags["stars"]).replace(",", ".")), 1)
        except Exception:
            average_rating = None

    source_place_id = source_external_id(
        "osm", f"{element.get('type')}:{element.get('id')}"
    )
    row = {
        "id_place": deterministic_place_uuid("osm", source_place_id),
        "id_place_subcategory": SUBCATEGORY_IDS[CATEGORY_QUERIES[category]["subcategory_key"]],
        "name": name,
        "description": generate_description(name, city.display_name, category, address, tags),
        "timespan": timespan,
        "timeclose": timeclose,
        "status": PLACE_STATUS_DEFAULT,
        "cover_image": cover_image,
        "gallery": gallery,
        "address": address,
        "latitude": float(lat),
        "longitude": float(lon),
        "source": "osm",
        "source_place_id": source_place_id,
        "average_rating": average_rating,
        "phone": phone,
        "website": website,
        "id_province": province["id_province"],
        "id_region": region["id_region"],
        "id_zone": region["id_zone"],
        "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    return row


def fetch_city_category(city: CityTarget, category: str) -> List[Dict[str, Any]]:
    elements = fetch_overpass(city, category)
    elements = dedupe_elements(elements)
    scored = sorted(elements, key=lambda el: score_element(el, city, category), reverse=True)
    rows: List[Dict[str, Any]] = []
    names_seen: set[str] = set()

    for element in scored:
        row = normalize_element(city, category, element)
        if not row:
            continue
        normalized_name = normalize_text(row["name"]).lower()
        rounded_geo = f"{round(row['latitude'], 4)}:{round(row['longitude'], 4)}"
        dedupe_key = f"{normalized_name}:{rounded_geo}"
        if dedupe_key in names_seen:
            continue
        names_seen.add(dedupe_key)
        rows.append(row)
        if len(rows) >= city.target_counts[category]:
            break
    return rows


def build_seed(city_keys: List[str]) -> List[Dict[str, Any]]:
    all_rows: List[Dict[str, Any]] = []
    seen_ids: set[str] = set()

    for city_key in city_keys:
        city = CITY_TARGETS[city_key]
        print(f"\n=== {city.display_name} ===")
        for category in ["restaurant", "cafe", "attraction", "shop_market"]:
            print(f"Fetching {category} ...", flush=True)
            rows = fetch_city_category(city, category)
            print(f"  -> kept {len(rows)} rows")
            for row in rows:
                if row["id_place"] not in seen_ids:
                    seen_ids.add(row["id_place"])
                    all_rows.append(row)
            time.sleep(SLEEP_BETWEEN_QUERIES)
    return all_rows


def chunked(seq: List[Dict[str, Any]], size: int) -> Iterable[List[Dict[str, Any]]]:
    for i in range(0, len(seq), size):
        yield seq[i:i + size]


def upsert_rows(rows: List[Dict[str, Any]]) -> None:
    client = create_client(SUPABASE_URL, SUPABASE_KEY)
    total = 0
    for batch in chunked(rows, UPSERT_BATCH_SIZE):
        client.table("place").upsert(batch, on_conflict="id_place").execute()
        total += len(batch)
        print(f"Upserted {total}/{len(rows)}")

    # Keep provenance in the generic freshness table as well as the legacy
    # place columns. New OSM rows must be visible to the scheduled checker on
    # the same run that inserts them.
    freshness_rows = [
        {
            "content_type": "place",
            "content_id": row["id_place"],
            "source_type": row["source"],
            "source_url": osm_source_url(row["source_place_id"]),
            "source_external_id": row["source_place_id"],
            "availability_type": "business",
            "freshness_status": "due",
            "next_check_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
        for row in rows
    ]
    for batch in chunked(freshness_rows, UPSERT_BATCH_SIZE):
        client.table("content_freshness").upsert(
            batch,
            on_conflict="content_type,content_id",
        ).execute()


def osm_source_url(source_external_id_value: str) -> str:
    """Convert ``osm:node:123`` into a stable OSM element URL."""

    token = str(source_external_id_value).strip()
    if token.startswith("osm:"):
        token = token[4:]
    return f"https://www.openstreetmap.org/{token.replace(':', '/')}"


def export_json(rows: List[Dict[str, Any]], path: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Seed stage-1 places into Supabase from OSM Overpass")
    parser.add_argument("--city", default="all", help="One city key or 'all'. Keys: " + ", ".join(CITY_TARGETS.keys()))
    parser.add_argument("--dry-run", action="store_true", help="Fetch and normalize only, do not write to Supabase")
    parser.add_argument("--export-json", default=None, help="Optional path to export normalized rows as JSON")
    return parser.parse_args()


def validate_args(args: argparse.Namespace) -> List[str]:
    if args.city == "all":
        return list(CITY_TARGETS.keys())
    if args.city not in CITY_TARGETS:
        raise SystemExit(f"Unknown city '{args.city}'. Valid values: all, " + ", ".join(CITY_TARGETS.keys()))
    return [args.city]


def main() -> None:
    args = parse_args()
    require_env()
    city_keys = validate_args(args)
    rows = build_seed(city_keys)

    print(f"\nNormalized rows: {len(rows)}")
    if args.export_json:
        export_json(rows, args.export_json)
        print(f"Exported JSON to {args.export_json}")

    if args.dry_run:
        print("Dry run complete. No data was written to Supabase.")
        return

    upsert_rows(rows)
    print("Done.")


if __name__ == "__main__":
    main()
