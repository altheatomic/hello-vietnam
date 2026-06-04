import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/user_location_preference.dart';

class UserLocationPreferenceRepository {
  UserLocationPreferenceRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _functionName = 'location-preference';
  final SupabaseClient _client;

  Future<void> upsertPreference(UserLocationPreference preference) async {
    final Session? session = _client.auth.currentSession;
    if (session == null) {
      throw StateError('Please sign in to save your location preference.');
    }

    final FunctionResponse response = await _client.functions.invoke(
      _functionName,
      headers: <String, String>{'Authorization': 'Bearer ${session.accessToken}'},
      body: <String, dynamic>{
        'action': 'upsertLocationPreference',
        'preference': preference.toRequestJson(),
      },
    );

    final dynamic data = response.data;
    if (data is Map<String, dynamic> && data['error'] != null) {
      throw StateError(data['error'].toString());
    }
  }
}

