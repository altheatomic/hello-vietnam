import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/features/admin/data/admin_report_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('fetchReports loads admin report view rows and status counts', () async {
    final _FakeTableClient tableClient = _FakeTableClient(
      responses: <String, Object?>{
        'admin_report_list page': _FakePostgrestPage(
          data: <Map<String, dynamic>>[
            <String, dynamic>{
              'id_report': 'report-1',
              'id_user': 'user-1',
              'report_category': 'bug_report',
              'issue_type': 'app_function',
              'target_type': 'feature',
              'target_id': null,
              'feature_area': 'translate',
              'report_content': 'Translate button is slow',
              'images': <String>['https://example.com/report.png'],
              'status': 'pending',
              'action_taken': null,
              'created_at': '2026-07-04T02:00:00Z',
              'reporter_name': 'Nguyen An',
              'reporter_email': 'an@example.com',
            },
          ],
          count: 15,
        ),
        'admin_report_status_counts pending': const _FakePostgrestPage(
          data: <Map<String, dynamic>>[],
          count: 4,
        ),
        'admin_report_status_counts reviewing': const _FakePostgrestPage(
          data: <Map<String, dynamic>>[],
          count: 3,
        ),
        'admin_report_status_counts resolved': const _FakePostgrestPage(
          data: <Map<String, dynamic>>[],
          count: 6,
        ),
        'admin_report_status_counts rejected': const _FakePostgrestPage(
          data: <Map<String, dynamic>>[],
          count: 2,
        ),
      },
    );
    final AdminReportRepository repository = AdminReportRepository(
      client: SupabaseClient('https://example.supabase.co', 'anon-key'),
      tableClient: tableClient,
    );

    final AdminReportPageResult result = await repository.fetchReports(
      page: 2,
      pageSize: 8,
      query: 'translate',
      status: 'pending',
      issueType: 'app_function',
    );

    expect(tableClient.runLabels, <String>[
      'admin_report_list page',
      'admin_report_status_counts pending',
      'admin_report_status_counts reviewing',
      'admin_report_status_counts resolved',
      'admin_report_status_counts rejected',
    ]);
    expect(result.totalCount, 15);
    expect(result.statusCounts.pending, 4);
    expect(result.statusCounts.reviewing, 3);
    expect(result.statusCounts.resolved, 6);
    expect(result.statusCounts.rejected, 2);
    expect(result.records.single.id, 'report-1');
    expect(result.records.single.issueType, 'app_function');
    expect(result.records.single.reporterName, 'Nguyen An');
    expect(result.records.single.reporterEmail, 'an@example.com');
    expect(result.records.single.content, 'Translate button is slow');
    expect(result.records.single.images, <String>[
      'https://example.com/report.png',
    ]);
  });
}

class _FakePostgrestPage {
  const _FakePostgrestPage({required this.data, required this.count});

  final List<Map<String, dynamic>> data;
  final int count;
}

class _FakeTableClient extends SupabaseTableClient {
  _FakeTableClient({required this.responses});

  final Map<String, Object?> responses;
  final List<String> runLabels = <String>[];

  @override
  Future<T> run<T>(
    String label,
    Future<T> Function() request, {
    Duration? timeout,
  }) async {
    runLabels.add(label);
    if (!responses.containsKey(label)) {
      throw StateError('No fake response for $label.');
    }
    return responses[label] as T;
  }
}
