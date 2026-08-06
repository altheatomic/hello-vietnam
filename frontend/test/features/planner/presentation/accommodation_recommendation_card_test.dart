import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/accommodation_recommendation_card.dart';

AccommodationRecommendation _recommendation() {
  return AccommodationRecommendation.fromJson(<String, dynamic>{
    'version': 1,
    'strategy': 'multi_zone',
    'zones': <Map<String, dynamic>>[
      <String, dynamic>{
        'zone_index': 1,
        'day_from': 1,
        'day_to': 3,
        'latitude': 21.0285,
        'longitude': 105.8542,
        'google_maps_query': 'hotels near 21.0285,105.8542',
      },
      <String, dynamic>{
        'zone_index': 2,
        'day_from': 4,
        'day_to': 7,
        'latitude': 20.85,
        'longitude': 106.60,
        'google_maps_query': 'hotels near 20.850000,106.600000',
      },
    ],
    'evaluation': <String, dynamic>{
      'single_zone_cost_km': 95.0,
      'selected_cost_km': 44.0,
      'reduction_ratio': 0.5368,
      'objective_weights': <String, dynamic>{
        'mean_distance': 0.6,
        'worst_day_distance': 0.4,
      },
      'min_zone_separation_km': 50.0,
      'min_cost_reduction_ratio': 0.35,
    },
  });
}

void main() {
  testWidgets('renders a Google Maps action for each accommodation zone',
      (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccommodationRecommendationCard(
            recommendation: _recommendation(),
            openUrl: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Find hotels on Google Maps'), findsNWidgets(2));
    await tester.tap(find.text('Find hotels on Google Maps').first);
    await tester.pump();

    expect(opened.single.queryParameters['query'], contains('21.0285'));
    expect(opened.single.queryParameters['query'], contains('105.8542'));
  });
}
