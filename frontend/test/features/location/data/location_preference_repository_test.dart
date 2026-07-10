import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/location/data/location_preference_repository.dart';
import 'package:hellovietnam/features/location/domain/user_location_preference.dart';

void main() {
  test(
    'upsertPreference sends payload through shared function client',
    () async {
      Object? capturedBody;
      Map<String, String>? capturedHeaders;

      final UserLocationPreferenceRepository repository =
          UserLocationPreferenceRepository(
            functionClient: SupabaseFunctionClient(
              accessTokenProvider: () => 'session-token',
              invoker:
                  (
                    String functionName, {
                    Map<String, String>? headers,
                    Object? body,
                  }) async {
                    expect(functionName, 'location-preference');
                    capturedHeaders = headers;
                    capturedBody = body;
                    return <String, dynamic>{};
                  },
            ),
          );

      await repository.upsertPreference(
        UserLocationPreference(
          latitude: 10.7,
          longitude: 106.7,
          approxAddress: 'District 1',
          provinceCity: 'Ho Chi Minh City',
          locationSource: LocationSource.gps,
          updatedAt: DateTime.utc(2026, 7, 9, 10, 30),
        ),
      );

      expect(capturedHeaders, <String, String>{
        'Authorization': 'Bearer session-token',
      });
      expect(capturedBody, <String, Object?>{
        'action': 'upsertLocationPreference',
        'preference': <String, Object?>{
          'latitude': 10.7,
          'longitude': 106.7,
          'approxAddress': 'District 1',
          'provinceCity': 'Ho Chi Minh City',
          'locationSource': 'gps',
          'updatedAt': '2026-07-09T10:30:00.000Z',
        },
      });
    },
  );

  test('upsertPreference keeps location-specific auth error message', () async {
    final UserLocationPreferenceRepository repository =
        UserLocationPreferenceRepository(
          functionClient: SupabaseFunctionClient(
            accessTokenProvider: () => null,
            invoker:
                (
                  String functionName, {
                  Map<String, String>? headers,
                  Object? body,
                }) async {
                  fail('Missing auth should stop before invoking function.');
                },
          ),
        );

    expect(
      () => repository.upsertPreference(
        UserLocationPreference(
          locationSource: LocationSource.manual,
          updatedAt: DateTime.utc(2026, 7, 9),
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          'Please sign in to save your location preference.',
        ),
      ),
    );
  });
}
