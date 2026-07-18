import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/explore/presentation/widgets/explore_category_filter_bar.dart';

void main() {
  testWidgets('renders compact frosted category controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExploreCategoryFilterBar(
            labels: const <String>[
              'ACTIVITIES',
              'CULTURE',
              'FOOD',
              'LOCAL PRODUCTS',
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(ExploreCategoryFilterBar)).height,
      ExploreCategoryFilterBar.height,
    );
    expect(ExploreCategoryFilterBar.height, lessThanOrEqualTo(44));
    expect(tester.getSize(find.byType(InkWell).first).height, 44);
    expect(find.byType(BackdropFilter), findsNWidgets(4));
  });

  testWidgets('notifies when a category is selected', (
    WidgetTester tester,
  ) async {
    int? selectedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExploreCategoryFilterBar(
            labels: const <String>['ACTIVITIES', 'CULTURE'],
            selectedIndex: 0,
            onSelected: (int index) => selectedIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('CULTURE'));

    expect(selectedIndex, 1);
  });
}
