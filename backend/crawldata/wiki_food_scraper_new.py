import csv
import json
import requests
from bs4 import BeautifulSoup

URL = "https://vi.wikipedia.org/wiki/Danh_s%C3%A1ch_m%C3%B3n_%C4%83n_Vi%E1%BB%87t_Nam"
OUTPUT_FILE = "foods.csv"
CITY_MAPPING_FILE = "city_province_rows.csv"
FOOD_TYPE_MAPPING_FILE = "food_type_rows.csv"


def clean_text(text):
    if not text:
        return ""
    return " ".join(text.replace("\xa0", " ").split()).strip()


def normalize_location_name(location: str) -> str:
    if not location:
        return ""
    loc = clean_text(location).lower()

    mapping = {
        "tp. hồ chí minh": "hồ chí minh",
        "tp hồ chí minh": "hồ chí minh",
        "tphcm": "hồ chí minh",
        "tp.hcm": "hồ chí minh",
        "sài gòn": "hồ chí minh",
        "miền nam": "miền nam",
        "miền trung": "miền trung",
        "miền bắc": "miền bắc",
        "khắp cả nước": "việt nam",
    }

    return mapping.get(loc, clean_text(location))


def get_image_url(cell):
    if not cell:
        return ""
    img = cell.find("img")
    if not img:
        return ""
    src = img.get("src") or img.get("data-src") or ""
    if not src:
        return ""
    if src.startswith("//"):
        return "https:" + src
    if src.startswith("/"):
        return "https://vi.wikipedia.org" + src
    return src


def load_mapping_csv(file_path, key_col, value_col):
    result = {}
    try:
        with open(file_path, "r", encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                key = clean_text(row.get(key_col, "")).lower()
                value = clean_text(row.get(value_col, ""))
                if key:
                    result[key] = value
    except FileNotFoundError:
        print(f"Không tìm thấy file mapping: {file_path}")
    return result


def get_nearest_section_name(table):
    # tìm heading gần nhất phía trước bảng
    prev = table.find_previous(["h2", "h3"])
    if not prev:
        return ""

    # ưu tiên span.mw-headline nếu có
    headline = prev.find(class_="mw-headline")
    if headline:
        return clean_text(headline.get_text(" ", strip=True))

    return clean_text(prev.get_text(" ", strip=True))


def main():
    city_map = load_mapping_csv(CITY_MAPPING_FILE, "name", "id_city")
    food_type_map = load_mapping_csv(FOOD_TYPE_MAPPING_FILE, "food_type_name", "id")

    headers = {"User-Agent": "Mozilla/5.0"}
    res = requests.get(URL, headers=headers, timeout=30)
    res.raise_for_status()

    soup = BeautifulSoup(res.text, "html.parser")

    tables = soup.select("table.wikitable")
    print(f"Tìm thấy {len(tables)} bảng wikitable")

    rows = []

    fieldnames = [
        "name",
        "food_type_id",
        "id_city",
        "image_path",
        "description",
        "cover_image",
        "gallery",
        "short_description",
        "detailed_description",
        "ingredients",
        "taste_profile",
        "dietary_warnings",
        "average_rating",
        "review_count",
        "source_location",
        "source_classification",
        "source_section",
    ]

    for table in tables:
        section_name = get_nearest_section_name(table)

        if any(x in section_name.lower() for x in ["chú thích", "xem thêm", "liên kết ngoài"]):
            continue

        trs = table.find_all("tr")
        if not trs:
            continue

        header_cells = trs[0].find_all(["th", "td"])
        headers_text = [clean_text(th.get_text(" ", strip=True)) for th in header_cells]

        # debug
        print("SECTION:", section_name)
        print("HEADERS:", headers_text)

        if "Tên món" not in headers_text:
            continue

        def idx(col):
            return headers_text.index(col) if col in headers_text else -1

        name_idx = idx("Tên món")
        img_idx = idx("Hình ảnh")
        location_idx = idx("Địa phương")
        classify_idx = idx("Phân loại")
        desc_idx = idx("Miêu tả")

        for tr in trs[1:]:
            tds = tr.find_all("td")
            if not tds:
                continue

            # nhiều dòng trên wiki bị thiếu cột vì merge/format lạ
            def get_td_text(i):
                return clean_text(tds[i].get_text(" ", strip=True)) if i != -1 and i < len(tds) else ""

            def get_td_img(i):
                return get_image_url(tds[i]) if i != -1 and i < len(tds) else ""

            name = get_td_text(name_idx)
            image_path = get_td_img(img_idx)
            location = get_td_text(location_idx)
            classification = get_td_text(classify_idx)
            desc = get_td_text(desc_idx)

            if not name:
                continue

            normalized_location = normalize_location_name(location)
            id_city = city_map.get(normalized_location.lower(), "")

            food_type_id = food_type_map.get(section_name.lower(), "")

            gallery = json.dumps([image_path], ensure_ascii=False) if image_path else json.dumps([], ensure_ascii=False)

            short_description = desc[:120] if desc else ""
            detailed_description = desc

            rows.append({
                "name": name,
                "food_type_id": food_type_id,
                "id_city": id_city,
                "image_path": image_path,
                "description": desc,
                "cover_image": image_path,
                "gallery": gallery,
                "short_description": short_description,
                "detailed_description": detailed_description,
                "ingredients": "",
                "taste_profile": "",
                "dietary_warnings": "",
                "average_rating": "",
                "review_count": 0,
                "source_location": location,
                "source_classification": classification,
                "source_section": section_name,
            })

    # bỏ trùng theo tên món
    unique_rows = []
    seen = set()
    for row in rows:
        key = row["name"].strip().lower()
        if key not in seen:
            seen.add(key)
            unique_rows.append(row)

    print(f"Số dòng parse được: {len(rows)}")
    print(f"Số dòng sau khi bỏ trùng: {len(unique_rows)}")

    if not unique_rows:
        print("Không crawl được dữ liệu nào.")
        return

    with open(OUTPUT_FILE, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(unique_rows)

    print(f"Đã xuất {len(unique_rows)} dòng vào {OUTPUT_FILE}")


if __name__ == "__main__":
    main()