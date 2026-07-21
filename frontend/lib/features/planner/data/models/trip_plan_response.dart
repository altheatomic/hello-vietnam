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
    this.coverImage,
    this.gallery = const <Map<String, dynamic>>[],
    this.tagMatch,
    this.cfScore,
    this.finalScore,
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
  final String? coverImage;
  /// List of {url, type, source} objects from the DB gallery jsonb column.
  final List<Map<String, dynamic>> gallery;
  final double? tagMatch;
  final double? cfScore;
  final double? finalScore;

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
        ? rawGallery
            .whereType<Map<String, dynamic>>()
            .toList()
        : <Map<String, dynamic>>[];

    final TripPlanPlace place = TripPlanPlace(
      type:                       json['type'] as String? ?? 'place',
      order:                      (json['order'] as num?)?.toInt() ?? 0,
      idPlace:                    json['id_place'] as String? ?? '',
      name:                       json['name'] as String? ?? '',
      slot:                       json['slot'] as String?,
      startTime:                  json['start_time'] as String?,
      endTime:                    json['end_time'] as String?,
      warning:                    json['warning'] as String?,
      latitude:                   (json['latitude'] as num?)?.toDouble(),
      longitude:                  (json['longitude'] as num?)?.toDouble(),
      estimatedTravelMinutes:     (json['estimated_travel_minutes'] as num?)?.toInt(),
      estimatedDurationMinutes:   (json['estimated_duration_minutes'] as num?)?.toInt(),
      coverImage:                 json['cover_image'] as String?,
      gallery:                    gallery,
      tagMatch:                   (json['tag_match'] as num?)?.toDouble(),
      cfScore:                    (json['cf_score'] as num?)?.toDouble(),
      finalScore:                 (json['final_score'] as num?)?.toDouble(),
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
      id:        json['id']         as String? ?? '',
      slot:      json['slot']       as String? ?? '',
      timeLabel: json['time_label'] as String? ?? '',
      startTime: json['start_time'] as String?,
      endTime:   json['end_time']   as String?,
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
      idLog:       json['id_log']       as String? ?? '',
      triggeredBy: json['triggered_by'] as String? ?? '',
      startedAt:   json['started_at']   as String? ?? '',
      finishedAt:  json['finished_at']  as String?,
      status:      json['status']       as String? ?? '',
      rowsWritten: (json['rows_written'] as num?)?.toInt(),
      errorMsg:    json['error_msg']    as String?,
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
