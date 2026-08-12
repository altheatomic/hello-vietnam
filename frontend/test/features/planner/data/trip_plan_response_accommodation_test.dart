import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';

Map<String, dynamic> _responseWithRecommendation() {
  return <String, dynamic>{
    'id_plan': null,
    'days': <Map<String, dynamic>>[
      <String, dynamic>{
        'day': 1,
        'date': '2026-08-01',
        'places': <Map<String, dynamic>>[],
      },
    ],
    'accommodation_recommendation': <String, dynamic>{
      'version': 1,
      'strategy': 'single_zone',
      'zones': <Map<String, dynamic>>[
        <String, dynamic>{
          'zone_index': 1,
          'day_from': 1,
          'day_to': 3,
          'latitude': 21.0285,
          'longitude': 105.8542,
          'google_maps_query': 'hotels near 21.0285,105.8542',
        },
      ],
      'evaluation': <String, dynamic>{
        'single_zone_cost_km': 18.4,
        'selected_cost_km': 18.4,
        'reduction_ratio': 0.0,
        'objective_weights': <String, dynamic>{
          'mean_distance': 0.6,
          'worst_day_distance': 0.4,
        },
        'min_zone_separation_km': 50.0,
        'min_cost_reduction_ratio': 0.35,
      },
    },
  };
}

void main() {
  test('parses one accommodation zone and evaluation thresholds', () {
    final plan = TripPlanResponse.fromJson(_responseWithRecommendation());

    expect(plan.accommodationRecommendation!.zones.single.dayFrom, 1);
    expect(plan.accommodationRecommendation!.zones.single.latitude, 21.0285);
    expect(
      plan.accommodationRecommendation!.evaluation.minZoneSeparationKm,
      50.0,
    );
  });

  test('keeps compatibility when recommendation is absent', () {
    final plan = TripPlanResponse.fromJson(<String, dynamic>{
      'id_plan': null,
      'days': <Map<String, dynamic>>[],
    });

    expect(plan.accommodationRecommendation, isNull);
  });
}
