import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/profile/data/currency_service.dart';
import 'package:hellovietnam/features/profile/presentation/currency_page.dart';

void main() {
  testWidgets('shows and persists a selected live exchange rate', (
    WidgetTester tester,
  ) async {
    final _FakeCurrencyController controller = _FakeCurrencyController();
    await tester.pumpWidget(
      MaterialApp(home: CurrencyPage(controller: controller)),
    );
    await tester.pump();

    expect(find.text('1 USD = 1.00 USD'), findsOneWidget);

    await tester.tap(find.byKey(const Key('currency-option-VND')));
    await tester.pump();

    expect(controller.savedCurrencyCode, 'VND');
    expect(find.text('1 USD = 25,600 VND'), findsOneWidget);
  });
}

class _FakeCurrencyController extends ChangeNotifier
    implements CurrencyController {
  String _selectedCode = 'USD';
  String? savedCurrencyCode;

  @override
  bool get isReady => true;

  @override
  bool get isRefreshing => false;

  @override
  bool get isSavingSelection => false;

  @override
  String? get lastError => null;

  @override
  String get selectedCurrencyCode => _selectedCode;

  @override
  CurrencyRatesSnapshot? get snapshot => null;

  @override
  bool get isUsingCache => false;

  @override
  List<CurrencyOptionViewModel> get options => <CurrencyOptionViewModel>[
    CurrencyOptionViewModel(
      entry: const CurrencyCatalogEntry(
        code: 'USD',
        name: 'US Dollar',
        symbol: '\$',
        flagCode: 'us',
      ),
      rate: 1,
      selected: _selectedCode == 'USD',
    ),
    CurrencyOptionViewModel(
      entry: const CurrencyCatalogEntry(
        code: 'VND',
        name: 'Vietnamese Dong',
        symbol: 'VND',
        flagCode: 'vn',
      ),
      rate: 25600,
      selected: _selectedCode == 'VND',
    ),
  ];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> selectCurrency(String currencyCode) async {
    _selectedCode = currencyCode;
    savedCurrencyCode = currencyCode;
    notifyListeners();
  }
}
