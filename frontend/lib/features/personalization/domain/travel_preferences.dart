import 'dart:convert';

import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

enum TravelStyle {
  food,
  culture,
  nature,
  relaxation,
  adventure,
  shopping,
  photography,
  localDiscovery,
}

extension TravelStyleX on TravelStyle {
  String get label {
    switch (this) {
      case TravelStyle.food:
        return 'Food';
      case TravelStyle.culture:
        return 'Culture';
      case TravelStyle.nature:
        return 'Nature';
      case TravelStyle.relaxation:
        return 'Relaxation';
      case TravelStyle.adventure:
        return 'Adventure';
      case TravelStyle.shopping:
        return 'Shopping';
      case TravelStyle.photography:
        return 'Photography';
      case TravelStyle.localDiscovery:
        return 'Local Life';
    }
  }

  String get subtitle {
    switch (this) {
      case TravelStyle.food:
        return 'Street food, specialties, local flavors';
      case TravelStyle.culture:
        return 'History, rituals, art, heritage';
      case TravelStyle.nature:
        return 'Mountains, beaches, gardens, scenery';
      case TravelStyle.relaxation:
        return 'Easy pacing, cafes, spa, slow travel';
      case TravelStyle.adventure:
        return 'Energetic activities and new thrills';
      case TravelStyle.shopping:
        return 'Markets, crafts, local finds';
      case TravelStyle.photography:
        return 'Scenic spots and memorable visuals';
      case TravelStyle.localDiscovery:
        return 'Neighborhood vibes and authentic moments';
    }
  }

  DetailCategory get primaryCategory {
    switch (this) {
      case TravelStyle.food:
        return DetailCategory.food;
      case TravelStyle.culture:
        return DetailCategory.culture;
      case TravelStyle.shopping:
        return DetailCategory.localProducts;
      case TravelStyle.nature:
      case TravelStyle.relaxation:
      case TravelStyle.adventure:
      case TravelStyle.photography:
      case TravelStyle.localDiscovery:
        return DetailCategory.activities;
    }
  }
}

enum TravelCompanion { solo, couple, friends, familyKids, seniors, business }

extension TravelCompanionX on TravelCompanion {
  String get label {
    switch (this) {
      case TravelCompanion.solo:
        return 'Solo';
      case TravelCompanion.couple:
        return 'Couple';
      case TravelCompanion.friends:
        return 'Friends';
      case TravelCompanion.familyKids:
        return 'Family';
      case TravelCompanion.seniors:
        return 'Seniors';
      case TravelCompanion.business:
        return 'Business';
    }
  }

  String get subtitle {
    switch (this) {
      case TravelCompanion.solo:
        return 'Freedom and flexible pacing';
      case TravelCompanion.couple:
        return 'Romantic and cozy suggestions';
      case TravelCompanion.friends:
        return 'Fun group-friendly experiences';
      case TravelCompanion.familyKids:
        return 'Easy, safe, family-ready options';
      case TravelCompanion.seniors:
        return 'Comfortable and low-effort plans';
      case TravelCompanion.business:
        return 'Efficient stops around a work trip';
    }
  }
}

enum BudgetLevel { budget, moderate, comfort, premium }

extension BudgetLevelX on BudgetLevel {
  String get label {
    switch (this) {
      case BudgetLevel.budget:
        return 'Budget';
      case BudgetLevel.moderate:
        return 'Mid-range';
      case BudgetLevel.comfort:
        return 'Comfort';
      case BudgetLevel.premium:
        return 'Premium';
    }
  }

  String get subtitle {
    switch (this) {
      case BudgetLevel.budget:
        return 'Smart spending and free gems';
      case BudgetLevel.moderate:
        return 'Balanced value and comfort';
      case BudgetLevel.comfort:
        return 'More flexibility and polish';
      case BudgetLevel.premium:
        return 'Top picks and upgraded stays';
    }
  }
}

enum TravelPace { easy, balanced, active, packed }

extension TravelPaceX on TravelPace {
  String get label {
    switch (this) {
      case TravelPace.easy:
        return 'Easy';
      case TravelPace.balanced:
        return 'Balanced';
      case TravelPace.active:
        return 'Active';
      case TravelPace.packed:
        return 'Packed';
    }
  }

  String get subtitle {
    switch (this) {
      case TravelPace.easy:
        return 'Slow mornings and room to breathe';
      case TravelPace.balanced:
        return 'A healthy mix of must-sees and rest';
      case TravelPace.active:
        return 'More stops and more movement';
      case TravelPace.packed:
        return 'Make the most of every hour';
    }
  }
}

enum InterestTopic {
  streetFood,
  coffee,
  museums,
  temples,
  festivals,
  beaches,
  mountains,
  nightMarkets,
  workshops,
  handmadeProducts,
  scenicSpots,
  wellness,
}

