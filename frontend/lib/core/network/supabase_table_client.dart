import 'dart:async';

typedef SupabaseTableRequest = Future<Object?> Function();

class SupabaseTableException implements Exception {
  const SupabaseTableException(this.message, {this.details});

  final String message;
  final Object? details;

  @override
  String toString() => message;
}

class SupabaseTableRange {
  const SupabaseTableRange({required this.from, required this.to});

  final int from;
  final int to;
}

class SupabasePagedRows {
  const SupabasePagedRows({required this.rows, required this.totalCount});

  final List<Map<String, dynamic>> rows;
  final int? totalCount;
}

class SupabaseTableClient {
  const SupabaseTableClient({
    this.defaultTimeout = const Duration(seconds: 20),
  });

  final Duration defaultTimeout;

  Future<T> run<T>(
    String label,
    Future<T> Function() request, {
    Duration? timeout,
  }) async {
    try {
      return await request().timeout(timeout ?? defaultTimeout);
    } on TimeoutException {
      throw SupabaseTableException('$label timed out. Please try again.');
    } on SupabaseTableException {
      rethrow;
    } catch (error) {
      throw SupabaseTableException('Failed to load $label.', details: error);
    }
  }

  Future<List<Map<String, dynamic>>> list(
    String label,
    SupabaseTableRequest request, {
    Duration? timeout,
  }) async {
    final Object? raw = await run(label, request, timeout: timeout);
    if (raw == null) return const <Map<String, dynamic>>[];
    if (raw is! List) {
      throw SupabaseTableException('Unexpected $label response.', details: raw);
    }
    return raw.map(_asMap).toList(growable: false);
  }

  Future<SupabasePagedRows> pagedRows(
    String label,
    SupabaseTableRequest request, {
    Duration? timeout,
  }) async {
    final Object? raw = await run(label, request, timeout: timeout);
    final List<dynamic> rows = _readRows(label, raw);
    return SupabasePagedRows(
      rows: rows.map(_asMap).toList(growable: false),
      totalCount: _readCount(raw),
    );
  }

  Future<Map<String, dynamic>?> maybeSingle(
    String label,
    SupabaseTableRequest request, {
    Duration? timeout,
  }) async {
    final Object? raw = await run(label, request, timeout: timeout);
    if (raw == null) return null;
    return _asMap(raw);
  }

  Future<Map<String, dynamic>> single(
    String label,
    SupabaseTableRequest request, {
    Duration? timeout,
  }) async {
    final Map<String, dynamic>? row = await maybeSingle(
      label,
      request,
      timeout: timeout,
    );
    if (row == null) {
      throw SupabaseTableException('$label was not found.');
    }
    return row;
  }

  static SupabaseTableRange rangeForPage({
    required int page,
    required int pageSize,
  }) {
    final int safePage = page < 1 ? 1 : page;
    final int safePageSize = pageSize < 1 ? 1 : pageSize;
    final int from = (safePage - 1) * safePageSize;
    return SupabaseTableRange(from: from, to: from + safePageSize - 1);
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    }
    throw SupabaseTableException(
      'Unexpected table row response.',
      details: raw,
    );
  }

  List<dynamic> _readRows(String label, Object? raw) {
    if (raw == null) return const <dynamic>[];
    if (raw is List) return raw;

    try {
      final dynamic data = (raw as dynamic).data;
      if (data == null) return const <dynamic>[];
      if (data is List) return data;
    } catch (_) {
      // Fall through to the uniform exception below.
    }

    throw SupabaseTableException('Unexpected $label response.', details: raw);
  }

  int? _readCount(Object? raw) {
    try {
      final dynamic count = (raw as dynamic).count;
      if (count is num) return count.toInt();
    } catch (_) {
      return null;
    }
    return null;
  }
}
