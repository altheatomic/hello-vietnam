import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/data/accommodation_recommendation_calculator.dart';

TripPlanDay _day(int day, List<List<double>> coordinates) {
  return TripPlanDay(
    day: day,
    date: '2026-08-${day.toString().padLeft(2, '0')}',
    places: coordinates
        .asMap()
        .entries
        .map(
          (entry) => TripPlanPlace(
            order: entry.key + 1,
            idPlace: 'place-$day-${entry.key}',
            name: 'Place $day-${entry.key}',
            latitude: entry.value[0],
            longitude: entry.value[1],
          ),
        )
        .toList(),
  );
}

List<TripPlanDay> _separatedSevenDayTrip() {
  return <TripPlanDay>[
    _day(1, <List<double>>[
      <double>[21.02, 105.84],
    ]),
    _day(2, <List<double>>[
      <double>[21.03, 105.85],
    ]),
    _day(3, <List<double>>[
      <double>[21.04, 105.86],
    ]),
    _day(4, <List<double>>[
      <double>[20.85, 106.60],
    ]),
    _day(5, <List<double>>[
      <double>[20.86, 106.61],
    ]),
    _day(6, <List<double>>[
      <double>[20.87, 106.62],
    ]),
    _day(7, <List<double>>[
      <double>[20.88, 106.63],
    ]),
  ];
}

void main() {
  test('short trips always use one accommodation zone', () {
    final result = calculateAccommodationRecommendation(<TripPlanDay>[
      _day(1, <List<double>>[
        <double>[21.02, 105.84],
      ]),
      _day(2, <List<double>>[
        <double>[21.03, 105.85],
      ]),
      _day(3, <List<double>>[
        <double>[21.04, 105.86],
      ]),
    ]);

    expect(result!.strategy, 'single_zone');
    expect(result.zones.single.dayFrom, 1);
    expect(result.zones.single.dayTo, 3);
  });

  test('separated contiguous days split into two zones', () {
    final result = calculateAccommodationRecommendation(
      _separatedSevenDayTrip(),
    );

    expect(result!.strategy, 'multi_zone');
    expect(
      result.zones.map((zone) => <int>[zone.dayFrom, zone.dayTo]).toList(),
      <List<int>>[
        <int>[1, 3],
        <int>[4, 7],
      ],
    );
  });

  test('nearby groups do not split when centers are under 50 km apart', () {
    final result = calculateAccommodationRecommendation(<TripPlanDay>[
      _day(1, <List<double>>[
        <double>[21.02, 105.84],
      ]),
      _day(2, <List<double>>[
        <double>[21.03, 105.85],
      ]),
      _day(3, <List<double>>[
        <double>[21.04, 105.86],
      ]),
      _day(4, <List<double>>[
        <double>[21.10, 106.05],
      ]),
      _day(5, <List<double>>[
        <double>[21.11, 106.06],
      ]),
    ]);

    expect(result!.strategy, 'single_zone');
  });

  test('groups with a radius over 12 km are not accepted as zones', () {
    final result = calculateAccommodationRecommendation(<TripPlanDay>[
      _day(1, <List<double>>[
        <double>[21.00, 105.80],
        <double>[21.30, 105.80],
      ]),
      _day(2, <List<double>>[
        <double>[21.10, 105.80],
      ]),
      _day(3, <List<double>>[
        <double>[21.10, 105.80],
      ]),
      _day(4, <List<double>>[
        <double>[20.85, 106.60],
      ]),
      _day(5, <List<double>>[
        <double>[20.86, 106.61],
      ]),
    ]);

    expect(result!.strategy, 'single_zone');
  });

  test('split is rejected when travel-cost reduction is below threshold', () {
    final result = calculateAccommodationRecommendation(
      _separatedSevenDayTrip(),
      minTravelCostReductionRatio: 0.99,
    );

    expect(result!.strategy, 'single_zone');
  });

  test('nine-day trips can use three contiguous accommodation zones', () {
    final result = calculateAccommodationRecommendation(<TripPlanDay>[
      ..._separatedSevenDayTrip().take(3),
      _day(4, <List<double>>[
        <double>[20.85, 106.60],
      ]),
      _day(5, <List<double>>[
        <double>[20.86, 106.61],
      ]),
      _day(6, <List<double>>[
        <double>[20.87, 106.62],
      ]),
      _day(7, <List<double>>[
        <double>[20.25, 105.97],
      ]),
      _day(8, <List<double>>[
        <double>[20.26, 105.98],
      ]),
      _day(9, <List<double>>[
        <double>[20.27, 105.99],
      ]),
    ]);

    expect(result!.strategy, 'multi_zone');
    expect(
      result.zones.map((zone) => <int>[zone.dayFrom, zone.dayTo]).toList(),
      <List<int>>[
        <int>[1, 3],
        <int>[4, 6],
        <int>[7, 9],
      ],
    );
  });
}
