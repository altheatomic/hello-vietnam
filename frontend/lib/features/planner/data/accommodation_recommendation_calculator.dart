import 'dart:math' as math;

import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';

const int accommodationLongTripMinDays = 5;
const int accommodationMinDaysPerZone = 2;
const double accommodationMinZoneSeparationKm = 50.0;
const double accommodationMaxZoneRadiusKm = 12.0;
const double accommodationMinTravelCostReductionRatio = 0.35;

AccommodationRecommendation? calculateAccommodationRecommendation(
  List<TripPlanDay> days, {
  int longTripMinDays = accommodationLongTripMinDays,
  int minDaysPerZone = accommodationMinDaysPerZone,
  double minZoneSeparationKm = accommodationMinZoneSeparationKm,
  double maxZoneRadiusKm = accommodationMaxZoneRadiusKm,
  double minTravelCostReductionRatio =
      accommodationMinTravelCostReductionRatio,
}) {
  if (days.isEmpty) return null;

  final List<_DayGeometry> geometries = days
      .map(_DayGeometry.fromDay)
      .whereType<_DayGeometry>()
      .toList()
    ..sort((a, b) => a.day.day.compareTo(b.day.day));
  if (geometries.length != days.length) return null;

  final _ZoneGeometry singleZone = _buildZone(geometries, 1);
  final double singleCost = _cost(
    geometries
        .map((geometry) => _distance(singleZone.center, geometry.centroid))
        .toList(),
  );

  AccommodationRecommendation _singleRecommendation() {
    return AccommodationRecommendation(
      version: 1,
      strategy: 'single_zone',
      zones: <AccommodationZone>[singleZone.toModel()],
      evaluation: AccommodationEvaluation(
        singleZoneCostKm: singleCost,
        selectedCostKm: singleCost,
        reductionRatio: 0.0,
        minZoneSeparationKm: minZoneSeparationKm,
        minCostReductionRatio: minTravelCostReductionRatio,
      ),
    );
  }

  if (geometries.length < longTripMinDays) return _singleRecommendation();

  _MultiCandidate? best;
  for (int zoneCount = 2;
      zoneCount <= _maxAccommodationZones(geometries.length);
      zoneCount++) {
    for (final List<List<_DayGeometry>> segments in _partitions(
      geometries,
      zoneCount,
      minDaysPerZone,
    )) {
      final List<_ZoneGeometry> zones = segments
          .asMap()
          .entries
          .map(
            (entry) => _buildZone(entry.value, entry.key + 1),
          )
          .toList();
      bool hasTooSmallSeparation = false;
      for (int index = 0; index < zones.length - 1; index++) {
        if (_distance(zones[index].center, zones[index + 1].center) <
            minZoneSeparationKm) {
          hasTooSmallSeparation = true;
          break;
        }
      }
      if (hasTooSmallSeparation ||
          zones.any((zone) => zone.radiusKm > maxZoneRadiusKm)) {
        continue;
      }

      final double selectedCost = _cost(<double>[
        for (final _ZoneGeometry zone in zones)
          for (final _DayGeometry day in zone.days)
            _distance(zone.center, day.centroid),
      ]);
      final double reductionRatio = singleCost == 0
          ? 0.0
          : (singleCost - selectedCost) / singleCost;
      if (reductionRatio < minTravelCostReductionRatio) continue;

      final _MultiCandidate candidate = _MultiCandidate(
        zones: zones,
        selectedCost: selectedCost,
        reductionRatio: reductionRatio,
      );
      if (best == null || candidate.selectedCost < best.selectedCost) {
        best = candidate;
      }
    }
  }

  if (best == null) return _singleRecommendation();
  return AccommodationRecommendation(
    version: 1,
    strategy: 'multi_zone',
    zones: best.zones.map((zone) => zone.toModel()).toList(),
    evaluation: AccommodationEvaluation(
      singleZoneCostKm: singleCost,
      selectedCostKm: best.selectedCost,
      reductionRatio: best.reductionRatio,
      minZoneSeparationKm: minZoneSeparationKm,
      minCostReductionRatio: minTravelCostReductionRatio,
    ),
  );
}

