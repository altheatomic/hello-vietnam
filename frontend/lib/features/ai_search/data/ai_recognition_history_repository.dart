import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_search_service.dart';

abstract interface class AiRecognitionHistoryStore {
  Future<List<AiRecognitionHistoryEntry>> load();

  Future<AiRecognitionHistoryEntry> save({
    required AiSearchResult result,
    required Uint8List imageBytes,
  });

  Future<void> delete(String id);
}

class AiRecognitionHistoryEntry {
  const AiRecognitionHistoryEntry({
    required this.id,
    required this.createdAt,
    required this.thumbnailBytes,
    required this.result,
  });

  final String id;
  final DateTime createdAt;
  final Uint8List thumbnailBytes;
  final AiSearchResult result;

  factory AiRecognitionHistoryEntry.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] as String? ?? '').trim();
    final DateTime? createdAt = DateTime.tryParse(
      (json['created_at'] as String? ?? '').trim(),
    );
    final String thumbnail = (json['thumbnail_base64'] as String? ?? '').trim();
    final Object? resultJson = json['result'];

    if (id.isEmpty ||
        createdAt == null ||
        thumbnail.isEmpty ||
        resultJson is! Map) {
      throw const FormatException('Invalid AI recognition history entry.');
    }

    final Uint8List thumbnailBytes = base64Decode(thumbnail);
    if (thumbnailBytes.isEmpty) {
      throw const FormatException('AI recognition thumbnail is empty.');
    }

    return AiRecognitionHistoryEntry(
      id: id,
      createdAt: createdAt.toUtc(),
      thumbnailBytes: thumbnailBytes,
      result: AiSearchResult.fromJson(Map<String, dynamic>.from(resultJson)),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'created_at': createdAt.toUtc().toIso8601String(),
    'thumbnail_base64': base64Encode(thumbnailBytes),
    'result': result.toJson(),
  };
}

class AiRecognitionHistoryRepository implements AiRecognitionHistoryStore {
  AiRecognitionHistoryRepository({String? userId}) : _userId = userId;

  static const int maxEntries = 30;
  static const int _thumbnailWidth = 240;
  static const int _maxStoredJsonLength = 4 * 1024 * 1024;
  static const String _storagePrefix = 'ai_recognition_history_v1_';

  final String? _userId;
  final Random _random = Random.secure();

  static String storageKeyForUser(String? userId) {
    final String normalized = userId?.trim() ?? '';
    return '$_storagePrefix${normalized.isEmpty ? 'anonymous' : normalized}';
  }

  @override
  Future<List<AiRecognitionHistoryEntry>> load() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? raw = preferences.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <AiRecognitionHistoryEntry>[];
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <AiRecognitionHistoryEntry>[];

      final List<AiRecognitionHistoryEntry> entries =
          <AiRecognitionHistoryEntry>[];
      for (final Object? value in decoded) {
        if (value is! Map) continue;
        try {
          entries.add(
            AiRecognitionHistoryEntry.fromJson(
              Map<String, dynamic>.from(value),
            ),
          );
        } catch (_) {
          // A single corrupted record should not hide the remaining history.
        }
      }
      entries.sort(
        (AiRecognitionHistoryEntry left, AiRecognitionHistoryEntry right) =>
            right.createdAt.compareTo(left.createdAt),
      );
      return entries.take(maxEntries).toList(growable: false);
    } catch (_) {
      return <AiRecognitionHistoryEntry>[];
    }
  }

  @override
  Future<AiRecognitionHistoryEntry> save({
    required AiSearchResult result,
    required Uint8List imageBytes,
  }) async {
    if (imageBytes.isEmpty) {
      throw const FormatException('Cannot save an empty recognition image.');
    }

    final Uint8List thumbnail = await _createThumbnail(imageBytes);
    final DateTime now = DateTime.now().toUtc();
    final AiRecognitionHistoryEntry entry = AiRecognitionHistoryEntry(
      id:
          '${now.microsecondsSinceEpoch}-'
          '${_random.nextInt(0x7fffffff).toRadixString(16)}',
      createdAt: now,
      thumbnailBytes: thumbnail,
      result: result,
    );

    final List<AiRecognitionHistoryEntry> entries = await load();
    await _persist(<AiRecognitionHistoryEntry>[
      entry,
      ...entries.where((AiRecognitionHistoryEntry item) => item.id != entry.id),
    ]);
    return entry;
  }

  @override
  Future<void> delete(String id) async {
    final String normalized = id.trim();
    if (normalized.isEmpty) return;
    final List<AiRecognitionHistoryEntry> entries = await load();
    await _persist(
      entries
          .where((AiRecognitionHistoryEntry item) => item.id != normalized)
          .toList(growable: false),
    );
  }

  String get _storageKey => storageKeyForUser(_userId ?? _currentUserId());

  String? _currentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist(List<AiRecognitionHistoryEntry> entries) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<AiRecognitionHistoryEntry> retained = entries
        .take(maxEntries)
        .toList();

    String encoded = _encode(retained);
    while (retained.length > 1 && encoded.length > _maxStoredJsonLength) {
      retained.removeLast();
      encoded = _encode(retained);
    }

    final bool saved = await preferences.setString(_storageKey, encoded);
    if (!saved) {
      throw StateError('Could not persist AI recognition history.');
    }
  }

  String _encode(List<AiRecognitionHistoryEntry> entries) {
    return jsonEncode(
      entries
          .map((AiRecognitionHistoryEntry item) => item.toJson())
          .toList(growable: false),
    );
  }

  Future<Uint8List> _createThumbnail(Uint8List sourceBytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(
      sourceBytes,
      targetWidth: _thumbnailWidth,
      allowUpscaling: false,
    );
    try {
      final ui.FrameInfo frame = await codec.getNextFrame();
      try {
        final ByteData? byteData = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData == null) {
          throw StateError('Could not encode AI recognition thumbnail.');
        }
        return byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}
