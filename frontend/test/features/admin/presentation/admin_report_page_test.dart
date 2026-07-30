import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/admin/data/admin_report_repository.dart';
import 'package:hellovietnam/features/admin/presentation/admin_shell.dart';
import 'package:hellovietnam/features/admin/presentation/pages/admin_report_page.dart';

void main() {
  testWidgets('report page does not overflow while loading or showing data', (
    tester,
  ) async {
    final completer = Completer<AdminReportPageResult>();
    final repository = _FakeAdminReportRepository(completer.future);

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminShell(
          currentPath: '/admin/reports',
          child: AdminReportPage(repository: repository),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    completer.complete(_reportPageResult());
    await tester.pumpAndSettle();

    expect(find.text('Report Management'), findsOneWidget);
    expect(find.text('App function'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

AdminReportPageResult _reportPageResult() {
  return AdminReportPageResult(
    records: <AdminReportRecord>[
      AdminReportRecord(
        id: '7a4ba058-1326-4acb-80c5-4a87599589c8',
        reporterName: 'Thái Cao Phạm Hoàng',
        reporterEmail: 'caothai0711@gmail.com',
        reportCategory: 'bug_report',
        issueType: 'app_function',
        targetType: 'feature',
        targetId: null,
        featureArea: 'explore',
        content: 'The Explore screen did not load as expected.',
        images: const <String>[],
        status: 'pending',
        actionTaken: null,
        createdAt: DateTime.utc(2026, 7, 15),
      ),
    ],
    totalCount: 1,
    statusCounts: const AdminReportStatusCounts(
      pending: 1,
      reviewing: 0,
      resolved: 0,
      rejected: 0,
    ),
  );
}

class _FakeAdminReportRepository extends AdminReportRepository {
  _FakeAdminReportRepository(this.result);

  final Future<AdminReportPageResult> result;

  @override
  Future<AdminReportPageResult> fetchReports({
    required int page,
    required int pageSize,
    String query = '',
    String? status,
    String? reportCategory,
    String? issueType,
  }) {
    return result;
  }
}
