import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReportRecord {
  const AdminReportRecord({
    required this.id,
    required this.reporterName,
    required this.reporterEmail,
    required this.reportCategory,
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
  final String? targetType;
  final String? targetId;
  final String? featureArea;
  final String content;
  final List<String> images;
  final String status;
  final String? actionTaken;
  final DateTime createdAt;
}

class AdminReportRepository {
  AdminReportRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AdminReportRecord>> fetchReports() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('report')
        .select(
          'id_report, id_user, report_category, target_type, target_id, feature_area, report_content, images, status, action_taken, created_at, user_account(full_name, username)',
        )
        .order('created_at', ascending: false);

    return rows.map(_recordFromRow).toList(growable: false);
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
    final String reporterEmail = _string(user?['username']);
    final String reporterName = _firstNonEmpty(<String>[
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
}
