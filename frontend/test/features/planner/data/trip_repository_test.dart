import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_request.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';

void main() {
  test('planTrip invokes trip-planner edge function with normalized payload', () async {
    final calls = <Map<String, Object?>>[];
    final functionClient = SupabaseFunctionClient(
      accessTokenProvider: () => 'token',
      invoker: (functionName, {headers, body}) async {
        calls.add(<String, Object?>{
          'functionName': functionName,
          'headers': headers,
          'body': body,
        });
        return <String, dynamic>{
          'id_plan': 'plan-1',
          'days': <Map<String, dynamic>>[
            <String, dynamic>{
              'day': 1,
              'date': '2026-07-10',
              'places': <Map<String, dynamic>>[],
            },
          ],
        };
      },
    );

    final repository = TripRepository(functionClient: functionClient);
    final response = await repository.planTrip(
      const TripPlanRequest(
        idProvince: 'province-1',
        nDays: 2,
        saRuns: 4,
        savePlan: true,
        interestOptionIds: <String>['food', 'culture'],
      ),
    );

    expect(response.idPlan, 'plan-1');
    expect(response.days, hasLength(1));
    expect(calls, hasLength(1));
    expect(calls.single['functionName'], 'trip-planner');
    expect(
      calls.single['headers'],
      containsPair('Authorization', 'Bearer token'),
    );
    expect(
      calls.single['body'],
      containsPair('action', 'planTrip'),
    );
    expect(
      calls.single['body'],
      containsPair('idProvince', 'province-1'),
    );
  });

  test('listSavedPlans reads saved plans through trip-planner function', () async {
    final calls = <Object?>[];
    final functionClient = SupabaseFunctionClient(
      accessTokenProvider: () => 'token',
      invoker: (functionName, {headers, body}) async {
        calls.add(body);
        return <String, dynamic>{
          'plans': <Map<String, dynamic>>[
            <String, dynamic>{
              'id_plan': 'saved-1',
              'duration': '2 days',
              'start_at': '2026-07-10',
              'end_at': '2026-07-11',
              'province_name': 'Da Nang',
              'created_at': '2026-07-10',
              'stops': <Map<String, dynamic>>[],
            },
          ],
        };
      },
    );

    final repository = TripRepository(functionClient: functionClient);
    final plans = await repository.listSavedPlans();

    expect(plans, hasLength(1));
    expect(plans.single.idPlan, 'saved-1');
    expect(calls.single, containsPair('action', 'listSavedPlans'));
  });
}
