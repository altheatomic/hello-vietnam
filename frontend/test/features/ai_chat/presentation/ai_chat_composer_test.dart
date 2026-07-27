import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_chat/presentation/widgets/ai_chat_composer.dart';

void main() {
  testWidgets('keeps the draft when sending fails', (
    WidgetTester tester,
  ) async {
    int sendCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiChatComposer(
            isSending: false,
            onSend: (_) async {
              sendCalls++;
              return false;
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('ai-chat-input')),
      'Keep this draft',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-chat-send')));
    await tester.pumpAndSettle();

    final TextField input = tester.widget<TextField>(
      find.byKey(const Key('ai-chat-input')),
    );
    expect(sendCalls, 1);
    expect(input.controller?.text, 'Keep this draft');
  });

  testWidgets('clears the draft after a successful send', (
    WidgetTester tester,
  ) async {
    int sendCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiChatComposer(
            isSending: false,
            onSend: (_) async {
              sendCalls++;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('ai-chat-input')),
      'Send this draft',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-chat-send')));
    await tester.pumpAndSettle();

    final TextField input = tester.widget<TextField>(
      find.byKey(const Key('ai-chat-input')),
    );
    expect(sendCalls, 1);
    expect(input.controller?.text, isEmpty);
  });

  testWidgets('uses a pale-blue send surface when disabled in light mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: AiChatComposer(isSending: false, onSend: (_) async => true),
        ),
      ),
    );

    final AnimatedContainer surface = tester.widget<AnimatedContainer>(
      find.byKey(const Key('ai-chat-send-surface')),
    );
    final BoxDecoration decoration = surface.decoration! as BoxDecoration;

    expect(decoration.color, isNotNull);
    expect(decoration.color!.computeLuminance(), greaterThan(0.75));
  });
}