class _Point {
  const _Point(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class _DayGeometry {
  const _DayGeometry({
    required this.day,
    required this.points,
    required this.centroid,
  });

  final TripPlanDay day;
  final List<_Point> points;
  final _Point centroid;

  static _DayGeometry? fromDay(TripPlanDay day) {
    final List<_Point> points = day.places
        .where((place) => place.type != 'lunch_break')
        .map((place) {
          final double? latitude = place.latitude;
          final double? longitude = place.longitude;
          if (latitude == null || longitude == null) return null;
          if (!latitude.isFinite || !longitude.isFinite) return null;
          if (latitude < -90 ||
              latitude > 90 ||
              longitude < -180 ||
              longitude > 180) {
            return null;
          }
          if (latitude == 0 && longitude == 0) return null;
          return _Point(latitude, longitude);
        })
        .whereType<_Point>()
        .toList();
    if (points.isEmpty) return null;
    return _DayGeometry(
      day: day,
      points: points,
      centroid: _averagePoint(points),
    );
  }
}

class _ZoneGeometry {
  const _ZoneGeometry({
    required this.days,
    required this.center,
    required this.radiusKm,
    required this.zoneIndex,
  });

  final List<_DayGeometry> days;
  final _Point center;
  final double radiusKm;
  final int zoneIndex;

  AccommodationZone toModel() {
    return AccommodationZone(
      zoneIndex: zoneIndex,
      dayFrom: days.first.day.day,
      dayTo: days.last.day.day,
      latitude: center.latitude,
      longitude: center.longitude,
      googleMapsQuery:
          'hotels near ${center.latitude.toStringAsFixed(6)},${center.longitude.toStringAsFixed(6)}',
    );
  }
}

class _MultiCandidate {
  const _MultiCandidate({
    required this.zones,
    required this.selectedCost,
    required this.reductionRatio,
  });

  final List<_ZoneGeometry> zones;
  final double selectedCost;
  final double reductionRatio;
}

int _maxAccommodationZones(int totalDays) {
  if (totalDays <= 8) return 2;
  if (totalDays <= 14) return 3;
  return 4;
}

List<List<List<_DayGeometry>>> _partitions(
  List<_DayGeometry> days,
  int zoneCount,
  int minDaysPerZone,
) {
  final List<List<List<_DayGeometry>>> result =
      <List<List<_DayGeometry>>>[];

  void visit(int start, List<List<_DayGeometry>> segments) {
    final int remainingDays = days.length - start;
    final int remainingZones = zoneCount - segments.length;
    if (remainingZones == 1) {
      if (remainingDays >= minDaysPerZone) {
        result.add(<List<_DayGeometry>>[
          ...segments,
          days.sublist(start),
        ]);
      }
      return;
    }

    final int maxEnd = days.length - minDaysPerZone * (remainingZones - 1);
    for (int end = start + minDaysPerZone; end <= maxEnd; end++) {
      visit(end, <List<_DayGeometry>>[
        ...segments,
        days.sublist(start, end),
      ]);
    }
  }

  visit(0, <List<_DayGeometry>>[]);
  return result;
}

_ZoneGeometry _buildZone(List<_DayGeometry> days, int zoneIndex) {
  final List<_Point> points = days.expand((day) => day.points).toList();
  _Point center = points.first;
  double bestWorstDistance = double.infinity;
  double bestTotalDistance = double.infinity;
  for (final _Point candidate in points) {
    final List<double> distances = points
        .map((point) => _distance(candidate, point))
        .toList();
    final double worstDistance = distances.reduce(math.max);
    final double totalDistance = distances.reduce((a, b) => a + b);
    if (worstDistance < bestWorstDistance ||
        (worstDistance == bestWorstDistance &&
            totalDistance < bestTotalDistance)) {
      center = candidate;
      bestWorstDistance = worstDistance;
      bestTotalDistance = totalDistance;
    }
  }
  return _ZoneGeometry(
    days: days,
    center: center,
    radiusKm: bestWorstDistance,
    zoneIndex: zoneIndex,
  );
}

_Point _averagePoint(List<_Point> points) {
  return _Point(
    points.map((point) => point.latitude).reduce((a, b) => a + b) / points.length,
    points.map((point) => point.longitude).reduce((a, b) => a + b) / points.length,
  );
}

double _cost(List<double> distances) {
  if (distances.isEmpty) return 0.0;
  final double mean = distances.reduce((a, b) => a + b) / distances.length;
  return 0.6 * mean + 0.4 * distances.reduce(math.max);
}

double _distance(_Point first, _Point second) {
  const double earthRadiusKm = 6371.0;
  final double firstLatitude = first.latitude * math.pi / 180;
  final double secondLatitude = second.latitude * math.pi / 180;
  final double deltaLatitude = (second.latitude - first.latitude) * math.pi / 180;
  final double deltaLongitude = (second.longitude - first.longitude) * math.pi / 180;
  final double a = math.pow(math.sin(deltaLatitude / 2), 2).toDouble() +
      math.cos(firstLatitude) *
          math.cos(secondLatitude) *
          math.pow(math.sin(deltaLongitude / 2), 2).toDouble();
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
