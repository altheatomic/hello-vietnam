import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/local_storage.dart' as app_storage;

typedef ReferenceRecord = Map<String, dynamic>;

class ReferenceDataCacheRepository {
  ReferenceDataCacheRepository._();

  static final ReferenceDataCacheRepository instance =
      ReferenceDataCacheRepository._();

  static const Duration _cacheTtl = Duration(days: 7);
  static const String _storageKeyPrefix = 'reference_cache_v1_';
  static const String _storageTimeSuffix = '_fetched_at';

  final SupabaseClient _client = Supabase.instance.client;

  bool _isReady = false;

  Future<void> initialize() async {
    if (_isReady) return;
    await app_storage.LocalStorage.instance.initialize();
    _isReady = true;
  }

  Future<List<ReferenceRecord>> getZones({bool forceRefresh = false}) {
    return _getTableRecords('zone', forceRefresh: forceRefresh);
  }

  Future<List<ReferenceRecord>> getRegions({bool forceRefresh = false}) {
    return _getTableRecords('region', forceRefresh: forceRefresh);
  }

  Future<List<ReferenceRecord>> getProvinces({bool forceRefresh = false}) {
    return _getTableRecords('province', forceRefresh: forceRefresh);
  }

  Future<void> warmUp() async {
    await initialize();
    await Future.wait(<Future<List<ReferenceRecord>>>[
      getZones(),
      getRegions(),
      getProvinces(),
    ]);
  }

  Future<void> refreshStaleInBackground() async {
    await initialize();
    unawaited(_refreshIfStale('zone'));
    unawaited(_refreshIfStale('region'));
    unawaited(_refreshIfStale('province'));
  }

  Future<void> clearAll() async {
    await initialize();
    await Future.wait(<Future<bool>>[
      app_storage.LocalStorage.instance.remove(_storageKeyFor('zone')),
      app_storage.LocalStorage.instance.remove(_storageTimestampKeyFor('zone')),
      app_storage.LocalStorage.instance.remove(_storageKeyFor('region')),
      app_storage.LocalStorage.instance.remove(
        _storageTimestampKeyFor('region'),
      ),
      app_storage.LocalStorage.instance.remove(_storageKeyFor('province')),
      app_storage.LocalStorage.instance.remove(
        _storageTimestampKeyFor('province'),
      ),
    ]);
  }

  Future<List<ReferenceRecord>> _getTableRecords(
    String table, {
    required bool forceRefresh,
  }) async {
    await initialize();

    if (!forceRefresh) {
      final List<ReferenceRecord>? cachedRecords = _readCachedRecords(table);
      if (cachedRecords != null && cachedRecords.isNotEmpty) {
        if (_isCacheStale(table)) {
          unawaited(_refreshIfStale(table));
        }
        return cachedRecords;
      }
    }

    return _fetchAndCache(table);
  }

  Future<void> _refreshIfStale(String table) async {
    if (!_isCacheStale(table)) return;
    try {
      await _fetchAndCache(table);
    } catch (error, stackTrace) {
      debugPrint('Reference cache refresh failed for $table: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<List<ReferenceRecord>> _fetchAndCache(String table) async {
    final List<dynamic> response = await _client.from(table).select();
    final List<ReferenceRecord> records = response
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
        .toList();

    _sortRecordsInPlace(records);

    await app_storage.LocalStorage.instance.setString(
      _storageKeyFor(table),
      jsonEncode(records),
    );
    await app_storage.LocalStorage.instance.setString(
      _storageTimestampKeyFor(table),
      DateTime.now().toUtc().toIso8601String(),
    );

    return records;
  }

  List<ReferenceRecord>? _readCachedRecords(String table) {
    final String? raw = app_storage.LocalStorage.instance.getString(
      _storageKeyFor(table),
    );
    if (raw == null || raw.isEmpty) return null;

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return null;

      return decoded
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> entry) => entry.map(
              (dynamic key, dynamic value) =>
                  MapEntry(key.toString(), value),
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  bool _isCacheStale(String table) {
    final String? rawTimestamp = app_storage.LocalStorage.instance.getString(
      _storageTimestampKeyFor(table),
    );
    if (rawTimestamp == null || rawTimestamp.isEmpty) return true;

    final DateTime? fetchedAt = DateTime.tryParse(rawTimestamp);
    if (fetchedAt == null) return true;

    return DateTime.now().toUtc().difference(fetchedAt) > _cacheTtl;
  }

  void _sortRecordsInPlace(List<ReferenceRecord> records) {
    String sortValue(ReferenceRecord record) {
      for (final String key in <String>['name', 'province_name', 'region_name', 'zone_name']) {
        final Object? value = record[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim().toLowerCase();
        }
      }
      return '';
    }

    records.sort((ReferenceRecord a, ReferenceRecord b) {
      return sortValue(a).compareTo(sortValue(b));
    });
  }

  String _storageKeyFor(String table) => '$_storageKeyPrefix$table';

  String _storageTimestampKeyFor(String table) =>
      '${_storageKeyFor(table)}$_storageTimeSuffix';
}
