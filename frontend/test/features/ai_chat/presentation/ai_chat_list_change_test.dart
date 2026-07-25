import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_chat/presentation/ai_chat_list_change.dart';

void main() {
  test('detects older messages prepended to the existing list', () {
    expect(
      detectAiChatListChange(
        previousIds: const <String>['m3', 'm4'],
        currentIds: const <String>['m1', 'm2', 'm3', 'm4'],
      ),
      AiChatListChange.prepended,
    );
  });

  test('detects a newly appended exchange', () {
    expect(
      detectAiChatListChange(
        previousIds: const <String>['m1', 'm2'],
        currentIds: const <String>['m1', 'm2', 'm3'],
      ),
      AiChatListChange.appended,
    );
  });

  test('treats optimistic replacement plus answer as appended', () {
    expect(
      detectAiChatListChange(
        previousIds: const <String>['local:request-1'],
        currentIds: const <String>['user-1', 'assistant-1'],
      ),
      AiChatListChange.appended,
    );
  });

  test('auto-scrolls only when the viewport is near the latest message', () {
    expect(
      shouldAutoScrollAiChatAppend(currentOffset: 860, maxScrollExtent: 1000),
      isTrue,
    );
    expect(
      shouldAutoScrollAiChatAppend(currentOffset: 400, maxScrollExtent: 1000),
      isFalse,
    );
  });
}
