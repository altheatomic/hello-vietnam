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
      final data = await _invoke(
        <String, Object?>{
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
        },
        timeout: _planTripTimeout(request.nDays),
      );
      return TripPlanResponse.fromJson(data);
    } on SupabaseFunctionException catch (error) {
      if (error.errorCode == 'no_candidates') {
        throw const NoTripCandidatesException();
      }
      rethrow;
    }
  }

  /// Module 3 (SA route optimisation) is the pipeline's dominant cost and
  /// scales with trip length — observed worst case in production logs:
  /// n_days=2, sa_runs=5 took 65.7s total (63.2s of that in module3 alone).
  /// The prior flat 45s timeout was shorter than that observed case, so the
  /// client gave up and showed an error while the backend went on to save
  /// the plan successfully (Future.timeout() doesn't cancel the underlying
  /// request — see supabase_function_client.dart). 60s base + 20s/day gives
  /// real margin over the observed n_days=2 case (100s vs 65.7s observed,
  /// ~34s headroom) and keeps scaling for longer trips, capped at 180s (3
  /// min) so a genuinely-hung request doesn't leave the user waiting
  /// indefinitely.
  Duration _planTripTimeout(int nDays) {
    final int seconds = (60 + 20 * nDays).clamp(60, 180);
    return Duration(seconds: seconds);
  }

  /// Recovery for the timeout-but-actually-succeeded race above: looks for
  /// a plan this user just created that matches the request's identifying
  /// parameters, created within [within] of now. Matches on id_province +
  /// n_days (duration) + start_date, NOT interest_option_ids — the plan
  /// listing (list_plans() in cf_service/db/queries_plan.py) doesn't return
  /// per-plan interest choices, and adding that would need a second query
  /// per candidate; id_province + n_days + start_date + a tight recency
  /// window is already a very low false-positive risk for one user's own
  /// plan list.
  ///
  /// Business trips (idProvince == null, matched by targetLat/targetLng
  /// instead) can't be matched this way — list_plans() doesn't return
  /// target_lat/target_lng at all — so this only returns a match for
  /// province-based trips. Callers should still fall back to a normal error
  /// message for business trips (or any case this returns null for).
  Future<TripPlanSummary?> findRecentMatchingPlan(
    TripPlanRequest request, {
    Duration within = const Duration(minutes: 10),
  }) async {
    if (request.idProvince == null || request.startDate == null) return null;

    final List<TripPlanSummary> plans = await listPlans();
    final DateTime cutoff = DateTime.now().toUtc().subtract(within);
    final DateTime? wantedStart = DateTime.tryParse(request.startDate!);
    if (wantedStart == null) return null;

    for (final TripPlanSummary plan in plans) {
      if (plan.idProvince != request.idProvince) continue;
      if (plan.duration != request.nDays.toString()) continue;
      final DateTime? planStart = DateTime.tryParse(plan.startAt);
      if (planStart == null ||
          !_isSameDate(planStart, wantedStart)) {
        continue;
      }
      final DateTime? createdAt = DateTime.tryParse(plan.createdAt);
      if (createdAt == null || createdAt.isBefore(cutoff)) continue;
      return plan;
    }
    return null;
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  Future<String> renamePlan(String idPlan, String customTitle) async {
    final data = await _invoke(<String, Object?>{
      'action': 'renamePlan',
      'idPlan': idPlan,
      'customTitle': customTitle,
    });
    return data['custom_title'] as String;
  }

  Future<List<SavedPlanItem>> listSavedPlans() async {
    final data = await _invoke(<String, Object?>{'action': 'listSavedPlans'});
    final raw = data['plans'] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SavedPlanItem.fromJson)
        .toList();
  }

  /// Shifts a saved plan's start_at/end_at when the user starts the trip
  /// later than originally planned, preserving its duration. [newStartAt]
  /// must be an ISO 'YYYY-MM-DD' date string.
  Future<void> rescheduleTrip(String idPlan, String newStartAt) async {
    await _invoke(<String, Object?>{
      'action': 'rescheduleTrip',
      'idPlan': idPlan,
      'newStartAt': newStartAt,
    });
  }

  Future<void> completeTrip(String idPlan) async {
    await _invoke(<String, Object?>{'action': 'completeTrip', 'idPlan': idPlan});
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

  Future<Map<String, dynamic>> _invoke(
    Map<String, Object?> body, {
    Duration timeout = const Duration(seconds: 45),
  }) {
    return _functionClient.invokeJson(
      Env.tripPlannerFunction,
      body: body,
      requireAuth: true,
      timeout: timeout,
    );
  }
}
