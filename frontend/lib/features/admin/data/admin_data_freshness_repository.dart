import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/admin/domain/admin_data_freshness.dart';

class AdminDataFreshnessRepository {
  AdminDataFreshnessRepository({SupabaseFunctionClient? functionClient})
    : _functionClient = functionClient;

  final SupabaseFunctionClient? _functionClient;

  SupabaseFunctionClient get _client =>
      _functionClient ?? SupabaseFunctionClient();

  Future<AdminFreshnessOverview> getOverview() async {
    final Map<String, dynamic> data = await _invoke('adminGetOverview');
    return AdminFreshnessOverview.fromJson(_map(data['overview']));
  }

  Future<AdminFreshnessPaged<AdminFreshnessProposal>> listQueue({
    required int page,
    required int pageSize,
  }) async {
    final Map<String, dynamic> data = await _invoke(
      'adminListQueue',
      extra: <String, Object?>{'page': page, 'pageSize': pageSize},
    );
    return AdminFreshnessPaged<AdminFreshnessProposal>(
      items: _rows(
        data['proposals'],
      ).map(AdminFreshnessProposal.fromJson).toList(growable: false),
      totalCount: _integer(data['totalCount']),
    );
  }

  Future<AdminFreshnessPaged<AdminFreshnessReport>> listReports({
    required int page,
    required int pageSize,
  }) async {
    final Map<String, dynamic> data = await _invoke(
      'adminListReports',
      extra: <String, Object?>{'page': page, 'pageSize': pageSize},
    );
    return AdminFreshnessPaged<AdminFreshnessReport>(
      items: _rows(
        data['reports'],
      ).map(AdminFreshnessReport.fromJson).toList(growable: false),
      totalCount: _integer(data['totalCount']),
    );
  }

  Future<AdminFreshnessPaged<AdminFreshnessStale>> listStale({
    required int page,
    required int pageSize,
  }) async {
    final Map<String, dynamic> data = await _invoke(
      'adminListStale',
      extra: <String, Object?>{'page': page, 'pageSize': pageSize},
    );
    return AdminFreshnessPaged<AdminFreshnessStale>(
      items: _rows(
        data['freshness'],
      ).map(AdminFreshnessStale.fromJson).toList(growable: false),
      totalCount: _integer(data['totalCount']),
    );
  }

  Future<AdminFreshnessPaged<AdminFreshnessRun>> listRuns({
    required int page,
    required int pageSize,
  }) async {
    final Map<String, dynamic> data = await _invoke(
      'adminListRuns',
      extra: <String, Object?>{'page': page, 'pageSize': pageSize},
    );
    return AdminFreshnessPaged<AdminFreshnessRun>(
      items: _rows(
        data['runs'],
      ).map(AdminFreshnessRun.fromJson).toList(growable: false),
      totalCount: _integer(data['totalCount']),
    );
  }

  Future<AdminFreshnessProposal?> reviewProposal({
    required String proposalId,
    required AdminFreshnessDecision decision,
    required Map<String, Object?> appliedData,
  }) async {
    final Map<String, dynamic> data = await _invoke(
      'adminReviewProposal',
      extra: <String, Object?>{
        'proposalId': proposalId,
        'decision': decision.apiValue,
        'appliedData': appliedData,
      },
    );
    final Object? proposal = data['proposal'];
    return proposal is Map
        ? AdminFreshnessProposal.fromJson(_map(proposal))
        : null;
  }

  Future<void> requestCheck({
    required String contentType,
    required String contentId,
  }) async {
    await _invoke(
      'adminRequestCheck',
      extra: <String, Object?>{
        'contentType': contentType,
        'contentId': contentId,
      },
    );
  }

  Future<Map<String, dynamic>> _invoke(
    String action, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    return _client.invokeJson(
      Env.dataFreshnessFunction,
      body: <String, Object?>{'action': action, ...extra},
      requireAuth: true,
    );
  }

  List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value.whereType<Map>().map(_map).toList(growable: false);
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((Object? key, Object? item) => MapEntry('$key', item));
    }
    return <String, dynamic>{};
  }

  int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
