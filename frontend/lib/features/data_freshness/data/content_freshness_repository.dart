import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/data_freshness/domain/content_freshness_models.dart';

class ContentFreshnessRepository {
  ContentFreshnessRepository({SupabaseFunctionClient? functionClient})
    : _functionClient = functionClient;

  final SupabaseFunctionClient? _functionClient;

  SupabaseFunctionClient get _resolvedClient =>
      _functionClient ?? SupabaseFunctionClient();

  Future<String?> submitReport({
    required FreshnessContentType contentType,
    required String contentId,
    required ContentReportReason reason,
    String? note,
  }) async {
    try {
      final Map<String, dynamic> payload = await _resolvedClient.invokeJson(
        Env.dataFreshnessFunction,
        body: <String, Object?>{
          'action': 'submitReport',
          'contentType': contentType.apiValue,
          'contentId': contentId,
          'reason': reason.apiValue,
          'note': note,
        },
        requireAuth: true,
      );
      final Object? report = payload['report'];
      if (report is Map) {
        return report['id']?.toString();
      }
      return null;
    } on SupabaseFunctionException catch (error) {
      final String? code = error.errorCode ?? _codeFromDetails(error.details);
      throw ContentFreshnessException(error.message, code: code);
    }
  }

  Future<List<Map<String, dynamic>>> listMyReports() async {
    final Map<String, dynamic> payload = await _resolvedClient.invokeJson(
      Env.dataFreshnessFunction,
      body: const <String, Object?>{'action': 'listMyReports'},
      requireAuth: true,
    );
    final Object? rows = payload['reports'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map(
          (Map row) => row.map(
            (Object? key, Object? value) => MapEntry(key.toString(), value),
          ),
        )
        .toList(growable: false);
  }

  String? _codeFromDetails(Object? details) {
    if (details is Map) {
      final Object? code = details['code'] ?? details['error_code'];
      final String value = code?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    }
    return null;
  }
}
