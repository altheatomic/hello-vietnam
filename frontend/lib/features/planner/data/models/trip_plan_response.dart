/// Response from `action: planTrip` / `GET /api/trips/plan/:id`.
///
/// Shape returned by cf_service:
/// {
///   "id_plan": "uuid" | null,
///   "days": [
///     {
///       "day": 1,
///       "date": "2026-06-07",
///       "places": [
///         {
///           "order": 1,
///           "id_place": "uuid",
///           "name": "...",
///           "slot": "morning",
///           "latitude": 16.0,
///           "longitude": 108.0,
///           "estimated_travel_minutes": 12,
///           "cb_score": 0.75,
///           "cf_score": 0.62,
///           "final_score": 0.70
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
    this.cbScore,
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
  final double? cbScore;
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
      cbScore:                  (json['cb_score'] as num?)?.toDouble(),
      cfScore:                  (json['cf_score'] as num?)?.toDouble(),
      finalScore:               (json['final_score'] as num?)?.toDouble(),
    );
  }
}

/// Summary item from `action: listPlans`.
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
