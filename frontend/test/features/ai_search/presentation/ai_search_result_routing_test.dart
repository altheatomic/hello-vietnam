import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_search/application/ai_recognition_map_coordinator.dart';
import 'package:hellovietnam/features/ai_search/data/ai_recognition_history_repository.dart';
import 'package:hellovietnam/features/ai_search/domain/ai_recognition_result.dart';
import 'package:hellovietnam/features/ai_search/presentation/ai_search_page.dart';

void main() {
  testWidgets('restoring a sign result does not request location', (
    WidgetTester tester,
  ) async {
    final _FakeMapCoordinator maps = _FakeMapCoordinator();

    await tester.pumpWidget(
      MaterialApp(
        home: AiSearchPage(
          initialHistoryEntry: _signHistoryEntry(),
          mapCoordinator: maps,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-result-sign-text')), findsOneWidget);
    expect(maps.prepareCalls, 0);
  });

  testWidgets('map tap prepares location exactly once', (
    WidgetTester tester,
  ) async {
    final _FakeMapCoordinator maps = _FakeMapCoordinator.ready();

    await tester.pumpWidget(
      MaterialApp(
        home: AiSearchPage(
          initialHistoryEntry: _signHistoryEntry(),
          mapCoordinator: maps,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-sign-map-button')));
    await tester.pumpAndSettle();

    expect(maps.prepareCalls, 1);
    expect(maps.launchCalls, 1);
  });

  testWidgets('copy and listen actions run only after taps', (
    WidgetTester tester,
  ) async {
    final List<String> copied = <String>[];
    final List<String> spoken = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AiSearchPage(
          initialHistoryEntry: _signHistoryEntry(),
          onCopyText: (String text) async => copied.add(text),
          onSpeakText: (String text) async => spoken.add(text),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(copied, isEmpty);
    expect(spoken, isEmpty);
    await tester.tap(find.byKey(const Key('ai-sign-copy-original-button')));
    await tester.tap(find.byKey(const Key('ai-sign-listen-button')));
    await tester.pumpAndSettle();

    expect(copied.single, 'DUONG NGUYEN HUE');
    expect(spoken.single, 'DUONG NGUYEN HUE');
  });

  testWidgets('location settings fallback can continue with text search', (
    WidgetTester tester,
  ) async {
    final _FakeMapCoordinator maps = _FakeMapCoordinator(
      preparation: const AiRecognitionMapNeedsSettings(
        AiRecognitionMapSettingsTarget.location,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AiSearchPage(
          initialHistoryEntry: _signHistoryEntry(),
          mapCoordinator: maps,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-sign-map-button')));
    await tester.pumpAndSettle();
    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Continue Without Location'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Continue Without Location'));
    await tester.pumpAndSettle();
    expect(maps.launchCalls, 1);
  });
}

class _FakeMapCoordinator implements AiRecognitionMapCoordinator {
  _FakeMapCoordinator({
    this.preparation = const AiRecognitionMapWithoutOrigin('test'),
  });

  _FakeMapCoordinator.ready()
    : preparation = const AiRecognitionMapReady((
        latitude: 10.7769,
        longitude: 106.7009,
      ));

  final AiRecognitionMapPreparation preparation;
  int prepareCalls = 0;
  int launchCalls = 0;

  @override
  Future<AiRecognitionMapPreparation> prepare() async {
    prepareCalls += 1;
    return preparation;
  }

  @override
  Future<bool> launch(String query, {AiRecognitionMapOrigin? origin}) async {
    launchCalls += 1;
    return true;
  }

  @override
  Future<bool> openSettings(AiRecognitionMapSettingsTarget target) async =>
      true;
}

AiRecognitionHistoryEntry _signHistoryEntry() {
  return AiRecognitionHistoryEntry(
    id: 'sign-1',
    createdAt: DateTime.utc(2026, 7, 23),
    thumbnailBytes: Uint8List.fromList(_transparentPixel),
    result: const AiSearchResult(
      kind: AiRecognitionKind.signText,
      confidence: 0.91,
      detectedName: 'DUONG NGUYEN HUE',
      subtitle: 'Vietnamese street sign',
      summary: 'A street name.',
      locationHint: 'Ho Chi Minh City',
      categoryText: 'Street sign',
      primaryTags: <String>[],
      secondaryTags: <String>[],
      bestTime: '',
      note: '',
      culturalSignificance: '',
      usageBullets: <String>[],
      productionMethod: '',
      alternativeNames: '',
      priceRange: '',
      suggestedPlaces: <String>[],
      mapQuery: 'Nguyen Hue Street, Vietnam',
      canOpenMap: true,
      textAnalysis: AiRecognitionTextAnalysis(
        originalText: 'DUONG NGUYEN HUE',
        detectedLanguageCode: 'vi',
        detectedLanguageName: 'Vietnamese',
        translatedText: 'Nguyen Hue Street',
        targetLanguageCode: 'en',
        signType: 'street',
        travelContext: 'A street name.',
        mapQuery: 'Nguyen Hue Street, Vietnam',
        canOpenMap: true,
      ),
    ),
  );
}

const List<int> _transparentPixel = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  8,
  215,
  99,
  248,
  207,
  192,
  240,
  31,
  0,
  5,
  0,
  1,
  255,
  137,
  153,
  61,
  29,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
