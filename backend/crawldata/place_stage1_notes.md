# Stage 1 place seed notes

## What this script does
- Pulls data from OpenStreetMap Overpass API for 10 target locations:
  - Hà Nội
  - TP.HCM
  - Đà Nẵng
  - Huế
  - Hội An
  - Đà Lạt
  - Nha Trang
  - Phú Quốc
  - Cần Thơ
  - Hạ Long
- For each location, tries to keep:
  - 50 restaurants
  - 30 cafes
  - 30 attractions
  - 20 shops/markets
- Normalizes rows to fit your `public.place` schema.
- Upserts into Supabase using deterministic `id_place` values.

## Important assumptions
- Your project uses a custom 34-province model.
- This script maps:
  - Hội An -> Đà Nẵng
  - Phú Quốc -> An Giang
- If your mapping is different, edit the `PROVINCES` dict in the script.

## Before running
1. Make sure table `place` already exists.
2. Make sure `place_subcategory` already has the 4 subcategories you want.
3. Copy `.env.place_seed.example` to `.env` and replace placeholders.
4. Install packages:
   ```bash
   pip install supabase requests python-dotenv
   ```

## Run examples
```bash
python stage1_seed_places.py --city all
python stage1_seed_places.py --city hanoi --dry-run --export-json hanoi_seed.json
```

## Recommended SQL before first run
If you want faster dedupe checks later, add this unique index too:
```sql
create unique index if not exists ux_place_source_source_place_id
on public.place (source, source_place_id);
```

## Limitations
- OSM coverage is uneven by city and category.
- Ratings and images are often missing in OSM.
- Opening hours may be partial or absent.
- For a prettier production-like seed later, enrich a subset with Google Places or manual curation.
