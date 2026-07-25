import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/storage/local_storage.dart' as app_storage;
import 'package:hellovietnam/features/profile/presentation/wishlist_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await app_storage.LocalStorage.instance.initialize();
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
    }
  });

  setUp(() async {
    await AppLanguageController.instance.setLanguage(AppLanguage.vietnamese);
  });

  tearDown(() async {
    await AppLanguageController.instance.setLanguage(AppLanguage.english);
  });

  testWidgets('Vietnamese header fits a narrow phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(const WishlistPage()));
    await tester.pump();

    expect(find.text('Danh sách yêu thích'), findsOneWidget);
    expect(find.text('Tất cả danh mục'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('can return from a category filter to all categories', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(const WishlistPage()));
    await tester.pump();

    await tester.tap(find.text('Tất cả danh mục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Món ăn').last);
    await tester.pumpAndSettle();
    expect(find.text('Món ăn'), findsOneWidget);

    await tester.tap(find.text('Món ăn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tất cả danh mục').last);
    await tester.pumpAndSettle();

    expect(find.text('Tất cả danh mục'), findsOneWidget);
  });

  testWidgets('renders a real image preview for a saved item', (
    WidgetTester tester,
  ) async {
    const String previewUrl = 'https://example.com/wishlist-preview.jpg';
    const WishlistItem item = WishlistItem(
      id: 'food-1',
      title: 'Hủ tiếu',
      shortDescription: 'Món ăn địa phương',
      detailDescription: 'Chi tiết',
      highlightsDescription: 'Điểm nổi bật',
      coverImageUrl: previewUrl,
      galleryImageUrls: <String>[],
      mapImageUrl: '',
      rating: 4.5,
      type: WishlistType.food,
    );

    await tester.pumpWidget(_testApp(const WishlistDetailPage(item: item)));
    await tester.pump();

    final Iterable<Image> images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.any(
        (Image image) =>
            image.image is NetworkImage &&
            (image.image as NetworkImage).url == previewUrl,
      ),
      isTrue,
    );
  });
}

Widget _testApp(Widget home) {
  return AppLanguageScope(
    controller: AppLanguageController.instance,
    child: MaterialApp(
      theme: buildTheme(),
      darkTheme: buildDarkTheme(),
      home: home,
    ),
  );
}
