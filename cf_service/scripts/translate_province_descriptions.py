"""
One-time translation helper for province.short_description -> description_en.

Originally targeted old_province.description (pre-merger, 63 rows); switched
to province.short_description (post-merger, 34 rows) alongside the Trip
Planner/Recommend old_province -> province migration — see
20260806090100_add_province_description_en.sql. province has no single
"description" column (only short_description / detailed_description);
short_description was chosen as the translation source because
recommend_service.py's province list is a compact card view, matching the
old old_province.description's short-form usage more closely than
detailed_description would.

cf_service has NO translation API key configured (checked .env.example:
only SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / DATABASE_URL — no
DEEPSEEK_API_KEY or equivalent, unlike backend/supabase/functions/ai-gateway
which is a separate Deno service with its own DeepSeek key). This script
does NOT call any translation API and does NOT add a new dependency.

Workflow:
  1. Export — dump every province row missing description_en into a
     JSON file for manual translation (paste into ChatGPT/Claude, or
     translate by hand):

       python scripts/translate_province_descriptions.py --export

     Writes province_descriptions_to_translate.json:
       [{"id_province": "...", "name": "...",
         "description_vi": "...", "description_en": ""}, ...]

  2. Fill in "description_en" for each entry in that file.

  3. Apply — update province.description_en from the filled file:

       python scripts/translate_province_descriptions.py --apply province_descriptions_to_translate.json

Run from cf_service/ root, AFTER 20260806090100_add_province_description_en.sql
has been applied (province.description_en must exist). One-time script, not
a recurring job.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from db.supabase_client import get_supabase_client

DEFAULT_EXPORT_PATH = "province_descriptions_to_translate.json"


if hasattr(sys.stdout, "reconfigure"):
    # Avoid Windows console encoding errors when printing Vietnamese text.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def fetch_provinces(supabase: Any) -> list[dict]:
    response = (
        supabase
        .table("province")
        .select("id_province,name,short_description,description_en")
        .execute()
    )
    return response.data or []


def export_for_translation(supabase: Any, output_path: str) -> None:
    provinces = fetch_provinces(supabase)
    pending = [
        {
            "id_province": p["id_province"],
            "name": p.get("name") or "",
            "description_vi": p.get("short_description") or "",
            "description_en": "",
        }
        for p in provinces
        if (p.get("short_description") or "").strip()
        and not (p.get("description_en") or "").strip()
    ]

    if not pending:
        print("Nothing to export — every province already has description_en "
              "(or has no Vietnamese description to translate).")
        return

    Path(output_path).write_text(
        json.dumps(pending, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Exported {len(pending)} province(s) needing translation to {output_path}")
    print("Fill in \"description_en\" for each entry, then run:")
    print(f"  python scripts/translate_province_descriptions.py --apply {output_path}")


def apply_translations(supabase: Any, input_path: str) -> None:
    entries = json.loads(Path(input_path).read_text(encoding="utf-8"))

    updated = 0
    skipped = 0
    for entry in entries:
        id_province = entry.get("id_province")
        description_en = (entry.get("description_en") or "").strip()
        if not id_province or not description_en:
            skipped += 1
            continue

        supabase.table("province").update(
            {"description_en": description_en}
        ).eq("id_province", id_province).execute()
        updated += 1
        print(f"Updated {entry.get('name', id_province)}")

    print("-" * 60)
    print(f"Updated: {updated}")
    print(f"Skipped (empty description_en): {skipped}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--export",
        action="store_true",
        help="Export provinces missing description_en to a JSON file.",
    )
    group.add_argument(
        "--apply",
        metavar="FILE",
        help="Apply translations from a filled-in JSON file.",
    )
    parser.add_argument(
        "--output",
        default=DEFAULT_EXPORT_PATH,
        help=f"Output path for --export (default: {DEFAULT_EXPORT_PATH})",
    )
    args = parser.parse_args()

    supabase = get_supabase_client()

    if args.export:
        export_for_translation(supabase, args.output)
    else:
        apply_translations(supabase, args.apply)


if __name__ == "__main__":
    main()
