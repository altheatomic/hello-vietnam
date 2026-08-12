import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/presentation/trip_result_page.dart';

void main() {
  testWidgets(
    'generated itinerary shows locally calculated accommodation zones',
    (WidgetTester tester) async {
      const TripPlanResponse plan = TripPlanResponse(
        idPlan: null,
        days: <TripPlanDay>[
          TripPlanDay(
            day: 1,
            date: '2026-08-01',
            places: <TripPlanPlace>[
              TripPlanPlace(latitude: 21.02, longitude: 105.84),
            ],
          ),
          TripPlanDay(
            day: 2,
            date: '2026-08-02',
            places: <TripPlanPlace>[
              TripPlanPlace(latitude: 21.03, longitude: 105.85),
            ],
          ),
          TripPlanDay(
            day: 3,
            date: '2026-08-03',
            places: <TripPlanPlace>[
              TripPlanPlace(latitude: 21.04, longitude: 105.86),
            ],
          ),
          TripPlanDay(
            day: 4,
            date: '2026-08-04',
            places: <TripPlanPlace>[
              TripPlanPlace(latitude: 20.85, longitude: 106.60),
            ],
          ),
          TripPlanDay(
            day: 5,
            date: '2026-08-05',
            places: <TripPlanPlace>[
              TripPlanPlace(latitude: 20.86, longitude: 106.61),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(home: TripResultPage(plan: plan)),
      );

      expect(find.text('Days 1–3'), findsOneWidget);
      expect(find.text('Days 4–5'), findsOneWidget);
      expect(find.text('Find hotels on Google Maps'), findsNWidgets(2));
    },
  );
}
