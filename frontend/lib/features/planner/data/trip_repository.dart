import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/trip_plan_request.dart';
import 'models/trip_plan_response.dart';

class TripRepository {
  TripRepository({
    SupabaseFunctionClient? functionClient,
    SupabaseClient? client,
  }) : _functionClient =
           functionClient ?? SupabaseFunctionClient(client: client);

  final SupabaseFunctionClient _functionClient;

  Future<TripPlanResponse> planTrip(TripPlanRequest request) async {
    final data = await _invoke(<String, Object?>{
      'action': 'planTrip',
      'idProvince': request.idProvince,
      'targetLat': request.targetLat,
      'targetLng': request.targetLng,
      'nDays': request.nDays,
      'saRuns': request.saRuns,
      'savePlan': request.savePlan,
      'startDate': request.startDate,
      if (request.interestOptionIds != null &&
          request.interestOptionIds!.isNotEmpty)
        'interestOptionIds': request.interestOptionIds,
    });
    return TripPlanResponse.fromJson(data);
  }

  Future<TripPlanResponse> getPlan(String idPlan) async {
    final data = await _invoke(<String, Object?>{
      'action': 'getPlan',
      'idPlan': idPlan,
    });
    return TripPlanResponse.fromJson(data);
  }

  Future<List<TripPlanSummary>> listPlans() async {
    final data = await _invoke(<String, Object?>{'action': 'listPlans'});
    final raw = data['plans'] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TripPlanSummary.fromJson)
        .toList();
  }

  Future<List<NearbyPlace>> getNearbyPlaces(
    double lat,
    double lng, {
    int limit = 3,
  }) async {
    final data = await _invoke(<String, Object?>{
      'action': 'getNearbyPlaces',
      'lat': lat,
      'lng': lng,
      'limit': limit,
    });
    final raw = data['places'] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(NearbyPlace.fromJson)
        .toList();
  }

  Future<String> clonePlan(String idPlan) async {
    final data = await _invoke(<String, Object?>{
      'action': 'clonePlan',
      'idPlan': idPlan,
    });
    return data['id_plan'] as String;
  }

  Future<void> savePlan(String idPlan, {String? customTitle}) async {
    await _invoke(<String, Object?>{
      'action': 'savePlan',
      'idPlan': idPlan,
      'customTitle': customTitle,
    });
  }

  Future<List<SavedPlanItem>> listSavedPlans() async {
    final data = await _invoke(<String, Object?>{'action': 'listSavedPlans'});
    final raw = data['plans'] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SavedPlanItem.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> _invoke(Map<String, Object?> body) {
    return _functionClient.invokeJson(
      Env.tripPlannerFunction,
      body: body,
      requireAuth: true,
      timeout: const Duration(seconds: 45),
    );
  }
}
