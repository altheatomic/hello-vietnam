import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/data_freshness/domain/content_freshness_models.dart';
import 'package:hellovietnam/features/data_freshness/presentation/content_report_sheet.dart';
import 'package:hellovietnam/features/data_freshness/data/content_freshness_repository.dart';

void main() {
  testWidgets('requires a reason before submitting a report', (tester) async {
    final _FakeRepository repository = _FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentReportSheet(
            contentType: FreshnessContentType.place,
            contentId: '10000000-0000-4000-8000-000000000001',
            contentName: 'Cafe Example',
            repository: repository,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(find.text('Please choose a reason.'), findsOneWidget);
    expect(repository.calls, 0);
  });

  testWidgets('submits a selected report once and shows success', (
    tester,
  ) async {
    final _FakeRepository repository = _FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentReportSheet(
            contentType: FreshnessContentType.place,
            contentId: '10000000-0000-4000-8000-000000000001',
            contentName: 'Cafe Example',
            repository: repository,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Wrong opening hours'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    expect(
      find.text('Thanks for helping keep this information accurate.'),
      findsOneWidget,
    );
  });
}

class _FakeRepository extends ContentFreshnessRepository {
  int calls = 0;

  @override
  Future<String?> submitReport({
    required FreshnessContentType contentType,
    required String contentId,
    required ContentReportReason reason,
    String? note,
  }) async {
    calls += 1;
    return 'report-1';
  }
}
