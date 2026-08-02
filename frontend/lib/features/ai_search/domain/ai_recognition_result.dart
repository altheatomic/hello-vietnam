enum AiRecognitionKind {
  food('food'),
  landmark('landmark'),
  culturalObject('cultural_object'),
  signText('sign_text'),
  unclear('unclear'),
  unsupported('unsupported');

  const AiRecognitionKind(this.wireValue);

  final String wireValue;

  static AiRecognitionKind parse(String? value, {String? legacyResultType}) {
    final String normalized = value?.trim().toLowerCase() ?? '';
    for (final AiRecognitionKind kind in values) {
      if (kind.wireValue == normalized) return kind;
    }
    if (normalized.isNotEmpty) return AiRecognitionKind.unsupported;
    return legacyResultType?.trim().toLowerCase() == 'food'
        ? AiRecognitionKind.food
        : AiRecognitionKind.culturalObject;
  }
}

class AiRecognitionTextAnalysis {
  const AiRecognitionTextAnalysis({
    required this.originalText,
    required this.detectedLanguageCode,
    required this.detectedLanguageName,
    required this.translatedText,
    required this.targetLanguageCode,
    required this.signType,
    required this.travelContext,
    required this.mapQuery,
    required this.canOpenMap,
  });

  final String originalText;
  final String detectedLanguageCode;
  final String detectedLanguageName;
  final String translatedText;
  final String targetLanguageCode;
  final String signType;
  final String travelContext;
  final String mapQuery;
  final bool canOpenMap;

  factory AiRecognitionTextAnalysis.fromJson(Map<String, dynamic> json) {
    return AiRecognitionTextAnalysis(
      originalText: _readString(json['original_text']),
      detectedLanguageCode: _readString(json['detected_language_code']),
      detectedLanguageName: _readString(json['detected_language_name']),
      translatedText: _readString(json['translated_text']),
      targetLanguageCode: _readString(json['target_language_code']),
      signType: _readString(json['sign_type']),
      travelContext: _readString(json['travel_context']),
      mapQuery: _readString(json['map_query']),
      canOpenMap: json['can_open_map'] == true,
    );
  }

  static AiRecognitionTextAnalysis? tryParse(Object? value) {
    if (value is! Map) return null;
    return AiRecognitionTextAnalysis.fromJson(Map<String, dynamic>.from(value));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'original_text': originalText,
    'detected_language_code': detectedLanguageCode,
    'detected_language_name': detectedLanguageName,
    'translated_text': translatedText,
    'target_language_code': targetLanguageCode,
    'sign_type': signType,
    'travel_context': travelContext,
    'map_query': mapQuery,
    'can_open_map': canOpenMap,
  };
}

class AiSearchResult {
  const AiSearchResult({
    required this.kind,
    required this.confidence,
    required this.detectedName,
    required this.subtitle,
    required this.summary,
    required this.locationHint,
    required this.categoryText,
    required this.primaryTags,
    required this.secondaryTags,
    required this.bestTime,
    required this.note,
    required this.culturalSignificance,
    required this.usageBullets,
    required this.productionMethod,
    required this.alternativeNames,
    required this.priceRange,
    required this.suggestedPlaces,
    this.schemaVersion = 2,
    this.confidenceBand = '',
    this.reasonCode = 'none',
    this.mapQuery = '',
    this.canOpenMap = false,
    this.textAnalysis,
    this.databaseMatch,
  });

  final int schemaVersion;
  final AiRecognitionKind kind;
  final double confidence;
  final String confidenceBand;
  final String detectedName;
  final String subtitle;
  final String summary;
  final String locationHint;
  final String categoryText;
  final String reasonCode;
  final List<String> primaryTags;
  final List<String> secondaryTags;
  final String bestTime;
  final String note;
  final String culturalSignificance;
  final List<String> usageBullets;
  final String productionMethod;
  final String alternativeNames;
  final String priceRange;
  final List<String> suggestedPlaces;
  final String mapQuery;
  final bool canOpenMap;
  final AiRecognitionTextAnalysis? textAnalysis;
  final AiSearchDatabaseMatch? databaseMatch;

  bool get isFood => kind == AiRecognitionKind.food;

  String get legacyResultType => isFood ? 'food' : 'object';

  String get resultType => legacyResultType;

  bool get isHistoryEligible => switch (kind) {
    AiRecognitionKind.food ||
    AiRecognitionKind.landmark ||
    AiRecognitionKind.culturalObject => detectedName.trim().isNotEmpty,
    AiRecognitionKind.signText =>
      textAnalysis?.originalText.trim().isNotEmpty ?? false,
    AiRecognitionKind.unclear || AiRecognitionKind.unsupported => false,
  };

