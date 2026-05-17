import argparse
import csv
import json
import os
import re
import time
import uuid
from dataclasses import dataclass, asdict
from typing import Any, Dict, List, Optional
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup, Tag, NavigableString


HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9,vi;q=0.8",
}

SESSION = requests.Session()
SESSION.headers.update(HEADERS)

# =========================
# Reliable curated seeds
# =========================

ACTIVITY_SEED_URLS = [
    "https://en.wikipedia.org/wiki/Ha_Long_Bay",
    "https://en.wikipedia.org/wiki/Phong_Nha-K%E1%BA%BB_B%C3%A0ng_National_Park",
    "https://en.wikipedia.org/wiki/Ba_Na_Hills",
    "https://en.wikipedia.org/wiki/C%E1%BB%A7_Chi_tunnels",
    "https://en.wikipedia.org/wiki/Tr%C3%A0ng_An_Scenic_Landscape_Complex",
    "https://en.wikipedia.org/wiki/Hoi_An",
    "https://en.wikipedia.org/wiki/Imperial_City_of_Hu%E1%BA%BF",
    "https://en.wikipedia.org/wiki/Temple_of_Literature,_Hanoi",
    "https://en.wikipedia.org/wiki/Ho%C3%A0n_Ki%E1%BA%BFm_Lake",
    "https://en.wikipedia.org/wiki/M%E1%BB%B9_S%C6%A1n",
    "https://en.wikipedia.org/wiki/Fansipan",
    "https://en.wikipedia.org/wiki/Mekong_Delta",
    "https://en.wikipedia.org/wiki/C%C3%A1t_B%C3%A0_Island",
    "https://en.wikipedia.org/wiki/Hang_S%C6%A1n_%C4%90o%C3%B2ng",
    "https://en.wikipedia.org/wiki/Golden_Bridge_(Vietnam)",
]

CULTURE_SEED_URLS = [
    "https://en.wikipedia.org/wiki/Water_puppetry",
    "https://en.wikipedia.org/wiki/T%E1%BA%BFt",
    "https://en.wikipedia.org/wiki/%C3%81o_d%C3%A0i",
    "https://en.wikipedia.org/wiki/Ca_tr%C3%B9",
    "https://en.wikipedia.org/wiki/Quan_h%E1%BB%8D",
    "https://en.wikipedia.org/wiki/Nh%C3%A3_nh%E1%BA%A1c",
    "https://en.wikipedia.org/wiki/%C4%90%E1%BB%9Dn_ca_t%C3%A0i_t%E1%BB%AD",
    "https://en.wikipedia.org/wiki/B%C3%A0i_ch%C3%B2i",
    "https://en.wikipedia.org/wiki/Xoan_singing",
    "https://en.wikipedia.org/wiki/Practices_related_to_the_Viet_beliefs_in_the_Mother_Goddesses_of_Three_Realms",
]

# Used as a guaranteed fallback when the list page layout changes
LOCAL_PRODUCT_SEED_URLS = [
    "https://en.wikipedia.org/wiki/Phu_Quoc_fish_sauce",
    "https://en.wikipedia.org/wiki/N%C3%B3n_l%C3%A1",
    "https://en.wikipedia.org/wiki/%C3%81o_d%C3%A0i",
    "https://en.wikipedia.org/wiki/B%C3%A1nh_p%C3%ADa",
    "https://en.wikipedia.org/wiki/B%C3%A1nh_ph%E1%BB%93ng_t%C3%B4m",
    "https://en.wikipedia.org/wiki/B%C3%A1nh_tr%C3%A1ng",
    "https://en.wikipedia.org/wiki/Coconut_candy",
    "https://en.wikipedia.org/wiki/B%C3%A1nh_%C4%91%E1%BA%ADu_xanh",
    "https://en.wikipedia.org/wiki/Ph%E1%BB%9F",
    "https://en.wikipedia.org/wiki/B%C3%A1nh_ch%C6%B0ng",
]

WIKI_SPECIALITIES_URL = "https://en.wikipedia.org/wiki/List_of_Vietnamese_culinary_specialities"


# =========================
# Utils
# =========================

def fetch_html(url: str, sleep_sec: float = 0.6) -> str:
    time.sleep(sleep_sec)
    resp = SESSION.get(url, timeout=30)
    resp.raise_for_status()
    return resp.text


def soup_from_url(url: str) -> BeautifulSoup:
    return BeautifulSoup(fetch_html(url), "lxml")


