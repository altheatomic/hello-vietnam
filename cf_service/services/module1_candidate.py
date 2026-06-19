"""
services/module1_candidate.py
Module 1 – Candidate place selection (CB + CF blending).

Dynamic alpha (CB weight):
  CF coverage = (# places with CF score) / total places in province
  coverage=0   → alpha=1.0  (cold start: pure CB)
  coverage<10% → alpha=0.7
  coverage<30% → alpha=0.5
  coverage≥30% → alpha=0.3  (enough CF data: let CF lead)
"""


# ── CB score ──────────────────────────────────────────────────────────────────

def compute_cb_score(place: dict,
                     user_profile: dict,
                     place_tags: dict,
                     user_tag_weights: dict) -> float:
    """
    Content-based score for a single place.  Returns float in [0.0, 1.0].

    Scoring breakdown (total = 1.0):
      0.35 – hobby / subcategory match
      0.35 – interest tag match (confidence × final_weight, normalized)
      0.15 – average_rating normalised  (rating − 1) / 4
      0.15 – budget match (proximity on normalised price scale)
    """
    score = 0.0

    # ── 0.35: Hobby / subcategory match ──────────────────────────────────────
    hobbies          = user_profile.get('hobbies', [])
    hobby_sub_ids    = {h['id_place_subcategory'] for h in hobbies}
    hobby_categories = {h['place_category'] for h in hobbies}

    place_sub_id   = str(place.get('id_place_subcategory', '') or '')
    place_category = str(place.get('category', '') or '')

    if place_sub_id and place_sub_id in hobby_sub_ids:
        score += 0.35          # exact subcategory match
    elif place_category and place_category in hobby_categories:
        score += 0.20          # looser category-level match

    # ── 0.35: Interest tag match ──────────────────────────────────────────────
    pid             = str(place['id_place'])
    tags_for_place  = place_tags.get(pid, [])
    total_weight    = sum(user_tag_weights.values()) if user_tag_weights else 0.0

    if tags_for_place and total_weight > 0:
        raw_tag = sum(
            tag['confidence'] * user_tag_weights.get(tag['id_tag'], 0.0)
            for tag in tags_for_place
        )
        # Normalise: raw_tag / total_weight gives share of maximum achievable score.
        score += 0.35 * min(raw_tag / total_weight, 1.0)

    # ── 0.15: Average rating ──────────────────────────────────────────────────
    avg_rating = float(place.get('average_rating') or 3.0)
    score += 0.15 * max(0.0, min(1.0, (avg_rating - 1.0) / 4.0))

    # ── 0.15: Budget compatibility ────────────────────────────────────────────
    BUDGET_TO_NORM = {'budget': 0.0, 'mid_range': 1/3, 'comfort': 2/3, 'premium': 1.0}
    budget_level   = user_profile.get('travel_profile', {}).get('budget_level', 'mid_range')
    user_price     = BUDGET_TO_NORM.get(budget_level, 1/3)
    place_price    = min(float(place.get('price_level') or 0) / 4.0, 1.0)

    score += 0.15 * (1.0 - abs(user_price - place_price))

    return round(min(max(score, 0.0), 1.0), 6)


# ── Dynamic alpha ─────────────────────────────────────────────────────────────

def _compute_alpha(cf_map: dict, total_places: int) -> float:
    if total_places == 0:
        return 1.0
    coverage = len(cf_map) / total_places
    if coverage == 0:   return 1.0
    if coverage < 0.10: return 0.7
    if coverage < 0.30: return 0.5
    return 0.3


# ── Public API ────────────────────────────────────────────────────────────────

def select_candidates(places: list,
                      user_profile: dict,
                      place_tags: dict,
                      cf_map: dict,
                      already_rated: set,
                      top_n: int = 40) -> list:
    user_tag_weights = {
        t['id_tag']: t['final_weight']
        for t in user_profile.get('interest_tags', [])
    }

    alpha  = _compute_alpha(cf_map, len(places))
    scored = []

    for place in places:
        pid = str(place['id_place'])
        if pid in already_rated:
            continue

        cb = compute_cb_score(place, user_profile, place_tags, user_tag_weights)
        cf = cf_map.get(pid, 0.0)

        place['cb_score']    = round(cb, 4)
        place['cf_score']    = round(cf, 4)
        place['alpha_used']  = alpha
        place['final_score'] = round(alpha * cb + (1 - alpha) * cf, 4)
        scored.append(place)

    scored.sort(key=lambda p: -p['final_score'])
    return scored[:top_n]