  factory AiSearchResult.fromJson(Map<String, dynamic> json) {
    final AiRecognitionTextAnalysis? textAnalysis =
        AiRecognitionTextAnalysis.tryParse(json['text_analysis']);
    final String detectedName = _readString(json['detected_name']).isNotEmpty
        ? _readString(json['detected_name'])
        : textAnalysis?.originalText ?? '';
    final String mapQuery = _readString(json['map_query']).isNotEmpty
        ? _readString(json['map_query'])
        : textAnalysis?.mapQuery ?? '';
    final bool canOpenMap = json['can_open_map'] is bool
        ? json['can_open_map'] == true
        : textAnalysis?.canOpenMap ?? false;
    final String legacyResultType = _readString(json['result_type']);

    return AiSearchResult(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      kind: AiRecognitionKind.parse(
        json['result_kind'] is String ? json['result_kind'] as String : null,
        legacyResultType: legacyResultType,
      ),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      confidenceBand: _readString(json['confidence_band']),
      detectedName: detectedName,
      subtitle: _readString(json['subtitle']),
      summary: _readString(json['summary']),
      locationHint: _readString(json['location_hint']),
      categoryText: _readString(json['category_text']),
      reasonCode: _readString(json['reason_code']).isEmpty
          ? 'none'
          : _readString(json['reason_code']),
      primaryTags: _readStringList(json['primary_tags']),
      secondaryTags: _readStringList(json['secondary_tags']),
      bestTime: _readString(json['best_time']),
      note: _readString(json['note']),
      culturalSignificance: _readString(json['cultural_significance']),
      usageBullets: _readStringList(json['usage_bullets']),
      productionMethod: _readString(json['production_method']),
      alternativeNames: _readString(json['alternative_names']),
      priceRange: _readString(json['price_range']),
      suggestedPlaces: _readStringList(json['suggested_places']),
      mapQuery: mapQuery,
      canOpenMap: canOpenMap,
      textAnalysis: textAnalysis,
      databaseMatch: AiSearchDatabaseMatch.tryParse(json['db_match']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema_version': schemaVersion,
    'result_kind': kind.wireValue,
    'result_type': legacyResultType,
    'confidence': confidence,
    if (confidenceBand.isNotEmpty) 'confidence_band': confidenceBand,
    'detected_name': detectedName,
    'subtitle': subtitle,
    'summary': summary,
    'location_hint': locationHint,
    'category_text': categoryText,
    'reason_code': reasonCode,
    'primary_tags': primaryTags,
    'secondary_tags': secondaryTags,
    'best_time': bestTime,
    'note': note,
    'cultural_significance': culturalSignificance,
    'usage_bullets': usageBullets,
    'production_method': productionMethod,
    'alternative_names': alternativeNames,
    'price_range': priceRange,
    'suggested_places': suggestedPlaces,
    'map_query': mapQuery,
    'can_open_map': canOpenMap,
    if (textAnalysis != null) 'text_analysis': textAnalysis!.toJson(),
    if (databaseMatch != null) 'db_match': databaseMatch!.toJson(),
  };
}

class AiSearchDatabaseMatch {
  const AiSearchDatabaseMatch({
    required this.category,
    required this.id,
    required this.name,
    required this.matchScore,
    this.imagePath,
  });

  final String category;
  final String id;
  final String name;
  final double matchScore;
  final String? imagePath;

  static AiSearchDatabaseMatch? tryParse(Object? value) {
    if (value is! Map) return null;
    final Map<String, dynamic> json = Map<String, dynamic>.from(value);
    final String status = _readString(json['status']);
    final String category = _readString(json['category']);
    final String id = _readString(json['id']);
    final String name = _readString(json['name']);
    if (status != 'matched' || category.isEmpty || id.isEmpty || name.isEmpty) {
      return null;
    }

    final String imagePath = _readString(json['image_path']);
    return AiSearchDatabaseMatch(
      category: category,
      id: id,
      name: name,
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 0,
      imagePath: imagePath.isEmpty ? null : imagePath,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': 'matched',
    'category': category,
    'id': id,
    'name': name,
    'match_score': matchScore,
    if (imagePath != null) 'image_path': imagePath,
  };
}

String _readString(Object? value) => value is String ? value.trim() : '';

List<String> _readStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((Object? item) => item is String ? item.trim() : '')
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}
