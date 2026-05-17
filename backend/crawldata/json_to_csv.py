import json
import csv
import os
from typing import List, Dict, Any


def load_json(path: str) -> List[Dict[str, Any]]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def stringify_value(value: Any) -> Any:
    """
    CSV không lưu object/list native như JSON.
    Với list/dict thì convert sang JSON string.
    """
    if isinstance(value, (list, dict)):
        return json.dumps(value, ensure_ascii=False)
    return value


def json_to_csv(json_path: str, csv_path: str):
    data = load_json(json_path)

    if not data:
        print(f"[WARN] No data in {json_path}")
        return

    # lấy toàn bộ field xuất hiện trong file
    fieldnames = []
    seen = set()
    for row in data:
        for key in row.keys():
            if key not in seen:
                seen.add(key)
                fieldnames.append(key)

    os.makedirs(os.path.dirname(csv_path) or ".", exist_ok=True)

    with open(csv_path, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()

        for row in data:
            out_row = {k: stringify_value(row.get(k)) for k in fieldnames}
            writer.writerow(out_row)

    print(f"[OK] Converted: {json_path} -> {csv_path}")


if __name__ == "__main__":
    json_to_csv("output/culture.json", "output/culture.csv")
    json_to_csv("output/local_products.json", "output/local_products.csv")