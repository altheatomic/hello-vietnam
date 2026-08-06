import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/admin/data/admin_food_repository.dart';
import 'package:hellovietnam/features/admin/domain/admin_food.dart';
import 'package:hellovietnam/features/admin/presentation/pages/admin_food_page.dart';

void main() {
  testWidgets('shows a retryable error instead of an empty food state', (
    tester,
  ) async {
    final repository = _FakeAdminFoodRepository(
      foodError: StateError('network unavailable'),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load food items'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No food items match your search.'), findsNothing);

    repository
      ..foodError = null
      ..foodPage = const AdminFoodPageResult(
        foods: <AdminFood>[
          AdminFood(
            id: 'food-1',
            name: 'Pho',
            typeId: 'type-1',
            city: 'Ha Noi',
          ),
        ],
        totalCount: 1,
      );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Pho'), findsOneWidget);
    expect(find.byTooltip('Archive'), findsOneWidget);
    expect(find.textContaining('Could not load food items'), findsNothing);
  });

  testWidgets('renders food even when the type request fails', (tester) async {
    final repository = _FakeAdminFoodRepository(
      foodPage: const AdminFoodPageResult(
        foods: <AdminFood>[
          AdminFood(
            id: 'food-1',
            name: 'Bun bo Hue',
            typeId: 'type-1',
            city: 'Hue',
          ),
        ],
        totalCount: 1,
      ),
      typeError: StateError('type service unavailable'),
    );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Bun bo Hue'), findsOneWidget);
    expect(find.textContaining('Could not load food items'), findsNothing);
  });

  testWidgets('loading layout fits a narrow admin viewport', (tester) async {
    final foodCompleter = Completer<AdminFoodPageResult>();
    final typeCompleter = Completer<List<FoodType>>();
    final repository = _FakeAdminFoodRepository(
      foodFuture: foodCompleter.future,
      typeFuture: typeCompleter.future,
    );

    await tester.pumpWidget(_testApp(repository, width: 640));
    await tester.pump();

    expect(tester.takeException(), isNull);

    foodCompleter.complete(
      const AdminFoodPageResult(foods: <AdminFood>[], totalCount: 0),
    );
    typeCompleter.complete(const <FoodType>[]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(AdminFoodRepository repository, {double width = 1200}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: 900,
        child: SingleChildScrollView(
          child: AdminFoodPage(repository: repository),
        ),
      ),
    ),
  );
}

class _FakeAdminFoodRepository extends AdminFoodRepository {
  _FakeAdminFoodRepository({
    this.foodPage = const AdminFoodPageResult(
      foods: <AdminFood>[],
      totalCount: 0,
    ),
    this.foodError,
    this.typeError,
    this.foodFuture,
    this.typeFuture,
  }) : super(
         functionClient: SupabaseFunctionClient(
           invoker:
               (
                 String functionName, {
                 Map<String, String>? headers,
                 Object? body,
               }) async => <String, dynamic>{},
         ),
       );

  AdminFoodPageResult foodPage;
  Object? foodError;
  Object? typeError;
  Future<AdminFoodPageResult>? foodFuture;
  Future<List<FoodType>>? typeFuture;

  @override
  Future<AdminFoodPageResult> fetchFoods({
    String language = 'en',
    required int page,
    required int pageSize,
    String query = '',
    String? typeId,
    String? sortField,
    String? sortDirection,
  }) async {
    if (foodFuture case final future?) return future;
    if (foodError case final error?) throw error;
    return foodPage;
  }

  @override
  Future<List<FoodType>> fetchFoodTypes({
    String language = 'en',
    bool forceRefresh = false,
  }) async {
    if (typeFuture case final future?) return future;
    if (typeError case final error?) throw error;
    return const <FoodType>[];
  }
}
