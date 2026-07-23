import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/profile/data/currency_service.dart';
import 'package:hellovietnam/features/profile/presentation/currency_page.dart';

void main() {
  testWidgets('currency header text stays readable in dark mode', (
    WidgetTester tester,
  ) async {
    final ThemeData darkTheme = buildDarkTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: CurrencyPage(controller: _StaticCurrencyController()),
      ),
    );

    final Text title = tester.widget<Text>(find.text('Currency'));
    final Text subtitle = tester.widget<Text>(
      find.text('Select your preferred currency'),
    );

    expect(title.style?.color, darkTheme.colorScheme.onSurface);
    expect(subtitle.style?.color, darkTheme.colorScheme.onSurfaceVariant);
  });
}

class _StaticCurrencyController extends ChangeNotifier
    implements CurrencyController {
  @override
  bool get isReady => true;

  @override
  bool get isRefreshing => false;

  @override
  bool get isSavingSelection => false;

  @override
  bool get isUsingCache => false;

  @override
  String? get lastError => null;

  @override
  List<CurrencyOptionViewModel> get options =>
      const <CurrencyOptionViewModel>[];

  @override
  String get selectedCurrencyCode => 'USD';

  @override
  CurrencyRatesSnapshot? get snapshot => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> selectCurrency(String currencyCode) async {}
}
