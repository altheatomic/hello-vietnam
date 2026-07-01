import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/trip_plan_request.dart';
import 'models/trip_plan_response.dart';

class TripRepository {
  TripRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // Switch back to Supabase Edge Function when deployed:
  // static const String _functionName = 'trip-planner';
  static const String _cfBaseUrl = 'http://localhost:8000';

  // Hardcoded for demo — replace with real auth when ready.
  static const String _testUserId = 'e4bb33fb-5f1b-49a6-9a00-93c67183afde';

  final SupabaseClient _client;

  String get _userId =>
      _client.auth.currentUser?.id ?? _testUserId;

  Future<TripPlanResponse> planTrip(TripPlanRequest request) async {
    final body = <String, dynamic>{
      'id_user':   _userId,
      'n_days':    request.nDays,
      'sa_runs':   request.saRuns,
      'save_plan': request.savePlan,
    };
    if (request.idProvince != null)   body['id_province'] = request.idProvince;
    if (request.targetLat  != null)   body['target_lat']  = request.targetLat;
    if (request.targetLng  != null)   body['target_lng']  = request.targetLng;
    if (request.startDate  != null)   body['start_date']  = request.startDate;
    if (request.interestOptionIds != null && request.interestOptionIds!.isNotEmpty) {
      body['interest_option_ids'] = request.interestOptionIds;
    }
    final data = await _post('/api/trips/plan', body);
    return TripPlanResponse.fromJson(data);
  }

  Future<TripPlanResponse> getPlan(String idPlan) async {
    final data = await _get('/api/trips/plan/$idPlan', {'id_user': _userId});
    return TripPlanResponse.fromJson(data);
  }

  Future<List<TripPlanSummary>> listPlans() async {
    final data = await _get('/api/trips/plans', {'id_user': _userId});
    final raw  = data['plans'] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TripPlanSummary.fromJson)
        .toList();
  }

  Future<List<NearbyPlace>> getNearbyPlaces(double lat, double lng, {int limit = 3}) async {
    final data = await _get('/api/places/nearby', {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'limit': limit.toString(),
    });
    final raw = data['places'] as List<dynamic>? ?? <dynamic>[];
    return raw.whereType<Map<String, dynamic>>().map(NearbyPlace.fromJson).toList();
  }

  Future<void> savePlan(String idPlan, {String? customTitle}) async {
    await _post('/api/trips/$idPlan/save', <String, dynamic>{
      'id_user': _userId,
      'custom_title': customTitle,
    });
  }

  Future<List<SavedPlanItem>> listSavedPlans() async {
    final data = await _get('/api/trips/saved', {'id_user': _userId});
    final raw  = data['plans'] as List<dynamic>? ?? <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SavedPlanItem.fromJson)
        .toList();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$_cfBaseUrl$path'),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> params,
  ) async {
    final response = await http.get(
      Uri.parse('$_cfBaseUrl$path').replace(queryParameters: params),
    );
    return _parseResponse(response);
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw StateError(
        'cf_service error ${response.statusCode}: ${response.body}',
      );
    }
    final raw = jsonDecode(response.body);
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw StateError('Unexpected response body from cf_service.');
  }
}
