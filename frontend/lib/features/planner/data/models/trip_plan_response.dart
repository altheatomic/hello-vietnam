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
  const TripPlanResponse({required this.idPlan, required this.days});

  final String? idPlan;
  final List<TripPlanDay> days;

  factory TripPlanResponse.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? <dynamic>[];
    return TripPlanResponse(
      idPlan: json['id_plan'] as String?,
      days:   rawDays
          .whereType<Map<String, dynamic>>()
          .map(TripPlanDay.fromJson)
          .toList(),
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
      day:    (json['day'] as num).toInt(),
      date:   json['date'] as String? ?? '',
      places: rawPlaces
          .whereType<Map<String, dynamic>>()
          .map(TripPlanPlace.fromJson)
          .toList(),
    );
  }
}

class TripPlanPlace {
  const TripPlanPlace({
    required this.order,
    required this.idPlace,
    required this.name,
    this.slot,
    this.latitude,
    this.longitude,
    this.estimatedTravelMinutes,
    this.tagMatch,
    this.cfScore,
    this.finalScore,
  });

  final int order;
  final String idPlace;
  final String name;
  final String? slot;
  final double? latitude;
  final double? longitude;
  final int? estimatedTravelMinutes;
  final double? tagMatch;
  final double? cfScore;
  final double? finalScore;

  factory TripPlanPlace.fromJson(Map<String, dynamic> json) {
    return TripPlanPlace(
      order:                    (json['order'] as num).toInt(),
      idPlace:                  json['id_place'] as String? ?? '',
      name:                     json['name'] as String? ?? '',
      slot:                     json['slot'] as String?,
      latitude:                 (json['latitude'] as num?)?.toDouble(),
      longitude:                (json['longitude'] as num?)?.toDouble(),
      estimatedTravelMinutes:   (json['estimated_travel_minutes'] as num?)?.toInt(),
      tagMatch:                 (json['tag_match'] as num?)?.toDouble(),
      cfScore:                  (json['cf_score'] as num?)?.toDouble(),
      finalScore:               (json['final_score'] as num?)?.toDouble(),
    );
  }
}

/// One stop (place) inside a saved plan card, from `GET /api/trips/saved`.
class SavedPlanStop {
  const SavedPlanStop({
    required this.id,
    required this.slot,
    required this.timeLabel,
    required this.title,
    required this.note,
  });

  final String id;
  final String slot;
  final String timeLabel;
  final String title;
  final String note;

  factory SavedPlanStop.fromJson(Map<String, dynamic> json) {
    return SavedPlanStop(
      id:        json['id']         as String? ?? '',
      slot:      json['slot']       as String? ?? '',
      timeLabel: json['time_label'] as String? ?? '',
      title:     json['title']      as String? ?? '',
      note:      json['note']       as String? ?? '',
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
      idPlan:       json['id_plan']       as String? ?? '',
      customTitle:  json['custom_title']  as String?,
      duration:     json['duration']      as String? ?? '',
      startAt:      json['start_at']      as String? ?? '',
      endAt:        json['end_at']        as String? ?? '',
      provinceName: json['province_name'] as String? ?? '',
      createdAt:    json['created_at']    as String? ?? '',
      stops: rawStops
          .whereType<Map<String, dynamic>>()
          .map(SavedPlanStop.fromJson)
          .toList(),
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
      idPlace:           json['id_place']           as String? ?? '',
      name:              json['name']               as String? ?? '',
      subcategoryName:   json['subcategory_name']   as String? ?? '',
      latitude:          (json['latitude']          as num?)?.toDouble() ?? 0.0,
      longitude:         (json['longitude']         as num?)?.toDouble() ?? 0.0,
      distanceKm:        (json['distance_km']       as num?)?.toDouble() ?? 0.0,
      estimatedMinutes:  (json['estimated_minutes'] as num?)?.toInt() ?? 0,
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
  });

  final String idPlan;
  final String duration;
  final String startAt;
  final String endAt;
  final String createdAt;

  factory TripPlanSummary.fromJson(Map<String, dynamic> json) {
    return TripPlanSummary(
      idPlan:    json['id_plan']    as String? ?? '',
      duration:  json['duration']   as String? ?? '',
      startAt:   json['start_at']   as String? ?? '',
      endAt:     json['end_at']     as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
