import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_chat/data/ai_chat_premium_access_cache.dart';

void main() {
  test('reuses a fresh Premium result for the same user', () async {
    var calls = 0;
    final AiChatPremiumAccessCache cache = AiChatPremiumAccessCache(
      ttl: const Duration(seconds: 30),
      now: () => DateTime.utc(2026, 7, 25, 10),
    );

    Future<bool> loader() async {
      calls++;
      return true;
    }

    expect(await cache.load(userId: 'user-1', loader: loader), isTrue);
    expect(await cache.load(userId: 'user-1', loader: loader), isTrue);
    expect(calls, 1);
  });

  test('deduplicates concurrent checks and keeps users isolated', () async {
    var calls = 0;
    final Completer<bool> pending = Completer<bool>();
    final AiChatPremiumAccessCache cache = AiChatPremiumAccessCache();

    Future<bool> loader() {
      calls++;
      return pending.future;
    }

    final Future<bool> first = cache.load(userId: 'user-1', loader: loader);
    final Future<bool> second = cache.load(userId: 'user-1', loader: loader);
    expect(calls, 1);

    pending.complete(true);
    expect(await Future.wait(<Future<bool>>[first, second]), <bool>[
      true,
      true,
    ]);
    await cache.load(userId: 'user-2', loader: () async => false);
    expect(calls, 1);
  });

  test('refreshes an expired result', () async {
    var now = DateTime.utc(2026, 7, 25, 10);
    var calls = 0;
    final AiChatPremiumAccessCache cache = AiChatPremiumAccessCache(
      ttl: const Duration(seconds: 30),
      now: () => now,
    );

    Future<bool> loader() async {
      calls++;
      return calls > 1;
    }

    expect(await cache.load(userId: 'user-1', loader: loader), isFalse);
    now = now.add(const Duration(seconds: 31));
    expect(await cache.load(userId: 'user-1', loader: loader), isTrue);
    expect(calls, 2);
  });
}
