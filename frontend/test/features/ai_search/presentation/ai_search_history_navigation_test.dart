import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_search/data/ai_recognition_history_repository.dart';
import 'package:hellovietnam/features/ai_search/data/ai_search_service.dart';
import 'package:hellovietnam/features/ai_search/presentation/ai_search_page.dart';

void main() {
  testWidgets('AI Recognition exposes a history button', (
    WidgetTester tester,
  ) async {
    bool openedHistory = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AiSearchPage(
          onOpenHistory: () {
            openedHistory = true;
          },
        ),
      ),
    );

    final Finder historyButton = find.byKey(
      const Key('ai-search-history-button'),
    );
    expect(historyButton, findsOneWidget);

    await tester.tap(historyButton);
    await tester.pump();

    expect(openedHistory, isTrue);
  });

  testWidgets('AI Recognition restores a saved result from history', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AiSearchPage(
          initialHistoryEntry: AiRecognitionHistoryEntry(
            id: 'history-1',
            createdAt: DateTime.utc(2026, 7, 23),
            thumbnailBytes: Uint8List.fromList(_transparentPixel),
            result: const AiSearchResult(
              resultType: 'food',
              confidence: 0.94,
              detectedName: 'History Bun Bo Hue',
              subtitle: 'Vietnamese noodle soup',
              summary: 'Saved recognition result',
              locationHint: 'Hue',
              categoryText: 'Food',
              primaryTags: <String>['Noodles'],
              secondaryTags: <String>['Spicy'],
              bestTime: 'Breakfast',
              note: 'Serve hot',
              culturalSignificance: 'Hue cuisine',
              usageBullets: <String>[],
              productionMethod: '',
              alternativeNames: '',
              priceRange: '',
              suggestedPlaces: <String>['Hue'],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('History Bun Bo Hue'), findsOneWidget);
    expect(find.text('Saved recognition result'), findsOneWidget);
  });
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
