"""
ml/matrix_a.py
Build interaction matrix A[user][place] from user events.

Formula:
  Implicit only  : A[u][p] = implicit_score
  Has explicit   : A[u][p] = 0.60 * explicit_score + 0.40 * implicit_score

Diminishing returns for implicit accumulation:
  score = score_prev + w * (1 - score_prev)
"""

import numpy as np

ACTION_WEIGHTS = {
    'view_thumbnail':  0.10,
    'view_detail':     0.26,
    'view_all_photos': 0.34,
    'add_favorite':    0.58,
    'add_plan':        0.82,
    'share':           0.82,
    'rating_1_5':      0.94,
    'review':          1.00,
}

EXPLICIT_ACTIONS = {'rating_1_5', 'review'}
IMPLICIT_ACTIONS = {k for k in ACTION_WEIGHTS if k not in EXPLICIT_ACTIONS}


def _compute_implicit_score(actions: list) -> float:
    score = 0.0
    implicit_only = [a for a in actions if a in IMPLICIT_ACTIONS]
    for action in sorted(implicit_only, key=lambda x: ACTION_WEIGHTS[x], reverse=True):
        w = ACTION_WEIGHTS[action]
        score = score + w * (1 - score)
    return score


def _index_events(event_list, u_idx, p_idx, action_type, target):
    for r in event_list:
        uid, pid = r.get('user_id'), r.get('place_id')
        if uid in u_idx and pid in p_idx:
            key = (u_idx[uid], p_idx[pid])
            target.setdefault(key, []).append(action_type)


def build_matrix_A(events: dict):
    ratings         = events.get('ratings', [])
    view_thumbnails = events.get('view_thumbnails', [])
    view_details    = events.get('view_details', [])
    view_all_photos = events.get('view_all_photos', [])
    favorites       = events.get('favorites', [])
    plans           = events.get('plans', [])
    shares          = events.get('shares', [])
    reviews         = events.get('reviews', [])

    all_user_ids  = sorted({r['user_id']  for src in events.values() for r in src})
    all_place_ids = sorted({r['place_id'] for src in events.values() for r in src})

    u_idx = {u: i for i, u in enumerate(all_user_ids)}
    p_idx = {p: i for i, p in enumerate(all_place_ids)}
    n_u, n_p = len(all_user_ids), len(all_place_ids)

    explicit_score = np.zeros((n_u, n_p), dtype=np.float32)
    has_explicit   = np.zeros((n_u, n_p), dtype=bool)

    for r in ratings:
        uid, pid = r.get('user_id'), r.get('place_id')
        if uid in u_idx and pid in p_idx:
            ui, pi = u_idx[uid], p_idx[pid]
            explicit_score[ui, pi] = (float(r['rating']) - 1) / 4.0
            has_explicit[ui, pi]   = True

    for r in reviews:
        uid, pid = r.get('user_id'), r.get('place_id')
        if uid in u_idx and pid in p_idx:
            ui, pi = u_idx[uid], p_idx[pid]
            w = ACTION_WEIGHTS['review']
            explicit_score[ui, pi] = explicit_score[ui, pi] + w * (1 - explicit_score[ui, pi])
            has_explicit[ui, pi]   = True

    action_map: dict = {}
    _index_events(view_thumbnails, u_idx, p_idx, 'view_thumbnail',  action_map)
    _index_events(view_details,    u_idx, p_idx, 'view_detail',     action_map)
    _index_events(view_all_photos, u_idx, p_idx, 'view_all_photos', action_map)
    _index_events(favorites,       u_idx, p_idx, 'add_favorite',    action_map)
    _index_events(plans,           u_idx, p_idx, 'add_plan',        action_map)
    _index_events(shares,          u_idx, p_idx, 'share',           action_map)

    implicit_mat = np.zeros((n_u, n_p), dtype=np.float32)
    for (ui, pi), actions in action_map.items():
        implicit_mat[ui, pi] = _compute_implicit_score(actions)

    A = np.where(
        has_explicit,
        0.60 * explicit_score + 0.40 * implicit_mat,
        implicit_mat,
    )

    return np.clip(A, 0, 1).astype(np.float32), all_user_ids, all_place_ids
