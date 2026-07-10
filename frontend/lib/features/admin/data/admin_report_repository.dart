import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReportRecord {
  const AdminReportRecord({
    required this.id,
    required this.reporterName,
    required this.reporterEmail,
    required this.reportCategory,
    required this.issueType,
    required this.targetType,
    required this.targetId,
    required this.featureArea,
    required this.content,
    required this.images,
    required this.status,
    required this.actionTaken,
    required this.createdAt,
  });

  final String id;
  final String reporterName;
  final String reporterEmail;
  final String reportCategory;
  final String issueType;
  final String? targetType;
  final String? targetId;
  final String? featureArea;
  final String content;
  final List<String> images;
  final String status;
  final String? actionTaken;
  final DateTime createdAt;
}

class AdminReportPageResult {
  const AdminReportPageResult({
    required this.records,
    required this.totalCount,
    required this.statusCounts,
  });

  final List<AdminReportRecord> records;
  final int totalCount;
  final AdminReportStatusCounts statusCounts;
}

class AdminReportStatusCounts {
  const AdminReportStatusCounts({
    required this.pending,
    required this.reviewing,
    required this.resolved,
    required this.rejected,
  });

  const AdminReportStatusCounts.zero()
    : pending = 0,
      reviewing = 0,
      resolved = 0,
      rejected = 0;

  final int pending;
  final int reviewing;
  final int resolved;
  final int rejected;

  int get total => pending + reviewing + resolved + rejected;
}

class AdminReportRepository {
  AdminReportRepository({
    SupabaseClient? client,
    SupabaseTableClient? tableClient,
  }) : _clientOverride = client,
       _tableClient = tableClient;

  final SupabaseClient? _clientOverride;
  final SupabaseTableClient? _tableClient;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  SupabaseTableClient get _resolvedTableClient =>
      _tableClient ?? const SupabaseTableClient();

  Future<AdminReportPageResult> fetchReports({
    required int page,
    required int pageSize,
    String query = '',
    String? status,
    String? reportCategory,
    String? issueType,
  }) async {
    final range = SupabaseTableClient.rangeForPage(
      page: page,
      pageSize: pageSize,
    );
    final dynamic filter = _reportListQuery(
      query: query,
      status: status,
      reportCategory: reportCategory,
      issueType: issueType,
    );

    final SupabasePagedRows pageRows = await _resolvedTableClient.pagedRows(
      'admin_report_list page',
      () async {
        return filter
            .order('created_at', ascending: false)
            .range(range.from, range.to)
            .count(CountOption.exact);
      },
    );
    final AdminReportStatusCounts statusCounts = await fetchStatusCounts(
      query: query,
      reportCategory: reportCategory,
      issueType: issueType,
    );
    final records = pageRows.rows.map(_recordFromRow).toList(growable: false);
    return AdminReportPageResult(
      records: records,
      totalCount: pageRows.totalCount ?? records.length,
      statusCounts: statusCounts,
    );
  }

  static const String _selectColumns =
      'id_report, id_user, reporter_name, reporter_email, report_category, issue_type, target_type, target_id, feature_area, report_content, images, status, action_taken, created_at';

  Future<AdminReportStatusCounts> fetchStatusCounts({
    String query = '',
    String? reportCategory,
    String? issueType,
  }) async {
    final List<int> counts = await Future.wait(<Future<int>>[
      _countReports(
        status: 'pending',
        query: query,
        reportCategory: reportCategory,
        issueType: issueType,
      ),
      _countReports(
        status: 'reviewing',
        query: query,
        reportCategory: reportCategory,
        issueType: issueType,
      ),
      _countReports(
        status: 'resolved',
        query: query,
        reportCategory: reportCategory,
        issueType: issueType,
      ),
      _countReports(
        status: 'rejected',
        query: query,
        reportCategory: reportCategory,
        issueType: issueType,
      ),
    ]);
    return AdminReportStatusCounts(
      pending: counts[0],
      reviewing: counts[1],
      resolved: counts[2],
      rejected: counts[3],
    );
  }

  Future<int> _countReports({
    required String status,
    required String query,
    String? reportCategory,
    String? issueType,
  }) async {
    final dynamic filter = _reportListQuery(
      query: query,
      status: status,
      reportCategory: reportCategory,
      issueType: issueType,
      selectColumns: 'id_report',
    );
    final SupabasePagedRows pageRows = await _resolvedTableClient.pagedRows(
      'admin_report_status_counts $status',
      () async {
        return filter.range(0, 0).count(CountOption.exact);
      },
    );
    return pageRows.totalCount ?? pageRows.rows.length;
  }

