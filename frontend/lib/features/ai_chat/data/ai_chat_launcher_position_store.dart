import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AiChatLauncherPosition {
  const AiChatLauncherPosition({required this.x, required this.y});

  static const AiChatLauncherPosition fallback = AiChatLauncherPosition(
    x: 1,
    y: 0.62,
  );

  final double x;
  final double y;

  AiChatLauncherPosition normalized() {
    return AiChatLauncherPosition(
      x: x.clamp(0, 1).toDouble(),
      y: y.clamp(0, 1).toDouble(),
    );
  }
}

class AiChatLauncherPositionStore {
  static const String _storageKey = 'ai_chat_launcher_position_v1';

  Future<AiChatLauncherPosition> load() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? encoded = preferences.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) {
      return AiChatLauncherPosition.fallback;
    }

    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        return AiChatLauncherPosition.fallback;
      }
      final Object? rawX = decoded['x'];
      final Object? rawY = decoded['y'];
      if (rawX is! num || rawY is! num) {
        return AiChatLauncherPosition.fallback;
      }
      return AiChatLauncherPosition(
        x: rawX.toDouble(),
        y: rawY.toDouble(),
      ).normalized();
    } on FormatException {
      return AiChatLauncherPosition.fallback;
    }
  }

  Future<void> save(AiChatLauncherPosition position) async {
    final AiChatLauncherPosition normalized = position.normalized();
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(<String, double>{'x': normalized.x, 'y': normalized.y}),
    );
  }
}
