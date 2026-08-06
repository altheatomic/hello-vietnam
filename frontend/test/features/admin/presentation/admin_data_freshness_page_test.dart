import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/admin/data/admin_data_freshness_repository.dart';
import 'package:hellovietnam/features/admin/domain/admin_data_freshness.dart';
import 'package:hellovietnam/features/admin/presentation/pages/admin_data_freshness_page.dart';

void main() {
  testWidgets('renders the four freshness queue tabs and a proposal diff', (
    tester,
  ) async {
    final _FakeRepository repository = _FakeRepository();
    await tester.pumpWidget(
      MaterialApp(home: AdminDataFreshnessPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chờ duyệt'), findsOneWidget);
    expect(find.text('Báo sai'), findsOneWidget);
    expect(find.text('Dữ liệu stale'), findsOneWidget);
    expect(find.text('Lịch sử chạy'), findsOneWidget);
    expect(find.text('Tải lại dữ liệu'), findsOneWidget);
    expect(find.text('Kiểm tra ngay'), findsNothing);
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

    await tester.tap(find.text('Báo sai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem chi tiết'));
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết báo sai'), findsOneWidget);
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
}