  dynamic _reportListQuery({
    required String query,
    String? status,
    String? reportCategory,
    String? issueType,
    String selectColumns = _selectColumns,
  }) {
    dynamic filter = _client.from('admin_report_list').select(selectColumns);

    final trimmedStatus = status?.trim();
    if (trimmedStatus != null && trimmedStatus.isNotEmpty) {
      filter = filter.eq('status', trimmedStatus);
    }

    final trimmedCategory = reportCategory?.trim();
    if (trimmedCategory != null && trimmedCategory.isNotEmpty) {
      filter = filter.eq('report_category', trimmedCategory);
    }

    final trimmedIssueType = issueType?.trim();
    if (trimmedIssueType != null && trimmedIssueType.isNotEmpty) {
      filter = filter.eq('issue_type', trimmedIssueType);
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      final escaped = _escapeSearch(trimmedQuery);
      filter = filter.or(
        'id_report.ilike.%$escaped%,reporter_name.ilike.%$escaped%,reporter_email.ilike.%$escaped%,report_category.ilike.%$escaped%,issue_type.ilike.%$escaped%,target_type.ilike.%$escaped%,feature_area.ilike.%$escaped%,report_content.ilike.%$escaped%,status.ilike.%$escaped%',
      );
    }

    return filter;
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    required String actionTaken,
  }) async {
    await _client
        .from('report')
        .update(<String, dynamic>{
          'status': status,
          'action_taken': actionTaken,
          if (status == 'resolved' || status == 'rejected')
            'resolved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id_report', reportId);
  }

  AdminReportRecord _recordFromRow(Map<String, dynamic> row) {
    final Map<String, dynamic>? user =
        row['user_account'] is Map<String, dynamic>
        ? row['user_account'] as Map<String, dynamic>
        : null;
    final String? userId = row['id_user']?.toString();
    final String reporterEmail = _firstNonEmpty(<String>[
      _string(row['reporter_email']),
      _string(user?['username']),
    ]);
    final String reporterName = _firstNonEmpty(<String>[
      _string(row['reporter_name']),
      _string(user?['full_name']),
      reporterEmail.isEmpty ? '' : reporterEmail.split('@').first,
      userId == null || userId.isEmpty
          ? ''
          : 'User ${userId.substring(0, userId.length < 8 ? userId.length : 8)}',
      'Anonymous user',
    ]);

    return AdminReportRecord(
      id: _string(row['id_report']),
      reporterName: reporterName,
      reporterEmail: reporterEmail.isEmpty ? 'No email' : reporterEmail,
      reportCategory: _string(row['report_category']),
      issueType: _string(row['issue_type']).isEmpty
          ? _issueTypeFromCategory(
              category: _string(row['report_category']),
              featureArea: _nullableString(row['feature_area']),
            )
          : _string(row['issue_type']),
      targetType: _nullableString(row['target_type']),
      targetId: _nullableString(row['target_id']),
      featureArea: _nullableString(row['feature_area']),
      content: _string(row['report_content']).isEmpty
          ? 'No description provided.'
          : _string(row['report_content']),
      images: _imageUrls(row['images']),
      status: _string(row['status']).isEmpty
          ? 'pending'
          : _string(row['status']),
      actionTaken: _nullableString(row['action_taken']),
      createdAt:
          DateTime.tryParse(_string(row['created_at']))?.toLocal() ??
          DateTime.now(),
    );
  }

  List<String> _imageUrls(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((Object? item) {
          if (item is Map) {
            return _firstNonEmpty(<String>[
              _string(item['url']),
              _string(item['path']),
              _string(item['name']),
            ]);
          }
          return item?.toString() ?? '';
        })
        .where((String value) => value.trim().isNotEmpty)
        .toList(growable: false);
  }

  String _firstNonEmpty(List<String> values) {
    for (final String value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  String _string(Object? value) => value?.toString().trim() ?? '';

  String? _nullableString(Object? value) {
    final String result = _string(value);
    return result.isEmpty ? null : result;
  }

  String _issueTypeFromCategory({
    required String category,
    required String? featureArea,
  }) {
    final String area = featureArea?.toLowerCase() ?? '';
    if (area.contains('map')) return 'map_address_issue';
    if (area.contains('media') || area.contains('image')) {
      return 'inappropriate_media';
    }
    return switch (category) {
      'content_report' => 'incorrect_data',
      'bug_report' => 'app_function',
      'account_issue' => 'app_function',
      'payment_issue' => 'app_function',
      'suggestion' => 'other',
      _ => 'other',
    };
  }

  String _escapeSearch(String query) {
    return query.replaceAll('%', r'\%').replaceAll(',', r'\,');
  }
}
