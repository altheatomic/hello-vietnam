# TripPlanner_filter_only

This folder tests only the filtering step of Module 1.

It does not calculate TagMatch or FinalRank.

## Flow

1. Query `place` by required filters:
   - `id_province = user.id_province`
   - `status = active`
   - `latitude is not null`
   - `longitude is not null`

2. Apply optional filters in Python:
   - `average_rating >= 3.5`
   - `review_count >= 10`
   - `maximum_price <= budget limit`

3. Check minimum expected candidates:
   - `MinCandidates = D * 8`

4. If optional filters return too few places:
   - fallback to required-filter result.

## Setup

Open PowerShell in this folder:

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

Copy `.env.example` to `.env` and fill:

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

## Run

Open `run_filtering.py` and replace:

```python
"id_province": "PUT_PROVINCE_UUID_HERE"
```

with a real province UUID.

Then run:

```powershell
python run_filtering.py
```
