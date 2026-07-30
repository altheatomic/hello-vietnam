import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/home/application/home_content_controller.dart';
import 'package:hellovietnam/features/home/data/home_repository.dart';
import 'package:hellovietnam/features/home/domain/destination.dart';
import 'package:hellovietnam/features/home/domain/dish.dart';
import 'package:hellovietnam/features/recommend/domain/recommend_destination.dart';

void main() {
  HomeFeaturedContent realFeatured() {
    return const HomeFeaturedContent(
      destinations: <Destination>[
        Destination(
          id: 'province-1',
          name: 'Ha Tinh',
          category: 'North Central',
          rating: 4.75,
          reviewCount: 8,
          imagePath: 'https://media.example.test/ha-tinh.jpg',
        ),
      ],
      dishes: <Dish>[],
    );
  }

  RecommendDestination realCandidate(String id) {
    return RecommendDestination(
      id: id,
      name: 'Ha Tinh',
      shortDescription: 'Coastal province',
      description: 'A real recommendation candidate',
      imagePath: 'https://media.example.test/ha-tinh.jpg',
      rating: 0,
      avgRating: 4.75,
      reviewCount: 8,
    );
  }

  test('loads featured content and candidates independently', () async {
    final HomeContentController controller = HomeContentController(
      loadFeatured: () async => realFeatured(),
      loadCandidates: () async => <RecommendDestination>[realCandidate('p1')],
      clock: () => DateTime.utc(2026, 7, 27, 8),
    );
    addTearDown(controller.dispose);

    await controller.loadInitial();

    expect(controller.featured, isNotNull);
    expect(controller.candidates?.single.id, 'p1');
    expect(controller.featuredError, isNull);
    expect(controller.personalizedError, isNull);
    expect(controller.isInitialLoading, isFalse);
  });

  test('retains successful featured data after refresh failure', () async {
    int calls = 0;
    final HomeFeaturedContent original = realFeatured();
    final HomeContentController controller = HomeContentController(
      loadFeatured: () async {
        calls += 1;
        if (calls == 1) return original;
        throw StateError('offline');
      },
      loadCandidates: () async => const <RecommendDestination>[],
    );
    addTearDown(controller.dispose);

    await controller.loadInitial();
    final HomeRefreshOutcome outcome = await controller.refreshAll();

    expect(controller.featured, same(original));
    expect(outcome.featuredError, isA<StateError>());
  });

  test(
    'foreground refresh waits for the two-minute freshness window',
    () async {
      DateTime now = DateTime.utc(2026, 7, 27, 8);
      int calls = 0;
      final HomeContentController controller = HomeContentController(
        loadFeatured: () async {
          calls += 1;
          return realFeatured();
        },
        loadCandidates: () async => const <RecommendDestination>[],
        clock: () => now,
      );
      addTearDown(controller.dispose);

      await controller.loadInitial();
      now = now.add(const Duration(minutes: 1, seconds: 59));
      await controller.refreshIfStale();
      expect(calls, 1);

      now = now.add(const Duration(seconds: 1));
      await controller.refreshIfStale();
      expect(calls, 2);
    },
  );

  test('deduplicates concurrent full refresh calls', () async {
    final Completer<HomeFeaturedContent> featured =
        Completer<HomeFeaturedContent>();
    final Completer<List<RecommendDestination>> candidates =
        Completer<List<RecommendDestination>>();
    int featuredCalls = 0;
    int candidateCalls = 0;
    final HomeContentController controller = HomeContentController(
      loadFeatured: () {
        featuredCalls += 1;
        return featured.future;
      },
      loadCandidates: () {
        candidateCalls += 1;
        return candidates.future;
      },
    );
    addTearDown(controller.dispose);

    final Future<HomeRefreshOutcome> first = controller.refreshAll();
    final Future<HomeRefreshOutcome> second = controller.refreshAll();
    expect(identical(first, second), isTrue);

    featured.complete(realFeatured());
    candidates.complete(<RecommendDestination>[realCandidate('p1')]);
    await Future.wait(<Future<HomeRefreshOutcome>>[first, second]);

    expect(featuredCalls, 1);
    expect(candidateCalls, 1);
  });
}
