import 'package:flutter/foundation.dart';

/// Response from `POST /api/trips/plan`.
///
/// Shape returned by cf_service:
/// {
///   "id_plan": "uuid" | null,
///   "days": [
///     {
///       "day": 1,
///       "date": "2026-07-01",
///       "places": [
///         {
///           "order": 1,
///           "id_place": "uuid",
///           "name": "...",
///           "slot": "morning",
///           "latitude": 16.0,
///           "longitude": 108.0,
///           "estimated_travel_minutes": 12,
///           "tag_match": 0.25,
///           "cf_score": 0.0,
///           "final_score": 0.25
///         }
///       ]
///     }
///   ]
/// }
class TripPlanResponse {
  const TripPlanResponse({
    required this.idPlan,
    this.customTitle,
    this.cityProvince,
    this.startAt,
    this.endAt,
    this.accommodationRecommendation,
    required this.days,
    this.includeLunchBreak = true,
  });

  final String? idPlan;
  final String? customTitle;
  final String? cityProvince;
  final DateTime? startAt;
  final DateTime? endAt;
  final AccommodationRecommendation? accommodationRecommendation;
  final List<TripPlanDay> days;

  /// Plan-level (not per-day) choice from Step 5 of the wizard: whether this
  /// trip's schedule reserves a lunch break. Defaults to true so plans saved
  /// before this field existed (NULL in the DB) keep showing the lunch
  /// discovery card exactly as before.
  final bool includeLunchBreak;

  TripPlanResponse copyWith({
    AccommodationRecommendation? accommodationRecommendation,
  }) {
    return TripPlanResponse(
      idPlan: idPlan,
      customTitle: customTitle,
      cityProvince: cityProvince,
      startAt: startAt,
      endAt: endAt,
      accommodationRecommendation:
          accommodationRecommendation ?? this.accommodationRecommendation,
      days: days,
      includeLunchBreak: includeLunchBreak,
    );
  }

  factory TripPlanResponse.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? <dynamic>[];
    final days = rawDays
        .whereType<Map<String, dynamic>>()
        .map(TripPlanDay.fromJson)
        .toList();

    // `getPlan` (loading a saved trip) returns start_at/end_at at the top
    // level. `planTrip` (freshly generated, not yet reloaded) does not —
    // fall back to the first/last day's calendar date, which is always
    // present either way.
    final DateTime? startAt =
        DateTime.tryParse(json['start_at'] as String? ?? '') ??
        (days.isNotEmpty ? DateTime.tryParse(days.first.date) : null);
    final DateTime? endAt =
        DateTime.tryParse(json['end_at'] as String? ?? '') ??
        (days.isNotEmpty ? DateTime.tryParse(days.last.date) : null);

    return TripPlanResponse(
      idPlan: json['id_plan'] as String?,
      customTitle: json['custom_title'] as String?,
      cityProvince: json['city_province'] as String?,
      startAt: startAt,
      endAt: endAt,
      accommodationRecommendation: json['accommodation_recommendation'] is Map
          ? AccommodationRecommendation.fromJson(
              Map<String, dynamic>.from(
                json['accommodation_recommendation'] as Map,
              ),
            )
          : null,
      days: days,
      includeLunchBreak: json['include_lunch_break'] as bool? ?? true,
    );
  }
}

class AccommodationRecommendation {
  const AccommodationRecommendation({
    required this.version,
    required this.strategy,
    required this.zones,
    required this.evaluation,
  });

  final int version;
  final String strategy;
  final List<AccommodationZone> zones;
  final AccommodationEvaluation evaluation;

  factory AccommodationRecommendation.fromJson(Map<String, dynamic> json) {
    final rawZones = json['zones'];
    final zones = rawZones is List
        ? rawZones
              .whereType<Map>()
              .map(
                (zone) =>
                    AccommodationZone.fromJson(Map<String, dynamic>.from(zone)),
              )
              .toList()
        : <AccommodationZone>[];
    final rawEvaluation = json['evaluation'];
    return AccommodationRecommendation(
      version: (json['version'] as num?)?.toInt() ?? 1,
      strategy: json['strategy'] as String? ?? 'single_zone',
      zones: zones,
      evaluation: rawEvaluation is Map
          ? AccommodationEvaluation.fromJson(
              Map<String, dynamic>.from(rawEvaluation),
            )
          : const AccommodationEvaluation(),
    );
  }
}

