"""
ml/wals_model.py
Train WALS (Weighted Alternating Least Squares) on matrix A.

References:
  Hu, Koren, Volinsky (2008) – Collaborative Filtering for Implicit Feedback
  Rendle et al. (RecSys 2022) – 16 iterations is sufficient

Formula:
  Confidence : C[u][p] = 1 + alpha * A[u][p]
  CF score   : sigmoid(U[u] · V[p])
"""

import numpy as np
from scipy.sparse import csr_matrix
from scipy.special import expit as sigmoid
from implicit.als import AlternatingLeastSquares

ALPHA      = 40
FACTORS    = 64
REG        = 0.1
ITERATIONS = 16


def train_wals(A: np.ndarray):
    sparse_A  = csr_matrix(A)
    conf      = sparse_A.copy()
    conf.data = 1.0 + ALPHA * conf.data

    model = AlternatingLeastSquares(
        factors=FACTORS,
        regularization=REG,
        iterations=ITERATIONS,
        use_gpu=False,
        calculate_training_loss=True,
    )
    model.fit(conf, show_progress=True)

    return np.array(model.user_factors), np.array(model.item_factors)


def compute_cf_scores(U, V, user_ids, place_ids, A, top_k=500) -> list:
    results = []
    effective_k = min(top_k, len(place_ids))

    for ui, user_id in enumerate(user_ids):
        raw_scores = sigmoid(V @ U[ui])
        interacted = np.where(A[ui] > 0)[0]

        scores_excl = raw_scores.copy()
        scores_excl[interacted] = -1.0

        top_idx = np.argpartition(scores_excl, -effective_k)[-effective_k:]
        top_idx = top_idx[np.argsort(scores_excl[top_idx])[::-1]]

        user_results = [
            (user_id, place_ids[pi], float(scores_excl[pi]))
            for pi in top_idx if scores_excl[pi] >= 0
        ]

        if not user_results:
            # Fallback: all places interacted — re-suggest by raw score
            fallback_idx = np.argpartition(raw_scores, -effective_k)[-effective_k:]
            fallback_idx = fallback_idx[np.argsort(raw_scores[fallback_idx])[::-1]]
            user_results = [
                (user_id, place_ids[pi], float(raw_scores[pi]))
                for pi in fallback_idx
            ]

        results.extend(user_results)

    return results
