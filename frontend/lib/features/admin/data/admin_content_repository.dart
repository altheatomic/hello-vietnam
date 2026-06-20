import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_content.dart';

class AdminPagedResult<T> {
  const AdminPagedResult({required this.items, required this.totalCount});

  final List<T> items;
  final int totalCount;
}

class AdminContentRepository {
  AdminContentRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<AdminPagedResult<AdminContentRecord>> fetchPage(
    AdminContentResourceConfig config, {
    required int page,
    required int pageSize,
    String query = '',
  }) async {
    final start = (page - 1) * pageSize;
    final end = start + pageSize - 1;
    final searchableColumns = config.fields
        .where(
          (field) =>
              field.type == AdminContentFieldType.text ||
              field.type == AdminContentFieldType.multiline ||
              field.type == AdminContentFieldType.imageUrl ||
              field.type == AdminContentFieldType.status,
        )
        .map((field) => field.key)
        .toSet()
        .toList(growable: false);

    dynamic filter = _client.from(config.table).select();

    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty && searchableColumns.isNotEmpty) {
      final escaped = trimmedQuery
          .replaceAll('%', r'\%')
          .replaceAll(',', r'\,');
      filter = filter.or(
        searchableColumns.map((column) => '$column.ilike.%$escaped%').join(','),
      );
    }

    final dynamic request = filter
        .order(config.orderColumn, ascending: config.orderAscending)
        .range(start, end)
        .count(CountOption.exact);

    final dynamic response = await request;
    final rows = (response.data as List<dynamic>? ?? <dynamic>[]);
    final records = rows
        .map((row) => _recordFromRow(Map<String, dynamic>.from(row), config))
        .toList(growable: false);
    return AdminPagedResult<AdminContentRecord>(
      items: records,
      totalCount: (response.count as int?) ?? records.length,
    );
  }

  Future<AdminContentRecord> create(
    AdminContentResourceConfig config,
    Map<String, dynamic> values,
  ) async {
    final payload = _payloadFor(config, values);
    final response = await _client
        .from(config.table)
        .insert(payload)
        .select()
        .single();
    return _recordFromRow(Map<String, dynamic>.from(response), config);
  }

  Future<AdminContentRecord> update(
    AdminContentResourceConfig config,
    AdminContentRecord record,
    Map<String, dynamic> values,
  ) async {
    final payload = _payloadFor(config, values, existingRecord: record);
    final response = await _client
        .from(config.table)
        .update(payload)
        .eq(record.idColumn, record.id)
        .select()
        .single();
    return _recordFromRow(Map<String, dynamic>.from(response), config);
  }

  Future<void> delete(
    AdminContentResourceConfig config,
    AdminContentRecord record,
  ) async {
    await _client.from(config.table).delete().eq(record.idColumn, record.id);
  }

  AdminContentRecord _recordFromRow(
    Map<String, dynamic> row,
    AdminContentResourceConfig config,
  ) {
    final idColumn = _resolveIdColumn(row, config);
    return AdminContentRecord(
      id: row[idColumn]?.toString() ?? '',
      idColumn: idColumn,
      values: Map<String, dynamic>.from(row),
    );
  }

  String _resolveIdColumn(
    Map<String, dynamic> row,
    AdminContentResourceConfig config,
  ) {
    final candidates = <String>{config.idColumn, ...config.idColumnCandidates};
    for (final candidate in candidates) {
      final value = row[candidate];
      if (value != null && value.toString().trim().isNotEmpty) {
        return candidate;
      }
    }
    return config.idColumn;
  }

  Map<String, dynamic> _payloadFor(
    AdminContentResourceConfig config,
    Map<String, dynamic> values, {
    AdminContentRecord? existingRecord,
  }) {
    final payload = <String, dynamic>{};
    for (final field in config.fields) {
      if (existingRecord != null &&
          !existingRecord.values.containsKey(field.key)) {
        continue;
      }
      final value = values[field.key];
      payload[field.key] = _normalizeValue(value, field);
    }
    return payload;
  }

  Object? _normalizeValue(Object? value, AdminContentFieldConfig field) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    if (field.type == AdminContentFieldType.number) {
      if (value is num) return value;
      return num.tryParse(text);
    }
    if (field.type == AdminContentFieldType.integer) {
      if (value is int) return value;
      return int.tryParse(text);
    }
    if (field.type == AdminContentFieldType.json) {
      return jsonDecode(text);
    }
    return text.isEmpty ? null : text;
  }
}
