import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/personalization/data/travel_recommendation_service.dart';
import 'package:hellovietnam/features/personalization/domain/travel_preferences.dart';
import 'package:hellovietnam/features/recommend/domain/recommend_destination.dart';

void main() {
  final UserTravelPreferences preferences = UserTravelPreferences(
    travelStyles: const <TravelStyle>[TravelStyle.food],
    companions: const <TravelCompanion>[TravelCompanion.solo],
    budgetLevel: BudgetLevel.moderate,
    pace: TravelPace.balanced,
    topics: const <InterestTopic>[InterestTopic.streetFood],
    completedAt: DateTime.utc(2026, 7, 27),
  );

  RecommendDestination candidate({
    required String id,
    required String description,
    double? avgRating,
  }) {
    return RecommendDestination(
      id: id,
      name: id,
      shortDescription: description,
      description: description,
      imagePath: 'https://media.test/$id.jpg',
      rating: 0,
      avgRating: avgRating,
    );
  }

  test('ranks only supplied candidates by preference match', () {
    final List<RecommendDestination> result =
        TravelRecommendationService.rankDestinations(
          preferences: preferences,
          candidates: <RecommendDestination>[
            candidate(id: 'museum', description: 'history museum'),
            candidate(id: 'street-food', description: 'street food and pho'),
          ],
        );

    expect(result.map((RecommendDestination item) => item.id), <String>[
      'street-food',
      'museum',
    ]);
  });

  test('uses average rating only as a deterministic score tie-breaker', () {
    final List<RecommendDestination> result =
        TravelRecommendationService.rankDestinations(
          preferences: preferences,
          candidates: <RecommendDestination>[
            candidate(id: 'lower', description: 'local', avgRating: 4.1),
            candidate(id: 'higher', description: 'local', avgRating: 4.8),
          ],
        );

    expect(result.first.id, 'higher');
  });

  test('keeps an empty candidate set empty', () {
    expect(
      TravelRecommendationService.rankDestinations(
        preferences: preferences,
        candidates: const <RecommendDestination>[],
      ),
      isEmpty,
    );
  });
}
