import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_search/data/ai_recognition_history_repository.dart';
import 'package:hellovietnam/features/ai_search/data/ai_search_service.dart';
import 'package:hellovietnam/features/ai_search/domain/ai_recognition_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Uint8List imageBytes;

  setUpAll(() async {
    imageBytes = await _createTestImage();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saves and loads a recognition with a thumbnail', () async {
    final AiRecognitionHistoryRepository repository =
        AiRecognitionHistoryRepository(userId: 'user-1');

    final AiRecognitionHistoryEntry saved = await repository.save(
      result: _result('Bun bo Hue'),
      imageBytes: imageBytes,
    );
    final List<AiRecognitionHistoryEntry> entries = await repository.load();

    expect(entries, hasLength(1));
    expect(entries.single.id, saved.id);
    expect(entries.single.result.detectedName, 'Bun bo Hue');
    expect(entries.single.thumbnailBytes, isNotEmpty);
    expect(entries.single.result.databaseMatch?.id, 'food-1');
  });

  test('persists history across repository instances', () async {
    final AiRecognitionHistoryRepository firstRepository =
        AiRecognitionHistoryRepository(userId: 'user-1');
    await firstRepository.save(
      result: _result('Persistent result'),
      imageBytes: imageBytes,
    );

    final AiRecognitionHistoryRepository restartedRepository =
        AiRecognitionHistoryRepository(userId: 'user-1');
    final List<AiRecognitionHistoryEntry> entries = await restartedRepository
        .load();

    expect(entries, hasLength(1));
    expect(entries.single.result.detectedName, 'Persistent result');
  });

  test('keeps recognition history separate for each user', () async {
    final AiRecognitionHistoryRepository firstUserRepository =
        AiRecognitionHistoryRepository(userId: 'user-1');
    final AiRecognitionHistoryRepository secondUserRepository =
        AiRecognitionHistoryRepository(userId: 'user-2');

    await firstUserRepository.save(
      result: _result('First user result'),
      imageBytes: imageBytes,
    );

    expect(await secondUserRepository.load(), isEmpty);
  });

  test('keeps the newest 30 recognition entries', () async {
    final AiRecognitionHistoryRepository repository =
        AiRecognitionHistoryRepository(userId: 'user-1');

    for (int index = 0; index < 31; index++) {
      await repository.save(
        result: _result('Result $index'),
        imageBytes: imageBytes,
      );
    }

    final List<AiRecognitionHistoryEntry> entries = await repository.load();
    expect(entries, hasLength(30));
    expect(entries.first.result.detectedName, 'Result 30');
    expect(entries.last.result.detectedName, 'Result 1');
  });

  test('ignores malformed stored entries', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AiRecognitionHistoryRepository.storageKeyForUser('user-1'): jsonEncode(
        <Object?>[
          'invalid-entry',
          <String, Object?>{'id': 'missing-fields', 'created_at': 'not-a-date'},
        ],
      ),
    });
    final AiRecognitionHistoryRepository repository =
        AiRecognitionHistoryRepository(userId: 'user-1');

    expect(await repository.load(), isEmpty);
  });

  test('deletes only the requested recognition entry', () async {
    final AiRecognitionHistoryRepository repository =
        AiRecognitionHistoryRepository(userId: 'user-1');
    final AiRecognitionHistoryEntry first = await repository.save(
      result: _result('First'),
      imageBytes: imageBytes,
    );
    final AiRecognitionHistoryEntry second = await repository.save(
      result: _result('Second'),
      imageBytes: imageBytes,
    );

    await repository.delete(second.id);

    final List<AiRecognitionHistoryEntry> entries = await repository.load();
    expect(entries.map((AiRecognitionHistoryEntry item) => item.id), <String>[
      first.id,
    ]);
  });
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

AiSearchResult _result(String name) {
  return AiSearchResult(
    kind: AiRecognitionKind.food,
    confidence: 0.93,
    detectedName: name,
    subtitle: 'Vietnamese dish',
    summary: 'Recognition summary',
    locationHint: 'Vietnam',
    categoryText: 'Food',
    primaryTags: const <String>['Noodles'],
    secondaryTags: const <String>['Savory'],
    bestTime: 'Lunch',
    note: 'Serve hot',
    culturalSignificance: 'Traditional dish',
    usageBullets: const <String>[],
    productionMethod: '',
    alternativeNames: '',
    priceRange: '',
    suggestedPlaces: const <String>['Hue'],
    databaseMatch: const AiSearchDatabaseMatch(
      category: 'food',
      id: 'food-1',
      name: 'Bun bo Hue',
      matchScore: 0.97,
    ),
  );
}
