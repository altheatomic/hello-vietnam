import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/popular_apps/data/popular_apps_mock_data.dart';
import 'package:hellovietnam/features/popular_apps/presentation/popular_apps_page.dart';
import 'package:hellovietnam/features/popular_apps/presentation/widgets/popular_apps_category_tabs.dart';

void main() {
  testWidgets('renders the Popular Apps title and compact category controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PopularAppsPage()));

    expect(find.text('Popular Apps'), findsOneWidget);
    expect(find.text('Essential Apps'), findsNothing);
    expect(tester.getSize(find.byType(PopularAppsCategoryTabs)).height, 44);

    final Finder allTapTarget = find.ancestor(
      of: find.text('All'),
      matching: find.byType(GestureDetector),
    );
    final Size allTapTargetSize = tester.getSize(allTapTarget);
    expect(allTapTargetSize.width, greaterThanOrEqualTo(44));
    expect(allTapTargetSize.height, 44);

    final Text selectedLabel = tester.widget<Text>(find.text('All'));
    expect(selectedLabel.style?.color, const Color(0xFF0369A1));
    expect(
      tester.getSemantics(find.text('All')).flagsCollection.isSelected,
      Tristate.isTrue,
    );

    final Finder grabLogo = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName.endsWith('/grab.webp'),
    );
    expect(tester.getSize(grabLogo), const Size.square(64));
  });

  test('uses current Android apps, bundled logos, and Google Play links', () {
    final Set<String> ids = popularAppsItems.map((item) => item.id).toSet();

    expect(ids, containsAll(<String>{'green_sm', 'oneu'}));
    expect(ids, isNot(contains('gojek')));
    expect(ids, isNot(contains('vinid')));
    expect(
      popularAppsItems.every(
        (item) => item.logoUrl.startsWith('assets/images/popular_apps/'),
      ),
      isTrue,
    );
    expect(
      popularAppsPosts.values.every(
        (post) => post.downloadUrl.startsWith(
          'https://play.google.com/store/apps/details?id=',
        ),
      ),
      isTrue,
    );

    final Map<String, String> verifiedDownloads = <String, String>{
      'grab': '100M+',
      'zalo': '100M+',
      'shopeefood': '10M+',
      'green_sm': '10M+',
      'thecoffeehouse': '500K+',
      'tiki': '10M+',
      'momo': '10M+',
      'vinbus': '100K+',
      'foody': '1M+',
      'oneu': '5M+',
      'klook': '10M+',
    };
    expect(<String, String>{
      for (final item in popularAppsItems) item.id: item.downloads,
    }, verifiedDownloads);
  });

  testWidgets('uses dark surfaces for the page and app cards', (
    WidgetTester tester,
  ) async {
    final ThemeData darkTheme = buildDarkTheme();
    await tester.pumpWidget(
      MaterialApp(theme: darkTheme, home: const PopularAppsPage()),
    );

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, darkTheme.scaffoldBackgroundColor);

    final Iterable<Container> darkCards = tester
        .widgetList<Container>(find.byType(Container))
        .where((Container container) {
          final Decoration? decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.color ==
                  darkTheme.colorScheme.surface.withValues(alpha: 0.94);
        });
    expect(darkCards, isNotEmpty);
  });
}
