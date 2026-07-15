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

  test('planTrip forwards business coordinates and draft flag', () async {
    Object? capturedBody;
    final functionClient = SupabaseFunctionClient(
      accessTokenProvider: () => 'token',
      invoker: (functionName, {headers, body}) async {
        capturedBody = body;
        return <String, dynamic>{
          'id_plan': null,
          'days': <Map<String, dynamic>>[],
        };
      },
    );

    final repository = TripRepository(functionClient: functionClient);
    final response = await repository.planTrip(
      const TripPlanRequest(
        nDays: 3,
        startDate: '2026-07-20',
        savePlan: false,
        targetLat: 10.7769,
        targetLng: 106.7009,
      ),
    );

    expect(response.idPlan, isNull);
    expect(
      capturedBody,
      allOf(
        containsPair('action', 'planTrip'),
        containsPair('nDays', 3),
        containsPair('startDate', '2026-07-20'),
        containsPair('savePlan', false),
        containsPair('targetLat', 10.7769),
        containsPair('targetLng', 106.7009),
      ),
    );
  });

  test('getPlan sends idPlan and parses the plan response', () async {
    Object? capturedBody;
    final functionClient = SupabaseFunctionClient(
      accessTokenProvider: () => 'token',
      invoker: (functionName, {headers, body}) async {
        capturedBody = body;
        return <String, dynamic>{
          'id_plan': 'plan-42',
          'days': <Map<String, dynamic>>[
            <String, dynamic>{
              'day': 1,
              'date': '2026-07-20',
              'places': <Map<String, dynamic>>[],
            },
          ],
        };
      },
    );

    final repository = TripRepository(functionClient: functionClient);
    final plan = await repository.getPlan('plan-42');

    expect(plan.idPlan, 'plan-42');
    expect(plan.days, hasLength(1));
    expect(
      capturedBody,
      allOf(
        containsPair('action', 'getPlan'),
        containsPair('idPlan', 'plan-42'),
      ),
    );
  });

  test('getNearbyPlaces forwards coordinates and limit', () async {
    Object? capturedBody;
    final functionClient = SupabaseFunctionClient(
      accessTokenProvider: () => 'token',
      invoker: (functionName, {headers, body}) async {
        capturedBody = body;
        return <String, dynamic>{
          'places': <Map<String, dynamic>>[
            <String, dynamic>{
              'id_place': 'place-1',
              'name': 'Ben Thanh Market',
              'subcategory_name': 'Market',
              'latitude': 10.7725,
              'longitude': 106.6980,
              'distance_km': 1.2,
              'estimated_minutes': 8,
            },
          ],
        };
      },
    );

    final repository = TripRepository(functionClient: functionClient);
    final places = await repository.getNearbyPlaces(
      10.7769,
      106.7009,
      limit: 5,
    );

    expect(places, hasLength(1));
    expect(places.single.idPlace, 'place-1');
    expect(
      capturedBody,
      allOf(
        containsPair('action', 'getNearbyPlaces'),
        containsPair('lat', 10.7769),
        containsPair('lng', 106.7009),
        containsPair('limit', 5),
      ),
    );
  });

  test('clonePlan sends source id and returns cloned id', () async {
    Object? capturedBody;
    final functionClient = SupabaseFunctionClient(
      accessTokenProvider: () => 'token',
      invoker: (functionName, {headers, body}) async {
        capturedBody = body;
        return <String, dynamic>{'id_plan': 'cloned-plan'};
      },
    );

    final repository = TripRepository(functionClient: functionClient);
    final clonedId = await repository.clonePlan('source-plan');

    expect(clonedId, 'cloned-plan');
    expect(
      capturedBody,
      allOf(
        containsPair('action', 'clonePlan'),
        containsPair('idPlan', 'source-plan'),
      ),
    );
  });

  test('savePlan forwards idPlan and customTitle', () async {
    Object? capturedBody;
    final functionClient = SupabaseFunctionClient(
      accessTokenProvider: () => 'token',
      invoker: (functionName, {headers, body}) async {
        capturedBody = body;
        return <String, dynamic>{};
      },
    );

    final repository = TripRepository(functionClient: functionClient);
    await repository.savePlan(
      'plan-42',
      customTitle: 'Summer in Da Nang',
    );

    expect(
      capturedBody,
      allOf(
        containsPair('action', 'savePlan'),
        containsPair('idPlan', 'plan-42'),
        containsPair('customTitle', 'Summer in Da Nang'),
      ),
    );
  });
}
