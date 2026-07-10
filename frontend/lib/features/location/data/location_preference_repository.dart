import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_function_client.dart';
import '../domain/user_location_preference.dart';

class UserLocationPreferenceRepository {
  UserLocationPreferenceRepository({
    SupabaseClient? client,
    SupabaseFunctionClient? functionClient,
  }) : _functionClient =
           functionClient ??
           SupabaseFunctionClient(client: client ?? Supabase.instance.client);

  static const String _functionName = 'location-preference';
  static const String _authErrorMessage =
      'Please sign in to save your location preference.';
  final SupabaseFunctionClient _functionClient;

  Future<void> upsertPreference(UserLocationPreference preference) async {
    try {
      await _functionClient.invokeVoid(
        _functionName,
        requireAuth: true,
        body: <String, Object?>{
          'action': 'upsertLocationPreference',
          'preference': preference.toRequestJson(),
        },
      );
    } on SupabaseFunctionException catch (error) {
      final String message =
          error.message == 'Please sign in before using this feature.'
          ? _authErrorMessage
          : error.message;
      throw StateError(message);
    }
  }
}
