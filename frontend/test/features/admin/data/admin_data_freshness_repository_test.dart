import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/admin/data/admin_data_freshness_repository.dart';
import 'package:hellovietnam/features/admin/domain/admin_data_freshness.dart';

void main() {
  test('reviewProposal sends selected applied fields', () async {
    Map<String, Object?>? lastBody;
    final AdminDataFreshnessRepository repository =
        AdminDataFreshnessRepository(
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
                    'proposal': <String, dynamic>{'decision': 'approved'},
                  };
                },
          ),
        );

    await repository.reviewProposal(
      proposalId: '10000000-0000-4000-8000-000000000001',
      decision: AdminFreshnessDecision.approved,
      appliedData: <String, Object?>{'timespan': '08:00', 'timeclose': '21:00'},
    );

    expect(lastBody?['action'], 'adminReviewProposal');
    expect(lastBody?['appliedData'], <String, Object?>{
      'timespan': '08:00',
      'timeclose': '21:00',
    });
  });

  test('decodes overview and paged queue rows', () async {
    final AdminDataFreshnessRepository repository =
        AdminDataFreshnessRepository(
          functionClient: SupabaseFunctionClient(
            accessTokenProvider: () => 'token',
            invoker:
                (
                  String functionName, {
                  Map<String, String>? headers,
                  Object? body,
                }) async {
                  final Map<String, dynamic> request =
                      Map<String, dynamic>.from(body as Map);
                  if (request['action'] == 'adminGetOverview') {
                    return <String, dynamic>{
                      'overview': <String, dynamic>{
                        'due': 3,
                        'pending': 2,
                        'autoExpiredToday': 1,
                        'failedRuns': 0,
                      },
                    };
                  }
                  if (request['action'] == 'adminListStale') {
                    return <String, dynamic>{
                      'freshness': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'id': 'freshness-1',
                          'content_type': 'place',
                          'freshness_status': 'stale',
                        },
                      ],
                      'totalCount': 1,
                    };
                  }
                  return <String, dynamic>{
                    'proposals': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'id': 'proposal-1',
                        'reason': 'possibly_closed',
                        'detected_at': '2026-08-03T02:15:00Z',
                      },
                    ],
                    'totalCount': 1,
                  };
                },
          ),
        );

    final AdminFreshnessOverview overview = await repository.getOverview();
    final AdminFreshnessPaged<AdminFreshnessProposal> queue = await repository
        .listQueue(page: 1, pageSize: 20);
    expect(overview.pending, 2);
    expect(queue.totalCount, 1);
    expect(queue.items.single.id, 'proposal-1');
    final AdminFreshnessPaged<AdminFreshnessStale> stale = await repository
        .listStale(page: 1, pageSize: 20);
    expect(stale.items.single.freshnessStatus, 'stale');
  });
}
