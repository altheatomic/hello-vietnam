import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/data_freshness/data/content_freshness_repository.dart';
import 'package:hellovietnam/features/data_freshness/domain/content_freshness_models.dart';

void main() {
  test('submitReport sends a content-specific payload', () async {
    Map<String, Object?>? lastBody;
    final ContentFreshnessRepository repository = ContentFreshnessRepository(
      functionClient: SupabaseFunctionClient(
        accessTokenProvider: () => 'token',
        invoker:
            (
              String functionName, {
              Map<String, String>? headers,
              Object? body,
            }) async {
              lastBody = Map<String, Object?>.from(body as Map);
              return <String, dynamic>{
                'report': <String, dynamic>{'id': 'report-1'},
              };
            },
      ),
    );

    await repository.submitReport(
      contentType: FreshnessContentType.place,
      contentId: '10000000-0000-4000-8000-000000000001',
      reason: ContentReportReason.wrongHours,
      note: 'Closes at 21:00',
    );

    expect(lastBody, <String, Object?>{
      'action': 'submitReport',
      'contentType': 'place',
      'contentId': '10000000-0000-4000-8000-000000000001',
      'reason': 'wrong_hours',
      'note': 'Closes at 21:00',
    });
  });

  test('maps duplicate and rate-limit errors to stable codes', () async {
    for (final String code in <String>[
      'duplicate_report',
      'report_rate_limited',
    ]) {
      final ContentFreshnessRepository repository = ContentFreshnessRepository(
        functionClient: SupabaseFunctionClient(
          accessTokenProvider: () => 'token',
          invoker:
              (
                String functionName, {
                Map<String, String>? headers,
                Object? body,
              }) async {
                throw SupabaseFunctionException('failed', errorCode: code);
              },
        ),
      );

      expect(
        () => repository.submitReport(
          contentType: FreshnessContentType.place,
          contentId: '10000000-0000-4000-8000-000000000001',
          reason: ContentReportReason.other,
        ),
        throwsA(
          isA<ContentFreshnessException>().having(
            (ContentFreshnessException error) => error.code,
            'code',
            code,
          ),
        ),
      );
    }
  });
}