extension InterestTopicX on InterestTopic {
  String get label {
    switch (this) {
      case InterestTopic.streetFood:
        return 'Street Food';
      case InterestTopic.coffee:
        return 'Coffee';
      case InterestTopic.museums:
        return 'Museums';
      case InterestTopic.temples:
        return 'Temples';
      case InterestTopic.festivals:
        return 'Festivals';
      case InterestTopic.beaches:
        return 'Beaches';
      case InterestTopic.mountains:
        return 'Mountains';
      case InterestTopic.nightMarkets:
        return 'Night Markets';
      case InterestTopic.workshops:
        return 'Workshops';
      case InterestTopic.handmadeProducts:
        return 'Handmade Goods';
      case InterestTopic.scenicSpots:
        return 'Scenic Spots';
      case InterestTopic.wellness:
        return 'Wellness';
    }
  }

  DetailCategory get category {
    switch (this) {
      case InterestTopic.streetFood:
      case InterestTopic.coffee:
        return DetailCategory.food;
      case InterestTopic.museums:
      case InterestTopic.temples:
      case InterestTopic.festivals:
        return DetailCategory.culture;
      case InterestTopic.handmadeProducts:
        return DetailCategory.localProducts;
      case InterestTopic.beaches:
      case InterestTopic.mountains:
      case InterestTopic.nightMarkets:
      case InterestTopic.workshops:
      case InterestTopic.scenicSpots:
      case InterestTopic.wellness:
        return DetailCategory.activities;
    }
  }
}

class UserTravelPreferences {
  const UserTravelPreferences({
    required this.travelStyles,
    required this.companions,
    required this.budgetLevel,
    required this.pace,
    required this.topics,
    required this.completedAt,
  });

  final List<TravelStyle> travelStyles;
  final List<TravelCompanion> companions;
  final BudgetLevel budgetLevel;
  final TravelPace pace;
  final List<InterestTopic> topics;
  final DateTime completedAt;

  List<DetailCategory> get preferredCategories {
    final List<DetailCategory> ordered = <DetailCategory>[];
    void addCategory(DetailCategory category) {
      if (!ordered.contains(category)) {
        ordered.add(category);
      }
    }

    for (final TravelStyle style in travelStyles) {
      addCategory(style.primaryCategory);
    }
    for (final InterestTopic topic in topics) {
      addCategory(topic.category);
    }

    for (final DetailCategory category in DetailCategory.values) {
      addCategory(category);
    }
    return ordered;
  }

  List<String> get summaryLabels => <String>[
    ...travelStyles.take(2).map((style) => style.label),
    ...topics.take(3).map((topic) => topic.label),
    budgetLevel.label,
    pace.label,
  ];

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'travelStyles': travelStyles.map((style) => style.name).toList(),
      'companions': companions.map((companion) => companion.name).toList(),
      'budgetLevel': budgetLevel.name,
      'pace': pace.name,
      'topics': topics.map((topic) => topic.name).toList(),
      'completedAt': completedAt.toIso8601String(),
    };
  }

  String toStorageValue() => jsonEncode(toJson());

  factory UserTravelPreferences.fromJson(Map<String, dynamic> json) {
    return UserTravelPreferences(
      travelStyles: _parseEnumList(
        json['travelStyles'] as List<dynamic>? ?? const <dynamic>[],
        TravelStyle.values,
      ),
      companions: _parseEnumList(
        json['companions'] as List<dynamic>? ?? const <dynamic>[],
        TravelCompanion.values,
      ),
      budgetLevel: _parseEnum(
        json['budgetLevel'] as String?,
        BudgetLevel.values,
        BudgetLevel.moderate,
      ),
      pace: _parseEnum(
        json['pace'] as String?,
        TravelPace.values,
        TravelPace.balanced,
      ),
      topics: _parseEnumList(
        json['topics'] as List<dynamic>? ?? const <dynamic>[],
        InterestTopic.values,
      ),
      completedAt:
          DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  factory UserTravelPreferences.fromStorageValue(String raw) {
    return UserTravelPreferences.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  static T _parseEnum<T extends Enum>(String? raw, List<T> values, T fallback) {
    if (raw == null) {
      return fallback;
    }
    for (final T value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    return fallback;
  }

  static List<T> _parseEnumList<T extends Enum>(
    List<dynamic> rawList,
    List<T> values,
  ) {
    final List<T> parsed = <T>[];
    for (final dynamic raw in rawList) {
      if (raw is! String) {
        continue;
      }
      for (final T value in values) {
        if (value.name == raw && !parsed.contains(value)) {
          parsed.add(value);
        }
      }
    }
    return parsed;
  }
}
