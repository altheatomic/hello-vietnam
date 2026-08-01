import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/trip_plan_request.dart';
import 'models/trip_plan_response.dart';

class NoTripCandidatesException implements Exception {
  const NoTripCandidatesException();
}

class TripRepository {
  TripRepository({
    SupabaseFunctionClient? functionClient,
    SupabaseClient? client,
  }) : _functionClient =
           functionClient ?? SupabaseFunctionClient(client: client);

  final SupabaseFunctionClient _functionClient;

  Future<TripPlanResponse> planTrip(TripPlanRequest request) async {
    try {
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
    } on SupabaseFunctionException catch (error) {
      if (error.errorCode == 'no_candidates') {
        throw const NoTripCandidatesException();
      }
      rethrow;
    }
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

  Future<void> activateTrip(String idPlan) async {
    await _invoke(<String, Object?>{'action': 'activateTrip', 'idPlan': idPlan});
  }

  Future<void> completeTrip(String idPlan) async {
    await _invoke(<String, Object?>{'action': 'completeTrip', 'idPlan': idPlan});
  }

  Future<void> markTripOverdueNotified(String idPlan) async {
    await _invoke(<String, Object?>{
      'action': 'markTripOverdueNotified',
      'idPlan': idPlan,
    });
  }

  /// Client-pull check for trips left un-ended long after their planned end
  /// date — see cf_service `get_overdue_plans()` for the reusable query
  /// this calls through.
  Future<List<OverdueTripPlan>> checkOverdueTrips() async {
    final data = await _invoke(<String, Object?>{'action': 'overdueTripCheck'});
    final raw = data['plans'] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(OverdueTripPlan.fromJson)
        .toList();
  }

  Future<void> triggerCfRetrain() async {
    await _invoke(<String, Object?>{'action': 'triggerCfRetrain'});
  }

  Future<List<CfRetrainLog>> getCfRetrainLogs() async {
    final data = await _invoke(<String, Object?>{'action': 'getCfRetrainLogs'});
    final raw = data['logs'] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CfRetrainLog.fromJson)
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
