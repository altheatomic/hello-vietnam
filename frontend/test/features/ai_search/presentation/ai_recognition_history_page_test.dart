import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_search/data/ai_recognition_history_repository.dart';
import 'package:hellovietnam/features/ai_search/data/ai_search_service.dart';
import 'package:hellovietnam/features/ai_search/domain/ai_recognition_result.dart';
import 'package:hellovietnam/features/ai_search/presentation/ai_recognition_history_page.dart';

void main() {
  late Uint8List thumbnailBytes;

  setUpAll(() async {
    thumbnailBytes = await _createTestImage();
  });

  testWidgets('shows an empty state when recognition history is empty', (
    WidgetTester tester,
  ) async {
    final _FakeHistoryStore store = _FakeHistoryStore();

    await tester.pumpWidget(
      MaterialApp(home: AiRecognitionHistoryPage(historyStore: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No recognition history yet'), findsOneWidget);
  });

  testWidgets('shows saved recognition details', (WidgetTester tester) async {
    final _FakeHistoryStore store = _FakeHistoryStore(
      <AiRecognitionHistoryEntry>[_entry(thumbnailBytes)],
    );

    await tester.pumpWidget(
      MaterialApp(home: AiRecognitionHistoryPage(historyStore: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bun bo Hue'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('93% match'), findsOneWidget);
    expect(find.text('Linked to database'), findsOneWidget);
  });

  testWidgets('opens the full recognition result when an entry is tapped', (
    WidgetTester tester,
  ) async {
    final AiRecognitionHistoryEntry entry = _entry(thumbnailBytes);
    final _FakeHistoryStore store = _FakeHistoryStore(
      <AiRecognitionHistoryEntry>[entry],
    );
    AiRecognitionHistoryEntry? openedEntry;

    await tester.pumpWidget(
      MaterialApp(
        home: AiRecognitionHistoryPage(
          historyStore: store,
          onOpenEntry: (AiRecognitionHistoryEntry value) {
            openedEntry = value;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bun bo Hue'));
    await tester.pump();

    expect(openedEntry, same(entry));
  });

  testWidgets('deletes only the confirmed recognition entry', (
    WidgetTester tester,
  ) async {
    final _FakeHistoryStore store = _FakeHistoryStore(
      <AiRecognitionHistoryEntry>[_entry(thumbnailBytes)],
    );

    await tester.pumpWidget(
      MaterialApp(home: AiRecognitionHistoryPage(historyStore: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-history-delete-entry-1')));
    await tester.pumpAndSettle();
    expect(find.text('Delete recognition?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.entries, isEmpty);
    expect(find.text('Bun bo Hue'), findsNothing);
    expect(find.text('No recognition history yet'), findsOneWidget);
  });
}

class _FakeHistoryStore implements AiRecognitionHistoryStore {
  _FakeHistoryStore([List<AiRecognitionHistoryEntry>? initialEntries])
    : entries = initialEntries ?? <AiRecognitionHistoryEntry>[];

  final List<AiRecognitionHistoryEntry> entries;

  @override
  Future<void> delete(String id) async {
    entries.removeWhere((AiRecognitionHistoryEntry entry) => entry.id == id);
  }

  @override
  Future<List<AiRecognitionHistoryEntry>> load() async {
    return List<AiRecognitionHistoryEntry>.unmodifiable(entries);
  }

  @override
  Future<AiRecognitionHistoryEntry> save({
    required AiSearchResult result,
    required Uint8List imageBytes,
  }) {
    throw UnimplementedError();
  }
}

AiRecognitionHistoryEntry _entry(Uint8List thumbnailBytes) {
  return AiRecognitionHistoryEntry(
    id: 'entry-1',
    createdAt: DateTime.utc(2026, 7, 23, 8, 30),
    thumbnailBytes: thumbnailBytes,
    result: const AiSearchResult(
      kind: AiRecognitionKind.food,
      confidence: 0.93,
      detectedName: 'Bun bo Hue',
      subtitle: 'Vietnamese dish',
      summary: 'Recognition summary',
      locationHint: 'Hue',
      categoryText: 'Food',
      primaryTags: <String>['Noodles'],
      secondaryTags: <String>['Savory'],
      bestTime: 'Lunch',
      note: 'Serve hot',
      culturalSignificance: 'Traditional dish',
      usageBullets: <String>[],
      productionMethod: '',
      alternativeNames: '',
      priceRange: '',
      suggestedPlaces: <String>['Hue'],
      databaseMatch: AiSearchDatabaseMatch(
        category: 'food',
        id: 'food-1',
        name: 'Bun bo Hue',
        matchScore: 0.97,
      ),
    ),
  );
}

Future<Uint8List> _createTestImage() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF29B6F6),
  );
  final ui.Image image = await recorder.endRecording().toImage(4, 4);
  try {
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}
