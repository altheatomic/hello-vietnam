import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_chat/data/ai_chat_launcher_position_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('returns the fallback position when no position was saved', () async {
    final AiChatLauncherPositionStore store = AiChatLauncherPositionStore();

    final AiChatLauncherPosition position = await store.load();

    expect(position.x, AiChatLauncherPosition.fallback.x);
    expect(position.y, AiChatLauncherPosition.fallback.y);
  });

  test('persists a normalized launcher position', () async {
    final AiChatLauncherPositionStore store = AiChatLauncherPositionStore();

    await store.save(const AiChatLauncherPosition(x: 0.25, y: 0.75));
    final AiChatLauncherPosition position = await store.load();

    expect(position.x, 0.25);
    expect(position.y, 0.75);
  });

  test('clamps invalid coordinates before persisting them', () async {
    final AiChatLauncherPositionStore store = AiChatLauncherPositionStore();

    await store.save(const AiChatLauncherPosition(x: -1, y: 2));
    final AiChatLauncherPosition position = await store.load();

    expect(position.x, 0);
    expect(position.y, 1);
  });
}
