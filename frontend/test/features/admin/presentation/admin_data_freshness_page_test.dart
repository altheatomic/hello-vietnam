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
    expect(find.text('Old Street'), findsOneWidget);
    expect(find.text('New Street'), findsOneWidget);
  });
}

class _FakeRepository extends AdminDataFreshnessRepository {
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
  }) async => const AdminFreshnessPaged<AdminFreshnessReport>(
    totalCount: 0,
    items: <AdminFreshnessReport>[],
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
