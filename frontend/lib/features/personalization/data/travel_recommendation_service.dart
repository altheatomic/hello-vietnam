import 'package:hellovietnam/features/explore/data/explore_mock_data.dart';
import 'package:hellovietnam/features/explore/domain/explore_item.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/personalization/domain/travel_preferences.dart';
import 'package:hellovietnam/features/recommend/data/recommend_mock_data.dart';
import 'package:hellovietnam/features/recommend/domain/recommend_destination.dart';

class TravelRecommendationService {
  TravelRecommendationService._();

  static List<RecommendDestination> recommendedDestinations(
    UserTravelPreferences preferences,
  ) {
    final Map<String, int> keywordWeights = _keywordWeights(preferences);
    final List<RecommendDestination> destinations =
        List<RecommendDestination>.from(mockRecommendDestinations);

    destinations.sort((RecommendDestination a, RecommendDestination b) {
      final int scoreA = _destinationScore(a, keywordWeights);
      final int scoreB = _destinationScore(b, keywordWeights);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      return b.rating.compareTo(a.rating);
    });
    return destinations;
  }

  static List<ExploreItem> recommendedExploreItems(
    UserTravelPreferences preferences,
  ) {
    final Map<String, int> keywordWeights = _keywordWeights(preferences);
    final List<ExploreItem> allItems = <ExploreItem>[
      ...exploreFeatured,
      ...exploreCategories.expand((category) => category.items),
    ];

    final Map<String, ExploreItem> deduped = <String, ExploreItem>{};
    for (final ExploreItem item in allItems) {
      deduped['${item.category.name}:${item.id}:${item.name}'] = item;
    }

    final List<ExploreItem> items = deduped.values.toList(growable: false);
    items.sort((ExploreItem a, ExploreItem b) {
      final int scoreA = _exploreScore(a, preferences, keywordWeights);
      final int scoreB = _exploreScore(b, preferences, keywordWeights);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      return a.name.compareTo(b.name);
    });
    return items;
  }

  static List<ExploreCategory> orderedExploreCategories(
    UserTravelPreferences preferences,
  ) {
    final List<DetailCategory> preferredOrder = preferences.preferredCategories;
    final List<ExploreCategory> categories = List<ExploreCategory>.from(
      exploreCategories,
    );

    categories.sort((ExploreCategory a, ExploreCategory b) {
      final int indexA = preferredOrder.indexOf(_categoryForExplore(a));
      final int indexB = preferredOrder.indexOf(_categoryForExplore(b));
      return indexA.compareTo(indexB);
    });
    return categories;
  }

  static DetailCategory _categoryForExplore(ExploreCategory category) {
    switch (category.id) {
      case 'culture':
        return DetailCategory.culture;
      case 'food':
        return DetailCategory.food;
      case 'local_products':
        return DetailCategory.localProducts;
      case 'activities':
      default:
        return DetailCategory.activities;
    }
  }

  static int _exploreScore(
    ExploreItem item,
    UserTravelPreferences preferences,
    Map<String, int> keywordWeights,
  ) {
    int score = 0;
    if (preferences.preferredCategories.take(2).contains(item.category)) {
      score += 12;
    } else if (preferences.preferredCategories.contains(item.category)) {
      score += 6;
    }

    final String haystack = item.name.toLowerCase();
    for (final MapEntry<String, int> entry in keywordWeights.entries) {
      if (haystack.contains(entry.key)) {
        score += entry.value;
      }
    }
    return score;
  }

  static int _destinationScore(
    RecommendDestination destination,
    Map<String, int> keywordWeights,
  ) {
    int score = 0;
    final String haystack = <String>[
      destination.name,
      destination.shortDescription,
      destination.description,
      destination.highlights,
      ...destination.tags,
      ...destination.activities,
      ...destination.cuisine.map((food) => food.name),
    ].join(' ').toLowerCase();

    for (final MapEntry<String, int> entry in keywordWeights.entries) {
      if (haystack.contains(entry.key)) {
        score += entry.value;
      }
    }

    score += (destination.rating * 2).round();
    return score;
  }