class AccommodationZone {
  const AccommodationZone({
    required this.zoneIndex,
    required this.dayFrom,
    required this.dayTo,
    required this.latitude,
    required this.longitude,
    required this.googleMapsQuery,
  });

  final int zoneIndex;
  final int dayFrom;
  final int dayTo;
  final double latitude;
  final double longitude;
  final String googleMapsQuery;

  factory AccommodationZone.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    return AccommodationZone(
      zoneIndex: (json['zone_index'] as num?)?.toInt() ?? 0,
      dayFrom: (json['day_from'] as num?)?.toInt() ?? 0,
      dayTo: (json['day_to'] as num?)?.toInt() ?? 0,
      latitude: latitude ?? 0.0,
      longitude: longitude ?? 0.0,
      googleMapsQuery:
          json['google_maps_query'] as String? ??
          'hotels near ${latitude ?? 0.0},${longitude ?? 0.0}',
    );
  }
}

class AccommodationEvaluation {
  const AccommodationEvaluation({
    this.singleZoneCostKm = 0.0,
    this.selectedCostKm = 0.0,
    this.reductionRatio = 0.0,
    this.minZoneSeparationKm = 50.0,
    this.minCostReductionRatio = 0.35,
  });

  final double singleZoneCostKm;
  final double selectedCostKm;
  final double reductionRatio;
  final double minZoneSeparationKm;
  final double minCostReductionRatio;

  factory AccommodationEvaluation.fromJson(Map<String, dynamic> json) {
    return AccommodationEvaluation(
      singleZoneCostKm:
          (json['single_zone_cost_km'] as num?)?.toDouble() ?? 0.0,
      selectedCostKm: (json['selected_cost_km'] as num?)?.toDouble() ?? 0.0,
      reductionRatio: (json['reduction_ratio'] as num?)?.toDouble() ?? 0.0,
      minZoneSeparationKm:
          (json['min_zone_separation_km'] as num?)?.toDouble() ?? 50.0,
      minCostReductionRatio:
          (json['min_cost_reduction_ratio'] as num?)?.toDouble() ?? 0.35,
    );
  }
}

class TripPlanDay {
  const TripPlanDay({
    required this.day,
    required this.date,
    required this.places,
  });

  final int day;
  final String date;
  final List<TripPlanPlace> places;

  factory TripPlanDay.fromJson(Map<String, dynamic> json) {
    final rawPlaces = json['places'] as List<dynamic>? ?? <dynamic>[];
    return TripPlanDay(
      day: (json['day'] as num).toInt(),
      date: json['date'] as String? ?? '',
      places: rawPlaces
          .whereType<Map<String, dynamic>>()
          .map(TripPlanPlace.fromJson)
          .toList(),
    );
  }
}

class TripPlanPlace {
  const TripPlanPlace({
    this.type = 'place',
    this.order = 0,
    this.idPlace = '',
    this.name = '',
    this.slot,
    this.startTime,
    this.endTime,
    this.warning,
    this.latitude,
    this.longitude,
    this.estimatedTravelMinutes,
    this.estimatedDurationMinutes,
    this.travelTimeCarSeconds,
    this.travelTimeBikeSeconds,
    this.travelDistanceCarMeters,
    this.travelDistanceBikeMeters,
    this.minimumPrice,
    this.maximumPrice,
    this.timespan,
    this.timeclose,
    this.coverImage,
    this.gallery = const <Map<String, dynamic>>[],
    this.tagMatch,
    this.cfScore,
    this.finalScore,
    this.tags = const <String>[],
  });

  /// 'place' or 'lunch_break'
  final String type;
  final int order;
  final String idPlace;
  final String name;
  final String? slot;
  final String? startTime;
  final String? endTime;
  final String? warning;
  final double? latitude;
  final double? longitude;
  final int? estimatedTravelMinutes;
  final int? estimatedDurationMinutes;

  /// Goong Distance Matrix data for the edge FROM the previous stop TO this
  /// place. Null for the first place of each day (no predecessor) and for
  /// any edge Goong couldn't cover (see cf_service _attach_travel_data()).
  final int? travelTimeCarSeconds;
  final int? travelTimeBikeSeconds;
  final int? travelDistanceCarMeters;
  final int? travelDistanceBikeMeters;
  final num? minimumPrice;
  final num? maximumPrice;
  final String? timespan;
  final String? timeclose;
  final String? coverImage;

