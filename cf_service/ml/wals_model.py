"""
ml/wals_model.py
Train WALS (Weighted Alternating Least Squares) on matrix A.

References:
  Hu, Koren, Volinsky (2008) – Collaborative Filtering for Implicit Feedback
  Rendle et al. (RecSys 2022) – 16-20 iterations is sufficient

Formula:
  Confidence : C[u][p] = 1 + alpha * A[u][p]
  CF score   : sigmoid(U[u] · V[p])
"""

import numpy as np
from scipy.sparse import csr_matrix
from scipy.special import expit as sigmoid
from implicit.als import AlternatingLeastSquares

ALPHA      = 100
FACTORS    = 64
REG        = 0.1
ITERATIONS = 20


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
    for ui, user_id in enumerate(user_ids):
        raw_scores = sigmoid(V @ U[ui])

        interacted = np.where(A[ui] > 0)[0]
        raw_scores[interacted] = -1.0

        top_indices = np.argpartition(raw_scores, -top_k)[-top_k:]
        top_indices = top_indices[np.argsort(raw_scores[top_indices])[::-1]]

        for pi in top_indices:
            if raw_scores[pi] < 0:
                break
            results.append((user_id, place_ids[pi], float(raw_scores[pi])))

    return results
