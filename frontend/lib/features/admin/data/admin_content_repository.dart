import 'dart:convert';

import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_content.dart';

class AdminPagedResult<T> {
  const AdminPagedResult({required this.items, required this.totalCount});

  final List<T> items;
  final int totalCount;
}

class AdminContentRepository {
  AdminContentRepository({
    SupabaseClient? client,
    SupabaseTableClient? tableClient,
  }) : _clientOverride = client,
       _tableClient = tableClient;

  final SupabaseClient? _clientOverride;
  final SupabaseTableClient? _tableClient;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  SupabaseTableClient get _resolvedTableClient =>
      _tableClient ?? const SupabaseTableClient();

  Future<AdminPagedResult<AdminContentRecord>> fetchPage(
    AdminContentResourceConfig config, {
    required int page,
    required int pageSize,
    String query = '',
  }) async {
    final range = SupabaseTableClient.rangeForPage(
      page: page,
      pageSize: pageSize,
    );
    final searchableColumns = config.fields
        .where(
          (field) =>
              field.visibleInTable &&
              (field.type == AdminContentFieldType.text ||
                  field.type == AdminContentFieldType.multiline ||
                  field.type == AdminContentFieldType.imageUrl ||
                  field.type == AdminContentFieldType.status),
        )
        .map((field) => field.key)
        .toSet()
        .toList(growable: false);

    dynamic filter = _client
        .from(config.table)
        .select(listSelectColumnsFor(config));

    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty && searchableColumns.isNotEmpty) {
      final escaped = trimmedQuery
          .replaceAll('%', r'\%')
          .replaceAll(',', r'\,');
      final searchParts = searchableColumns
          .map((column) => '$column.ilike.%$escaped%')
          .toList(growable: true);
      if (_looksLikeUuid(trimmedQuery)) {
        searchParts.add('${config.idColumn}.eq.$trimmedQuery');
      }
      filter = filter.or(searchParts.join(','));
    }

    final SupabasePagedRows pageRows = await _resolvedTableClient.pagedRows(
      '${config.table} page',
      () async {
        return filter
            .order(config.orderColumn, ascending: config.orderAscending)
            .range(range.from, range.to)
            .count(CountOption.exact);
      },
    );
    final records = pageRows.rows
        .map((row) => _recordFromRow(row, config))
        .toList(growable: false);
    return AdminPagedResult<AdminContentRecord>(
      items: records,
      totalCount: pageRows.totalCount ?? records.length,
    );
  }

  Future<AdminContentRecord> fetchRecord(
    AdminContentResourceConfig config,
    AdminContentRecord record,
  ) async {
    final row = await _resolvedTableClient.single(
      '${config.table} detail',
      () async {
        return _client
            .from(config.table)
            .select(detailSelectColumnsFor(config))
            .eq(record.idColumn, record.id)
            .single();
      },
    );
    return _recordFromRow(row, config);
  }

  String listSelectColumnsFor(AdminContentResourceConfig config) {
    return _joinColumns(<String>[
      config.idColumn,
      config.orderColumn,
      for (final field in config.fields.where((field) => field.visibleInTable))
        field.key,
    ]);
  }

  String detailSelectColumnsFor(AdminContentResourceConfig config) {
    return _joinColumns(<String>[
      config.idColumn,
      config.orderColumn,
      for (final field in config.fields) field.key,
    ]);
  }

  String _joinColumns(Iterable<String> columns) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final column in columns) {
      final trimmed = column.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      normalized.add(trimmed);
    }
    return normalized.join(', ');
  }

  bool _looksLikeUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);

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
    // Freshness-managed records are never hard-deleted. Province rows are
    // structural lookup data and currently have no lifecycle column, so keep
    // their existing delete behaviour until that schema is migrated too.
    if (config.fields.any((field) => field.key == 'status')) {
      await archive(config, record);
      return;
    }
    await _client.from(config.table).delete().eq(record.idColumn, record.id);
  }

  Future<void> archive(
    AdminContentResourceConfig config,
    AdminContentRecord record,
  ) async {
    await _client
        .from(config.table)
        .update(<String, dynamic>{'status': 'archived'})
        .eq(record.idColumn, record.id);
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
