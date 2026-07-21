import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/popular_apps/presentation/popular_apps_detail.dart';

void main() {
  testWidgets('shows the app logo without an outer frame', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PopularAppsDetailPage(appId: 'grab')),
    );
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();

    final Finder grabLogo = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName.endsWith('/grab.webp'),
    );

    expect(grabLogo, findsOneWidget);
    expect(tester.getSize(grabLogo), const Size.square(118));
  });

  testWidgets('opens the official Google Play page externally', (
    WidgetTester tester,
  ) async {
    Uri? openedUri;

    await tester.pumpWidget(
      MaterialApp(
        home: PopularAppsDetailPage(
          appId: 'grab',
          openExternalUrl: (Uri uri) async {
            openedUri = uri;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Open / Download Grab'));
    await tester.pump();

    expect(
      openedUri,
      Uri.parse(
        'https://play.google.com/store/apps/details?id=com.grabtaxi.passenger',
      ),
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('shows an error when Google Play cannot be opened', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PopularAppsDetailPage(
          appId: 'grab',
          openExternalUrl: (_) async => false,
        ),
      ),
    );

    await tester.tap(find.text('Open / Download Grab'));
    await tester.pump();

    expect(find.text('Could not open Google Play for Grab.'), findsOneWidget);
  });

  testWidgets('handles launcher exceptions without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PopularAppsDetailPage(
          appId: 'grab',
          openExternalUrl: (_) async => throw StateError('launcher failed'),
        ),
      ),
    );

    await tester.tap(find.text('Open / Download Grab'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Could not open Google Play for Grab.'), findsOneWidget);
  });
}
