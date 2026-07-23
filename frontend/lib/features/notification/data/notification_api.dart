import 'package:hellovietnam/core/network/supabase_function_client.dart';

abstract interface class NotificationApi {
  Future<Map<String, dynamic>> invoke(
    String action, {
    Map<String, Object?> body = const <String, Object?>{},
  });
}

class SupabaseNotificationApi implements NotificationApi {
  SupabaseNotificationApi({SupabaseFunctionClient? functionClient})
    : _functionClient = functionClient ?? SupabaseFunctionClient();

  final SupabaseFunctionClient _functionClient;

  @override
  Future<Map<String, dynamic>> invoke(
    String action, {
    Map<String, Object?> body = const <String, Object?>{},
  }) {
    return _functionClient.invokeJson(
      'notifications',
      requireAuth: true,
      body: <String, Object?>{'action': action, ...body},
    );
  }
}
