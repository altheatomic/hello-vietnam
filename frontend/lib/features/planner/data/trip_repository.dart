import 'dart:convert';

import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/trip_plan_request.dart';
import 'models/trip_plan_response.dart';
import 'models/trip_share_link.dart';

class NoTripCandidatesException implements Exception {
  const NoTripCandidatesException();
}

class TripRepository {
  TripRepository({
    SupabaseFunctionClient? functionClient,
    SupabaseClient? client,
    http.Client? httpClient,
  }) : _functionClient =
           functionClient ?? SupabaseFunctionClient(client: client),
       _httpClient = httpClient ?? http.Client();

  final SupabaseFunctionClient _functionClient;
  final http.Client _httpClient;

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

  Future<CreatedTripShare> createShareLink(
    String idPlan, {
    int expiryDays = 30,
    bool allowCopy = true,
  }) async {
    final data = await _shareInvoke(<String, Object?>{
      'action': 'create',
      'idPlan': idPlan,
      'expiryDays': expiryDays,
      'allowCopy': allowCopy,
    });
    return CreatedTripShare.fromJson(data);
  }

  Future<List<TripShareLink>> listShareLinks({String? idPlan}) async {
    final data = await _shareInvoke(<String, Object?>{
      'action': 'list',
      if (idPlan != null && idPlan.trim().isNotEmpty) 'idPlan': idPlan.trim(),
    });
    final raw = data['links'] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TripShareLink.fromJson)
        .toList();
  }

  Future<void> revokeShareLink(String idShare) async {
    await _shareInvoke(<String, Object?>{
      'action': 'revoke',
      'idShare': idShare,
    });
  }

  Future<String> copySharedPlan(String token) async {
    final data = await _shareInvoke(<String, Object?>{
      'action': 'copy',
      'token': token,
    });
    return data['id_plan'] as String;
  }

  Future<PublicSharedTrip> getPublicSharedPlan(String token) async {
    final Uri uri = Uri.parse(
      '${Env.supabaseUrl}/functions/v1/${Env.tripShareFunction}/public/'
      '${Uri.encodeComponent(token.trim())}',
    );
    final http.Response response;
    try {
      response = await _httpClient
          .get(
            uri,
            headers: const <String, String>{'apikey': Env.supabaseAnonKey},
          )
          .timeout(const Duration(seconds: 25));
    } catch (error) {
      throw SupabaseFunctionException(
        'Could not load the shared trip. Please try again.',
        details: error,
      );
    }

    final Object? decoded = jsonDecode(response.body);
    final Map<String, dynamic> data = decoded is Map
        ? decoded.map(
            (Object? key, Object? value) => MapEntry(key.toString(), value),
          )
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupabaseFunctionException(
        data['error']?.toString() ?? 'Shared trip is unavailable.',
        details: data,
      );
    }
    return PublicSharedTrip.fromJson(data);
  }

  Future<Map<String, dynamic>> _shareInvoke(Map<String, Object?> body) {
    return _functionClient.invokeJson(
      Env.tripShareFunction,
      body: body,
      requireAuth: true,
      timeout: const Duration(seconds: 30),
    );
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
