import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/admin/data/admin_dashboard_repository.dart';
import 'package:hellovietnam/features/admin/domain/admin_dashboard_models.dart';

void main() {
  test('loads and maps the real admin dashboard aggregate', () async {
    String? invokedFunction;
    Object? invokedBody;
    final SupabaseFunctionClient functionClient = SupabaseFunctionClient(
      accessTokenProvider: () => 'admin-token',
      invoker:
          (
            String functionName, {
            Map<String, String>? headers,
            Object? body,
          }) async {
            invokedFunction = functionName;
            invokedBody = body;
            return <String, Object?>{
              'snapshot': <String, Object?>{
                'generated_at': '2026-07-23T08:00:00Z',
                'users': <String, Object?>{
                  'total': 120,
                  'new_30d': 20,
                  'previous_30d': 10,
                  'daily_7d': <Object?>[
                    <String, Object?>{'label': 'Mon', 'count': 2},
                    <String, Object?>{'label': 'Tue', 'count': 4},
                  ],
                },
                'content': <String, Object?>{
                  'total': 310,
                  'places_total': 100,
                  'places_new_30d': 12,
                  'places_previous_30d': 8,
                  'foods_total': 80,
                  'provinces_total': 30,
                  'activities_total': 40,
                  'cultures_total': 35,
                  'local_products_total': 25,
                  'weekly_places_4': <Object?>[
                    <String, Object?>{'label': 'W1', 'count': 3},
                    <String, Object?>{'label': 'W2', 'count': 5},
                  ],
                  'inventory': <Object?>[
                    <String, Object?>{
                      'label': 'Places',
                      'count': 100,
                      'new_30d': 12,
                    },
                  ],
                },
                'reports': <String, Object?>{
                  'open': 7,
                  'new_today': 2,
                  'by_status': <Object?>[
                    <String, Object?>{'label': 'pending', 'count': 5},
                    <String, Object?>{'label': 'reviewing', 'count': 2},
                  ],
                  'by_category': <Object?>[
                    <String, Object?>{'label': 'bug_report', 'count': 4},
                    <String, Object?>{'label': 'suggestion', 'count': 3},
                  ],
                },
                'engagement': <String, Object?>{
                  'forum_posts_30d': 18,
                  'plans_30d': 9,
                  'favorites_30d': 27,
                  'weekly_4': <Object?>[
                    <String, Object?>{
                      'label': 'W1',
                      'forum_posts': 3,
                      'plans': 2,
                      'favorites': 8,
                    },
                  ],
                  'feature_30d': <Object?>[
                    <String, Object?>{'feature': 'Wishlist', 'count': 27},
                    <String, Object?>{'feature': 'Trip Planner', 'count': 9},
                  ],
                  'feature_90d': <Object?>[
                    <String, Object?>{'feature': 'Wishlist', 'count': 61},
                  ],
                },
                'subscriptions': <String, Object?>{'active': 6},
                'trending_places': <Object?>[
                  <String, Object?>{
                    'id': 'place-1',
                    'name': 'Hoi An',
                    'views': 250,
                    'saves': 40,
                    'rating': 4.7,
                  },
                ],
              },
            };
          },
    );
    final AdminDashboardRepositoryImpl repository =
        AdminDashboardRepositoryImpl(functionClient: functionClient);

    final AdminDashboardSnapshot snapshot = await repository
        .fetchDashboardSnapshot(forceRefresh: true);

    expect(invokedFunction, 'admin-dashboard');
    expect(invokedBody, <String, Object?>{'forceRefresh': true});
    expect(snapshot.hero.highlightStats[0].value, '12');
    expect(snapshot.businessMetrics[1].value, '310');
    expect(snapshot.systemMetrics[0].value, '7');
    expect(snapshot.systemMetrics[3].value, '6');
    expect(snapshot.trendingPlaces.single.title, 'Hoi An');
    expect(snapshot.reportBreakdown.items.first.count, 4);
    expect(
      snapshot.featureUsagePeriods.first.range,
      DashboardFeatureUsageRange.month,
    );
  });
}
