"""
ml/matrix_a.py
Build interaction matrix A[user][place] from user events.

Formula:
  Implicit only  : A[u][p] = implicit_score
  Has explicit   : A[u][p] = 0.60 * explicit_score + 0.40 * implicit_score

implicit_score is a weighted average over the (up to 3) implicit actions
observed for a (user, place) pair, weighted by presence (has/has-not),
not by event_count:
  score = Σ(weight_i for action_i present) / Σ(weight_i for action_i present)...
  i.e. score = Σ w_i / count(actions present)  — see _compute_implicit_score.

explicit_score is a weighted average (rating only, review removed).
"""

import numpy as np

ACTION_WEIGHTS = {
    'view_detail':   0.2,
    'add_favorite':  0.3,
    'share':         0.5,
}

EXPLICIT_ACTIONS = {'rating_1_5'}
IMPLICIT_ACTIONS = {'view_detail', 'add_favorite', 'share'}


def _compute_implicit_score(actions_present: set) -> float:
    if not actions_present:
        return 0.0
    total_weighted = sum(ACTION_WEIGHTS[a] for a in actions_present)
    return total_weighted


def _index_events(event_list, u_idx, p_idx, action_type, target):
    for r in event_list:
        uid, pid = r.get('user_id'), r.get('place_id')
        if uid in u_idx and pid in p_idx:
            key = (u_idx[uid], p_idx[pid])
            actions = target.setdefault(key, set())
            actions.add(action_type)


def build_matrix_A(events: dict):
    ratings   = events.get('ratings', [])
    views     = events.get('views', [])
    favorites = events.get('favorites', [])
    shares    = events.get('shares', [])

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
            key = (u_idx[uid], p_idx[pid])
            score = (float(r['rating']) - 1) / 4.0
            explicit_score[key] = score
            has_explicit[key]   = True

    action_map: dict = {}
    _index_events(views,     u_idx, p_idx, 'view_detail',  action_map)
    _index_events(favorites, u_idx, p_idx, 'add_favorite', action_map)
    _index_events(shares,    u_idx, p_idx, 'share',        action_map)

    implicit_mat = np.zeros((n_u, n_p), dtype=np.float32)
    for (ui, pi), actions_present in action_map.items():
        implicit_mat[ui, pi] = _compute_implicit_score(actions_present)

    A = np.where(
        has_explicit,
        0.60 * explicit_score + 0.40 * implicit_mat,
        implicit_mat,
    )

    return np.clip(A, 0, 1).astype(np.float32), all_user_ids, all_place_ids
