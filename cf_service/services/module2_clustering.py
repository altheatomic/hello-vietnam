"""
services/module2_clustering.py
Module 2 – Cluster candidate places into days.

Flow:
  1. K-Means on (latitude, longitude) with k = n_days
  2. Balance clusters so each day has similar number of places
  3. Assign time slots (morning / afternoon / evening) per day
"""

import math
from sklearn.cluster import KMeans

SLOT_LABELS = ['morning', 'afternoon', 'evening']


# DEPRECATED — superseded by services/module2_algorithm.build_module2_result() (Greedy Repair)
def _kmeans_cluster(places: list, n_days: int) -> dict:
    coords = [[p['latitude'], p['longitude']] for p in places]
    km     = KMeans(n_clusters=n_days, n_init=10, random_state=42)
    labels = km.fit_predict(coords)

    clusters: dict = {d: [] for d in range(n_days)}
    for place, label in zip(places, labels):
        clusters[int(label)].append(place)
    return clusters


# DEPRECATED — superseded by services/module2_algorithm.build_module2_result() (Greedy Repair)
def _centroid(places: list) -> tuple:
    lats = [p['latitude']  for p in places]
    lons = [p['longitude'] for p in places]
    return (sum(lats) / len(lats), sum(lons) / len(lons))


# DEPRECATED — superseded by services/module2_algorithm.build_module2_result() (Greedy Repair)
def _euclidean(place: dict, centroid: tuple) -> float:
    return math.sqrt(
        (place['latitude']  - centroid[0]) ** 2 +
        (place['longitude'] - centroid[1]) ** 2
    )


# DEPRECATED — superseded by Greedy Repair in services/module2_algorithm.py
def _balance_clusters(clusters: dict, n_days: int) -> dict:
    for _ in range(n_days * 5):
        sizes = {d: len(v) for d, v in clusters.items()}
        big, small = max(sizes, key=sizes.get), min(sizes, key=sizes.get)
        if sizes[big] - sizes[small] <= 1:
            break
        centroid_big = _centroid(clusters[big])
        candidate    = max(clusters[big], key=lambda p: _euclidean(p, centroid_big))
        clusters[big].remove(candidate)
        clusters[small].append(candidate)
    return clusters


def _assign_slots(day_places: list) -> None:
    per_slot = max(1, len(day_places) // 3)
    for i, place in enumerate(day_places):
        if place.get('preferred_slot') is not None:
            place['slot'] = SLOT_LABELS[int(place['preferred_slot'])]
        else:
            place['slot'] = SLOT_LABELS[min(i // per_slot, 2)]


# DEPRECATED — superseded by services/module2_algorithm.build_module2_result()
def cluster_into_days(places: list, n_days: int) -> dict:
    if not places:
        return {d + 1: [] for d in range(n_days)}

    if len(places) <= n_days:
        result = {}
        for d in range(n_days):
            if d < len(places):
                places[d]['slot'] = SLOT_LABELS[0]
                result[d + 1] = [places[d]]
            else:
                result[d + 1] = []
        return result

    clusters = _kmeans_cluster(places, n_days)
    clusters = _balance_clusters(clusters, n_days)

    result = {}
    for day_index, day_places in clusters.items():
        _assign_slots(day_places)
        result[day_index + 1] = day_places
    return result