def clean_text(text: Optional[str]) -> Optional[str]:
    if not text:
        return None
    text = re.sub(r"\s+", " ", text).strip()
    return text or None


def strip_citations(text: Optional[str]) -> Optional[str]:
    text = clean_text(text)
    if not text:
        return None
    text = re.sub(r"\[\d+\]", "", text)
    text = re.sub(r"\[\s*[a-zA-Z].*?\]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def absolute_url(base: str, href: Optional[str]) -> Optional[str]:
    if not href:
        return None
    return urljoin(base, href)


def to_short_description(text: Optional[str], limit: int = 180) -> Optional[str]:
    text = strip_citations(text)
    if not text:
        return None
    if len(text) <= limit:
        return text
    return text[: limit - 3].rstrip() + "..."


def stringify_value(value: Any) -> Any:
    if value is None:
        return ""
    if isinstance(value, (list, dict)):
        return json.dumps(value, ensure_ascii=False)
    return value


def dump_json(data: List[Dict[str, Any]], output_path: str):
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def dump_csv(data: List[Dict[str, Any]], output_path: str):
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)

    if not data:
        with open(output_path, "w", encoding="utf-8-sig", newline="") as f:
            f.write("")
        return

    fieldnames: List[str] = []
    seen = set()
    for row in data:
        for key in row.keys():
            if key not in seen:
                seen.add(key)
                fieldnames.append(key)

    with open(output_path, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in data:
            writer.writerow({k: stringify_value(row.get(k)) for k in fieldnames})


def first_paragraph(soup: BeautifulSoup) -> Optional[str]:
    for p in soup.select("p"):
        txt = strip_citations(p.get_text(" ", strip=True))
        if txt and len(txt) > 40:
            return txt
    return None


def first_image(soup: BeautifulSoup, base_url: str) -> Optional[str]:
    meta = soup.select_one("meta[property='og:image']")
    if meta and meta.get("content"):
        img = meta.get("content")
        if "enwiki-25.svg" in img:
            return None
        return img

    img = soup.select_one("table.infobox img, figure img, img")
    if img and img.get("src"):
        src = img.get("src")
        if src.startswith("//"):
            src = "https:" + src
        else:
            src = absolute_url(base_url, src)
        if src and "enwiki-25.svg" in src:
            return None
        return src
    return None


def dedupe_rows(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    out: Dict[str, Dict[str, Any]] = {}
    for row in rows:
        key = row["name"].strip().lower()
        if key not in out:
            out[key] = row
    return list(out.values())


def heading_text(node: Tag) -> Optional[str]:
    if not node:
        return None
    txt = strip_citations(node.get_text(" ", strip=True))
    if txt:
        txt = txt.replace("[edit]", "").strip()
    return txt


# =========================
# Data models
# =========================

@dataclass
class ActivityRecord:
    id: str
    name: str
    cover_image: Optional[str]
    gallery: Optional[List[str]]
    short_description: Optional[str]
    detailed_description: Optional[str]
    activity_type: Optional[str]
    opening_hours: Optional[Dict[str, Any]]
    price_range: Optional[str]
    safety_notes: Optional[str]
    average_rating: Optional[float]
    review_count: int
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


@dataclass
class CultureRecord:
    id: str
    name: str
    cover_image: Optional[str]
    gallery: Optional[List[str]]
    short_description: Optional[str]
    detailed_description: Optional[str]
    origin_history: Optional[str]
    cultural_significance: Optional[str]
    event_time: Optional[str]
    etiquette: Optional[str]
    notable_figures: Optional[str]
    average_rating: Optional[float]
    review_count: int
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


@dataclass
class LocalProductRecord:
    id: str
    name: str
    cover_image: Optional[str]
    gallery: Optional[List[str]]
    short_description: Optional[str]
    detailed_description: Optional[str]
    category: Optional[str]
    storage_transport: Optional[str]
    price_range: Optional[str]
    trusted_places: Optional[str]
    average_rating: Optional[float]
    review_count: int
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


# =========================
# Activity
# =========================

def extract_activity_type(name: str, desc: Optional[str]) -> str:
    text = f"{name} {desc or ''}".lower()
    rules = [
        ("museum", "museum"),
        ("citadel", "historical"),
        ("imperial city", "historical"),
        ("tunnel", "historical"),
        ("bridge", "sightseeing"),
        ("lake", "sightseeing"),
        ("bay", "nature"),
        ("island", "nature"),
        ("delta", "nature"),
        ("mountain", "nature"),
        ("park", "nature"),
        ("cave", "nature"),
        ("beach", "nature"),
        ("sanctuary", "culture"),
        ("temple", "culture"),
        ("ancient town", "city walk"),
        ("old town", "city walk"),
    ]
    for keyword, value in rules:
        if keyword in text:
            return value
    return "sightseeing"


def infer_safety_notes(name: str, desc: Optional[str]) -> Optional[str]:
    text = f"{name} {desc or ''}".lower()
    notes = []
    if any(k in text for k in ["bay", "island", "mountain", "park", "cave", "delta"]):
        notes.append("Check weather conditions before visiting.")
    if any(k in text for k in ["tunnel", "cave", "mountain"]):
        notes.append("Wear suitable shoes and follow on-site safety instructions.")
    if any(k in text for k in ["bridge", "town", "city", "lake"]):
        notes.append("Keep personal belongings secure in crowded areas.")
    return " ".join(notes) if notes else None


def crawl_activities(urls: List[str]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []

    for url in urls:
        try:
            soup = soup_from_url(url)
            title = heading_text(soup.select_one("h1"))
            if not title:
                continue

            desc = first_paragraph(soup)
            img = first_image(soup, url)

            record = ActivityRecord(
                id=str(uuid.uuid4()),
                name=title,
                cover_image=img,
                gallery=[img] if img else None,
                short_description=to_short_description(desc),
                detailed_description=desc,
                activity_type=extract_activity_type(title, desc),
                opening_hours=None,
                price_range=None,
                safety_notes=infer_safety_notes(title, desc),
                average_rating=None,
                review_count=0,
            )
            rows.append(asdict(record))
        except Exception as e:
            print(f"[WARN] activity failed for {url}: {e}")

    return dedupe_rows(rows)


# =========================
# Culture
# =========================

def infer_cultural_significance(name: str, desc: Optional[str]) -> Optional[str]:
    text = f"{name} {desc or ''}".lower()
    if "unesco" in text:
        return "Recognized as an important part of Vietnamese cultural heritage."
    if any(k in text for k in ["traditional", "folk", "court music", "ritual", "festival"]):
        return "Important part of Vietnamese cultural heritage."
    return None


def infer_event_time(name: str, desc: Optional[str]) -> Optional[str]:
    text = f"{name} {desc or ''}".lower()
    if "tet" in text or "tết" in text:
        return "Lunar New Year period"
    if "spring" in text:
        return "Spring season"
    return None


def crawl_culture(urls: List[str]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []

    for url in urls:
        try:
            soup = soup_from_url(url)
            title = heading_text(soup.select_one("h1"))
            if not title:
                continue

            desc = first_paragraph(soup)
            img = first_image(soup, url)

            record = CultureRecord(
                id=str(uuid.uuid4()),
                name=title,
                cover_image=img,
                gallery=[img] if img else None,
                short_description=to_short_description(desc),
                detailed_description=desc,
                origin_history=desc,
                cultural_significance=infer_cultural_significance(title, desc),
                event_time=infer_event_time(title, desc),
                etiquette=None,
                notable_figures=None,
                average_rating=None,
                review_count=0,
            )
            rows.append(asdict(record))
        except Exception as e:
            print(f"[WARN] culture failed for {url}: {e}")

    return dedupe_rows(rows)


# =========================
# Local products
# =========================

def normalize_product_name(text: str) -> str:
    text = strip_citations(text) or ""
    text = re.split(r"\s[-–]\s", text, maxsplit=1)[0].strip()
    text = re.split(r"\s\(", text, maxsplit=1)[0].strip()
    text = re.sub(r"\s+", " ", text).strip(" ,.;:")
    return text


def should_skip_name(name: str) -> bool:
    bad = {
        "references", "see also", "external links", "citation needed",
        "province", "city", "district"
    }
    lower = name.lower()
    if len(name) < 2 or len(name) > 120:
        return True
    if lower in bad:
        return True
    if lower.endswith("province") or lower.endswith("city"):
        return True
    return False


def parse_specialities_list_page(url: str, limit: int = 120) -> List[Dict[str, Any]]:
    soup = soup_from_url(url)
    content = soup.select_one("div.mw-parser-output")
    if not content:
        raise RuntimeError("Cannot find Wikipedia content block")

    rows: List[Dict[str, Any]] = []
    current_region = None

    for node in content.find_all(["h2", "h3", "ul"], recursive=False):
        if node.name in ("h2", "h3"):
            current_region = heading_text(node)
            if current_region and current_region.lower() in {"references", "see also", "external links", "notes"}:
                current_region = None
            continue

        if node.name == "ul" and current_region:
            items = node.find_all("li", recursive=False)
            for li in items:
                raw = strip_citations(li.get_text(" ", strip=True))
                if not raw:
                    continue

                name = normalize_product_name(raw)
                if should_skip_name(name):
                    continue

                detail_url = None
                # Prefer links that look like the product name
                for a in li.find_all("a", href=True):
                    href = a.get("href", "")
                    label = strip_citations(a.get_text(" ", strip=True)) or ""
                    if not href.startswith("/wiki/"):
                        continue
                    if label and (label.lower() in name.lower() or name.lower() in label.lower()):
                        detail_url = absolute_url(url, href)
                        break

                if not detail_url:
                    first_link = li.find("a", href=True)
                    if first_link and first_link.get("href", "").startswith("/wiki/"):
                        detail_url = absolute_url(url, first_link.get("href"))

                detail_desc = None
                detail_img = None
                if detail_url:
                    try:
                        dsoup = soup_from_url(detail_url)
                        detail_desc = first_paragraph(dsoup)
                        detail_img = first_image(dsoup, detail_url)
                    except Exception:
                        pass

                record = LocalProductRecord(
                    id=str(uuid.uuid4()),
                    name=name,
                    cover_image=detail_img,
                    gallery=[detail_img] if detail_img else None,
                    short_description=to_short_description(detail_desc or raw),
                    detailed_description=detail_desc or raw,
                    category="local specialty",
                    storage_transport=None,
                    price_range=None,
                    trusted_places=current_region,
                    average_rating=None,
                    review_count=0,
                )
                rows.append(asdict(record))
                if len(rows) >= limit:
                    return dedupe_rows(rows)

    return dedupe_rows(rows)


def crawl_local_products_fallback(urls: List[str]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for url in urls:
        try:
            soup = soup_from_url(url)
            title = heading_text(soup.select_one("h1"))
            if not title:
                continue
            desc = first_paragraph(soup)
            img = first_image(soup, url)

            record = LocalProductRecord(
                id=str(uuid.uuid4()),
                name=title,
                cover_image=img,
                gallery=[img] if img else None,
                short_description=to_short_description(desc),
                detailed_description=desc,
                category="local specialty",
                storage_transport=None,
                price_range=None,
                trusted_places=None,
                average_rating=None,
                review_count=0,
            )
            rows.append(asdict(record))
        except Exception as e:
            print(f"[WARN] local fallback failed for {url}: {e}")
    return dedupe_rows(rows)


def crawl_local_products(limit: int = 120) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    try:
        rows = parse_specialities_list_page(WIKI_SPECIALITIES_URL, limit=limit)
    except Exception as e:
        print(f"[WARN] list parser failed: {e}")

    # If the page structure changes or yields too few rows, fallback to curated pages
    if len(rows) < 10:
        fallback = crawl_local_products_fallback(LOCAL_PRODUCT_SEED_URLS)
        rows = dedupe_rows(rows + fallback)

    return rows[:limit]


# =========================
# Main
# =========================

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode",
        required=True,
        choices=["activity", "culture", "local_products", "all"],
    )
    parser.add_argument(
        "--output-dir",
        default="output",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=120,
        help="Max rows for local_products",
    )
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    if args.mode in ("activity", "all"):
        activities = crawl_activities(ACTIVITY_SEED_URLS)
        dump_json(activities, os.path.join(args.output_dir, "activity.json"))
        dump_csv(activities, os.path.join(args.output_dir, "activity.csv"))
        print(f"[OK] activity -> {len(activities)} rows")

    if args.mode in ("culture", "all"):
        culture = crawl_culture(CULTURE_SEED_URLS)
        dump_json(culture, os.path.join(args.output_dir, "culture.json"))
        dump_csv(culture, os.path.join(args.output_dir, "culture.csv"))
        print(f"[OK] culture -> {len(culture)} rows")

    if args.mode in ("local_products", "all"):
        local_products = crawl_local_products(limit=args.limit)
        dump_json(local_products, os.path.join(args.output_dir, "local_products.json"))
        dump_csv(local_products, os.path.join(args.output_dir, "local_products.csv"))
        print(f"[OK] local_products -> {len(local_products)} rows")
        if local_products:
            print("[DEBUG] first local product:", local_products[0]["name"])


if __name__ == "__main__":
    main()