  /// List of {url, type, source} objects from the DB gallery jsonb column.
  final List<Map<String, dynamic>> gallery;
  final double? tagMatch;
  final double? cfScore;
  final double? finalScore;

  /// Real tag_name list for this place (place_tag rows above the backend's
  /// confidence threshold, highest confidence first, capped) — NOT the same
  /// as tagMatch (a score) or a per-user match; this is the place's own
  /// full tag set. Always a list, never null (empty if no tag qualified).
  final List<String> tags;

  bool get isLunchBreak => type == 'lunch_break';

  /// Returns the best representative image URL for this place:
  /// gallery item with type='cover' → first gallery item → coverImage → null.
  String? get representativeImageUrl {
    for (final item in gallery) {
      if (item['type'] == 'cover') return item['url'] as String?;
    }
    if (gallery.isNotEmpty) return gallery.first['url'] as String?;
    return coverImage;
  }

  factory TripPlanPlace.fromJson(Map<String, dynamic> json) {
    final rawGallery = json['gallery'];
    final gallery = rawGallery is List
        ? rawGallery.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags.whereType<String>().toList()
        : <String>[];

    final TripPlanPlace place = TripPlanPlace(
      type: json['type'] as String? ?? 'place',
      order: (json['order'] as num?)?.toInt() ?? 0,
      idPlace: json['id_place'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slot: json['slot'] as String?,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      warning: json['warning'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      estimatedTravelMinutes: (json['estimated_travel_minutes'] as num?)
          ?.toInt(),
      estimatedDurationMinutes: (json['estimated_duration_minutes'] as num?)
          ?.toInt(),
      travelTimeCarSeconds: (json['travel_time_car_seconds'] as num?)?.toInt(),
      travelTimeBikeSeconds: (json['travel_time_bike_seconds'] as num?)
          ?.toInt(),
      travelDistanceCarMeters: (json['travel_distance_car_meters'] as num?)
          ?.toInt(),
      travelDistanceBikeMeters: (json['travel_distance_bike_meters'] as num?)
          ?.toInt(),
      minimumPrice: json['minimum_price'] as num?,
      maximumPrice: json['maximum_price'] as num?,
      timespan: json['timespan'] as String?,
      timeclose: json['timeclose'] as String?,
      coverImage: json['cover_image'] as String?,
      gallery: gallery,
      tagMatch: (json['tag_match'] as num?)?.toDouble(),
      cfScore: (json['cf_score'] as num?)?.toDouble(),
      finalScore: (json['final_score'] as num?)?.toDouble(),
      tags: tags,
    );
    debugPrint(
      '[TripPlanPlace.fromJson] coverImage=${place.coverImage} '
      'gallery.length=${place.gallery.length} '
      'representativeImageUrl=${place.representativeImageUrl}',
    );
    return place;
  }
}

/// One stop (place) inside a saved plan card, from `GET /api/trips/saved`.
class SavedPlanStop {
  const SavedPlanStop({
    required this.id,
    required this.slot,
    required this.timeLabel,
    this.startTime,
    this.endTime,
    required this.title,
    required this.note,
  });

  final String id;
  final String slot;
  final String timeLabel;
  final String? startTime;
  final String? endTime;
  final String title;
  final String note;

  factory SavedPlanStop.fromJson(Map<String, dynamic> json) {
    return SavedPlanStop(
      id: json['id'] as String? ?? '',
      slot: json['slot'] as String? ?? '',
      timeLabel: json['time_label'] as String? ?? '',
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}

/// One saved plan item from `GET /api/trips/saved`.
class SavedPlanItem {
  const SavedPlanItem({
    required this.idPlan,
    this.customTitle,
    required this.duration,
    required this.startAt,
    required this.endAt,
    required this.provinceName,
    required this.createdAt,
    required this.stops,
  });

  final String idPlan;
  final String? customTitle;
  final String duration;
  final String startAt;
  final String endAt;
  final String provinceName;
  final String createdAt;
  final List<SavedPlanStop> stops;

  factory SavedPlanItem.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'] as List<dynamic>? ?? <dynamic>[];
    return SavedPlanItem(
      idPlan: json['id_plan'] as String? ?? '',
      customTitle: json['custom_title'] as String?,
      duration: json['duration'] as String? ?? '',
      startAt: json['start_at'] as String? ?? '',
      endAt: json['end_at'] as String? ?? '',
      provinceName: json['province_name'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      stops: rawStops
          .whereType<Map<String, dynamic>>()
          .map(SavedPlanStop.fromJson)
          .toList(),
    );
  }
}

/// One row from `cf_retrain_log`, returned by the `getCfRetrainLogs` action.
class CfRetrainLog {
  const CfRetrainLog({
    required this.idLog,
    required this.triggeredBy,
    required this.startedAt,
    this.finishedAt,
    required this.status,
    this.rowsWritten,
    this.errorMsg,
  });

  final String idLog;
  final String triggeredBy;
  final String startedAt;
  final String? finishedAt;
  final String status;
  final int? rowsWritten;
  final String? errorMsg;

  factory CfRetrainLog.fromJson(Map<String, dynamic> json) {
    return CfRetrainLog(
      idLog: json['id_log'] as String? ?? '',
      triggeredBy: json['triggered_by'] as String? ?? '',
      startedAt: json['started_at'] as String? ?? '',
      finishedAt: json['finished_at'] as String?,
      status: json['status'] as String? ?? '',
      rowsWritten: (json['rows_written'] as num?)?.toInt(),
      errorMsg: json['error_msg'] as String?,
    );
  }
}

/// Persisted UTC schedule for APScheduler's `daily_cf_retrain` job.
class CfRetrainSchedule {
  const CfRetrainSchedule({
    required this.hourUtc,
    required this.minuteUtc,
    required this.timezone,
    this.nextRunAtUtc,
    this.updatedAt,
    this.updatedBy,
  });

  final int hourUtc;
  final int minuteUtc;
  final String timezone;
  final String? nextRunAtUtc;
  final String? updatedAt;
  final String? updatedBy;

  factory CfRetrainSchedule.fromJson(Map<String, dynamic> json) {
    return CfRetrainSchedule(
      hourUtc: (json['hour_utc'] as num).toInt(),
      minuteUtc: (json['minute_utc'] as num).toInt(),
      timezone: json['timezone'] as String? ?? 'UTC',
      nextRunAtUtc: json['next_run_at_utc'] as String?,
      updatedAt: json['updated_at'] as String?,
      updatedBy: json['updated_by'] as String?,
    );
  }
}

/// One plan overdue for the "Have you completed your trip?" check, from the
/// `overdueTripCheck` action.
class OverdueTripPlan {
  const OverdueTripPlan({
    required this.idPlan,
    this.customTitle,
    required this.startAt,
    required this.endAt,
    required this.provinceName,
  });

  final String idPlan;
  final String? customTitle;
  final String startAt;
  final String endAt;
  final String provinceName;

  factory OverdueTripPlan.fromJson(Map<String, dynamic> json) {
    return OverdueTripPlan(
      idPlan: json['id_plan'] as String? ?? '',
      customTitle: json['custom_title'] as String?,
      startAt: json['start_at'] as String? ?? '',
      endAt: json['end_at'] as String? ?? '',
      provinceName: json['province_name'] as String? ?? '',
    );
  }
}

/// Nearby amenity from `GET /api/places/nearby`.
class NearbyPlace {
  const NearbyPlace({
    required this.idPlace,
    required this.name,
    required this.subcategoryName,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.estimatedMinutes,
  });

  final String idPlace;
  final String name;
  final String subcategoryName;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final int estimatedMinutes;

  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    return NearbyPlace(
      idPlace: json['id_place'] as String? ?? '',
      name: json['name'] as String? ?? '',
      subcategoryName: json['subcategory_name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Summary item from `GET /api/trips/plans`.
class TripPlanSummary {
  const TripPlanSummary({
    required this.idPlan,
    required this.duration,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
    this.idProvince,
  });

  final String idPlan;
  final String duration;
  final String startAt;
  final String endAt;
  final String createdAt;
  // db/queries_plan.py's list_plans() already returns city_province — was
  // just never surfaced here. Used by TripRepository.findRecentMatchingPlan()
  // to recover from a client-side timeout that raced ahead of a plan the
  // backend actually finished creating (see trip_repository.dart).
  final String? idProvince;

  factory TripPlanSummary.fromJson(Map<String, dynamic> json) {
    final String? rawProvince = json['city_province'] as String?;
    return TripPlanSummary(
      idPlan: json['id_plan'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      startAt: json['start_at'] as String? ?? '',
      endAt: json['end_at'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      idProvince: (rawProvince == null || rawProvince.trim().isEmpty)
          ? null
          : rawProvince,
    );
  }
}
