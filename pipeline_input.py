"""
Centralized runtime input for the end-to-end trip pipeline.
Edit this file to test different users/trips without touching runner code.
"""

from __future__ import annotations

from copy import deepcopy


PIPELINE_INPUT = {
    "user_profile": {
        "id_user": "e4bb33fb-5f1b-49a6-9a00-93c67183afde",
        "id_province": "094014a7-b8f6-481a-bbce-5ed6cdd457c5",
        "start_date": "2026-06-22",
        "end_date": "2026-06-24",
        "budget_level": "medium",
        "companion_style": "couple",
        "pace_level": "balanced",
        "travel_styles": ["Culture", "Food", "Local Life"],
        "topics": ["Temples", "Coffee", "Beaches", "Scenic Spots"],
        "behavior_count": 0,
    },
    "run_settings": {
        "place_fetch_limit": 500,
        "terminal_candidate_preview_limit": 10,
        "terminal_ranked_preview_limit": 20,
    },
}


def get_pipeline_input() -> dict:
    return deepcopy(PIPELINE_INPUT)
