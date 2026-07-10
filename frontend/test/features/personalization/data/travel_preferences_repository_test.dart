import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/core/storage/local_storage.dart' as app_storage;
import 'package:hellovietnam/features/personalization/data/travel_preferences_repository.dart';
import 'package:hellovietnam/features/personalization/domain/travel_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saveCurrentUserPreferences uses shared function client', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await app_storage.LocalStorage.instance.initialize();
    Object? capturedBody;

    final TravelPreferencesRepository repository =
        TravelPreferencesRepository.test(
          currentUserIdProvider: () => 'user-1',
          accessTokenProvider: () => 'session-token',
          functionClient: SupabaseFunctionClient(
            accessTokenProvider: () => 'session-token',
            invoker:
                (
                  String functionName, {
                  Map<String, String>? headers,
                  Object? body,
                }) async {
                  expect(functionName, 'travel-preferences');
                  expect(headers, <String, String>{
                    'Authorization': 'Bearer session-token',
                  });
                  capturedBody = body;
                  return <String, dynamic>{};
                },
          ),
        );

    final UserTravelPreferences preferences = UserTravelPreferences(
      travelStyles: const <TravelStyle>[TravelStyle.food],
      companions: const <TravelCompanion>[TravelCompanion.solo],
      budgetLevel: BudgetLevel.moderate,
      pace: TravelPace.balanced,
      topics: const <InterestTopic>[InterestTopic.streetFood],
      completedAt: DateTime.utc(2026, 7, 9),
    );

    await repository.saveCurrentUserPreferences(preferences);

    expect(capturedBody, <String, Object?>{
      'action': 'saveTravelPreferences',
      'preferences': preferences.toJson(),
    });
  });

  test(
    'saveCurrentUserPreferences maps function errors to StateError',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await app_storage.LocalStorage.instance.initialize();

      final TravelPreferencesRepository repository =
          TravelPreferencesRepository.test(
            currentUserIdProvider: () => 'user-1',
            accessTokenProvider: () => 'session-token',
            functionClient: SupabaseFunctionClient(
              accessTokenProvider: () => 'session-token',
              invoker:
                  (
                    String functionName, {
                    Map<String, String>? headers,
                    Object? body,
                  }) async {
                    return <String, dynamic>{'error': 'SAVE_FAILED'};
                  },
            ),
          );

      final UserTravelPreferences preferences = UserTravelPreferences(
        travelStyles: const <TravelStyle>[TravelStyle.food],
        companions: const <TravelCompanion>[TravelCompanion.solo],
        budgetLevel: BudgetLevel.moderate,
        pace: TravelPace.balanced,
        topics: const <InterestTopic>[InterestTopic.streetFood],
        completedAt: DateTime.utc(2026, 7, 9),
      );

      expect(
        () => repository.saveCurrentUserPreferences(preferences),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            'SAVE_FAILED',
          ),
        ),
      );
    },
  );
}
