import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/home/presentation/widgets/home_banner.dart';

void main() {
  testWidgets('uses a static banner asset to avoid decoding a large GIF', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, child: HomeBanner()),
        ),
      ),
    );

    final Image image = tester.widget<Image>(find.byType(Image));
    final ResizeImage resizedProvider = image.image as ResizeImage;
    final AssetImage provider = resizedProvider.imageProvider as AssetImage;

    expect(provider.assetName, endsWith('.jpg'));
    expect(provider.assetName, isNot(contains('gif_background.gif')));
  });
}