  static Map<String, int> _keywordWeights(UserTravelPreferences preferences) {
    final Map<String, int> weights = <String, int>{};

    void addWords(Iterable<String> words, int weight) {
      for (final String word in words) {
        final String normalized = word.toLowerCase();
        weights.update(
          normalized,
          (int current) => current + weight,
          ifAbsent: () => weight,
        );
      }
    }

    for (final TravelStyle style in preferences.travelStyles) {
      switch (style) {
        case TravelStyle.food:
          addWords(<String>['food', 'street', 'seafood', 'coffee', 'pho'], 7);
          break;
        case TravelStyle.culture:
          addWords(<String>[
            'culture',
            'history',
            'heritage',
            'museum',
            'temple',
          ], 7);
          break;
        case TravelStyle.nature:
          addWords(<String>[
            'nature',
            'beach',
            'mountain',
            'lake',
            'island',
          ], 7);
          break;
        case TravelStyle.relaxation:
          addWords(<String>['relax', 'coast', 'spa', 'sunny', 'peaceful'], 6);
          break;
        case TravelStyle.adventure:
          addWords(<String>['adventure', 'hike', 'kayak', 'trek', 'cruise'], 8);
          break;
        case TravelStyle.shopping:
          addWords(<String>['market', 'shopping', 'craft', 'souvenir'], 6);
          break;
        case TravelStyle.photography:
          addWords(<String>['view', 'sunset', 'scenic', 'night market'], 6);
          break;
        case TravelStyle.localDiscovery:
          addWords(<String>['local', 'market', 'village', 'authentic'], 6);
          break;
      }
    }

    for (final InterestTopic topic in preferences.topics) {
      switch (topic) {
        case InterestTopic.streetFood:
          addWords(<String>['street food', 'banh mi', 'bun bo', 'pho'], 9);
          break;
        case InterestTopic.coffee:
          addWords(<String>['coffee', 'cafe'], 8);
          break;
        case InterestTopic.museums:
          addWords(<String>['museum', 'history'], 8);
          break;
        case InterestTopic.temples:
          addWords(<String>['temple', 'pagoda'], 8);
          break;
        case InterestTopic.festivals:
          addWords(<String>['festival', 'celebration', 'culture'], 8);
          break;
        case InterestTopic.beaches:
          addWords(<String>['beach', 'coast', 'sea'], 9);
          break;
        case InterestTopic.mountains:
          addWords(<String>['mountain', 'trek', 'highland'], 9);
          break;
        case InterestTopic.nightMarkets:
          addWords(<String>['night market', 'market'], 7);
          break;
        case InterestTopic.workshops:
          addWords(<String>['craft', 'workshop'], 8);
          break;
        case InterestTopic.handmadeProducts:
          addWords(<String>['pottery', 'craft', 'handmade', 'conical'], 8);
          break;
        case InterestTopic.scenicSpots:
          addWords(<String>['lake', 'view', 'sunrise', 'sunset'], 8);
          break;
        case InterestTopic.wellness:
          addWords(<String>['wellness', 'spa', 'peaceful'], 8);
          break;
      }
    }

    switch (preferences.budgetLevel) {
      case BudgetLevel.budget:
        addWords(<String>['market', 'street', 'local'], 3);
        break;
      case BudgetLevel.premium:
        addWords(<String>['premium', 'luxury', 'exclusive'], 3);
        break;
      case BudgetLevel.moderate:
      case BudgetLevel.comfort:
        break;
    }

    if (preferences.companions.contains(TravelCompanion.familyKids) ||
        preferences.companions.contains(TravelCompanion.seniors)) {
      addWords(<String>['peaceful', 'easy', 'heritage'], 2);
    }

    return weights;
  }
}
