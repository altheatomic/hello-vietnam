"""
Shared config for filtering, Module 1, and Module 2.
"""

MIN_RATING = 3.5
MIN_REVIEW_COUNT = 10

MIN_PER_DAY = 3
RECOMMENDED_PER_DAY = 4
MAX_PER_DAY = 5

CANDIDATE_PER_DAY = 8

BUDGET_LIMITS = {
    "low": 200_000,
    "budget": 200_000,
    "medium": 500_000,
    "mid_range": 500_000,
    "high": 1_500_000,
    "comfort": 1_500_000,
    "premium": None,
}

PACE_DAY_RULES = {
    "easy": {
        "target_per_day": 3,
        "min_per_day": 2,
        "max_per_day": 4,
    },
    "balanced": {
        "target_per_day": 4,
        "min_per_day": 3,
        "max_per_day": 5,
    },
    "active": {
        "target_per_day": 5,
        "min_per_day": 4,
        "max_per_day": 6,
    },
    "packed": {
        "target_per_day": 5,
        "min_per_day": 4,
        "max_per_day": 6,
    },
}

DEFAULT_PACE_LEVEL = "balanced"

MAX_VISIT_DURATION_MINUTES = 420
DEFAULT_VISIT_DURATION_MINUTES = 90

# Sanity clamp for a single place's estimated_duration_minutes as read from
# the DB, applied in estimate_duration_minutes(). 480min (8h) is far above
# any real place duration (real data tops out at 240min) and far below the
# 24h wraparound schedule_builder._add() cannot handle — see that module's
# docstring.
MAX_SINGLE_PLACE_DURATION_MINUTES = 480

HIGH_RANK_TOP_PERCENT = 0.20

KMEANS_RANDOM_STATE = 42
KMEANS_N_INIT = 10

REPAIR_DISTANCE_RHO = 2.0
REPAIR_RELAXED_DISTANCE_RHO = 3.0
