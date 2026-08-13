import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/admin/data/admin_data_freshness_repository.dart';
import 'package:hellovietnam/features/admin/domain/admin_data_freshness.dart';
import 'package:hellovietnam/features/admin/presentation/pages/admin_data_freshness_page.dart';

void main() {
  testWidgets('renders the admin freshness workflow entirely in English', (
    tester,
  ) async {
    final _FakeRepository repository = _FakeRepository();
    await tester.pumpWidget(
      MaterialApp(home: AdminDataFreshnessPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending review'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Stale data'), findsOneWidget);
    expect(find.text('Run history'), findsOneWidget);
    expect(find.text('Refresh data'), findsOneWidget);
    expect(find.text('Auto-expired today'), findsOneWidget);
    expect(find.text('Failed runs'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Keep active'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsNothing);
    expect(find.text('Tải lại dữ liệu'), findsNothing);
    expect(find.text('Old Street'), findsOneWidget);
    expect(find.text('New Street'), findsOneWidget);
  });

  testWidgets('opens report details from the report tab', (tester) async {
    final _FakeRepository repository = _FakeRepository(
      reports: const <AdminFreshnessReport>[
        AdminFreshnessReport(
          id: 'report-1',
          contentType: 'activity',
          contentId: 'activity-1',
          reason: 'event_ended',
          note: 'The event has ended.',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: AdminDataFreshnessPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();

    expect(find.text('Report details'), findsOneWidget);
    expect(find.text('ISSUE TYPE'), findsOneWidget);
    expect(find.text('AFFECTED ITEM'), findsOneWidget);
    expect(find.text('DESCRIPTION'), findsOneWidget);
    expect(find.text('Reporter'), findsOneWidget);
    expect(find.text('Edit item'), findsOneWidget);
    expect(find.text('Mark resolved'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Chi tiết báo sai'), findsNothing);
    expect(find.textContaining('activity-1'), findsOneWidget);
    expect(find.text('The event has ended.').last, findsOneWidget);
  });
}

class _FakeRepository extends AdminDataFreshnessRepository {
  _FakeRepository({this.reports = const <AdminFreshnessReport>[]});

  final List<AdminFreshnessReport> reports;

  @override
  Future<AdminFreshnessOverview> getOverview() async =>
      const AdminFreshnessOverview(due: 2, pending: 1);

  @override
  Future<AdminFreshnessPaged<AdminFreshnessProposal>> listQueue({
    required int page,
    required int pageSize,
  }) async => const AdminFreshnessPaged<AdminFreshnessProposal>(
    totalCount: 1,
    items: <AdminFreshnessProposal>[
      AdminFreshnessProposal(
        id: 'proposal-1',
        contentType: 'place',
        contentId: 'place-1',
        beforeData: <String, dynamic>{'address': 'Old Street'},
        proposedData: <String, dynamic>{'address': 'New Street'},
        reason: 'source_changed',
      ),
    ],
  );

  @override
  Future<AdminFreshnessPaged<AdminFreshnessReport>> listReports({
    required int page,
    required int pageSize,
  }) async => AdminFreshnessPaged<AdminFreshnessReport>(
    totalCount: reports.length,
    items: reports,
  );

  @override
  Future<AdminFreshnessPaged<AdminFreshnessStale>> listStale({
    required int page,
    required int pageSize,
  }) async => const AdminFreshnessPaged<AdminFreshnessStale>(
    totalCount: 0,
    items: <AdminFreshnessStale>[],
  );

  @override
  Future<AdminFreshnessPaged<AdminFreshnessRun>> listRuns({
    required int page,
    required int pageSize,
  }) async => const AdminFreshnessPaged<AdminFreshnessRun>(
    totalCount: 0,
    items: <AdminFreshnessRun>[],
  );

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
  }) async {}
}
