# App-wide Currency Synchronization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every customer-facing monetary value react to the currency selected on the Currency page while preserving source values and keeping Stripe settlement in USD.

**Architecture:** Add a pure `MoneyAmount`/converter/formatter layer and a root `CurrencyScope` backed by the existing `CurrencyRepository`. Feature boundaries declare source currencies, then render through the shared formatter; AI price responses become structured while retaining legacy compatibility.

**Tech Stack:** Flutter 3.38.9, Dart 3.10.8, Supabase, Deno Edge Functions, `flutter_test`.

## Global Constraints

- Do not modify Admin screens, Admin form semantics, or stored source amounts.
- Treat Trip and Recommend prices as VND, Explore prices as USD, and subscription/payment amounts as USD cents.
- Keep Stripe Checkout, voucher validation, payment records, and settlement currency in USD.
- Use cached rates when live refresh fails; without a usable rate, display the source amount and source currency.
- Follow red-green-refactor for every production change.
- Preserve unrelated working-tree changes, including `.vscode/launch.json`.

---

### Task 1: Pure money model, conversion, and formatting

**Files:**
- Create: `frontend/lib/core/currency/app_money.dart`
- Create: `frontend/test/core/currency/app_money_test.dart`

**Interfaces:**
- Consumes: USD-based rate maps where `1 USD = rate[currency]`.
- Produces: `CurrencyCatalogEntry`, `MoneyAmount`, `MoneyFormatResult`, and `AppMoneyFormatter`.

- [ ] **Step 1: Write failing conversion and fallback tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/currency/app_money.dart';

void main() {
  const rates = <String, double>{
    'USD': 1,
    'VND': 25000,
    'EUR': 0.92,
  };

  test('converts USD cents to zero-decimal VND', () {
    final formatter = AppMoneyFormatter(
      selectedCurrencyCode: 'VND',
      usdRates: rates,
    );
    final result = formatter.convert(const MoneyAmount('USD', 1800));
    expect(result.displayAmount, const MoneyAmount('VND', 450000));
    expect(formatter.format(const MoneyAmount('USD', 1800)), '450,000 ₫');
  });

  test('converts cross currency through the USD base', () {
    final formatter = AppMoneyFormatter(
      selectedCurrencyCode: 'EUR',
      usdRates: rates,
    );
    expect(
      formatter.convert(const MoneyAmount('VND', 250000)).displayAmount,
      const MoneyAmount('EUR', 920),
    );
  });

  test('falls back to the source currency when a rate is unavailable', () {
    final formatter = AppMoneyFormatter(
      selectedCurrencyCode: 'EUR',
      usdRates: const <String, double>{'USD': 1},
    );
    final result = formatter.convert(const MoneyAmount('VND', 800000));
    expect(result.usedSourceFallback, isTrue);
    expect(formatter.format(result.sourceAmount), '800,000 ₫');
  });
}
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run: `cd frontend; flutter test test/core/currency/app_money_test.dart`

Expected: compilation fails because `core/currency/app_money.dart` and its types do not exist.

- [ ] **Step 3: Implement the minimal pure API**

```dart
class MoneyAmount {
  const MoneyAmount(this.currencyCode, this.minorUnits);

  final String currencyCode;
  final int minorUnits;

  factory MoneyAmount.fromMajor(String code, num amount) {
    final spec = CurrencyCatalog.entryFor(code);
    final scale = spec.minorUnitScale;
    return MoneyAmount(spec.code, (amount * scale).round());
  }
}

class AppMoneyFormatter {
  const AppMoneyFormatter({
    required this.selectedCurrencyCode,
    required this.usdRates,
  });

  final String selectedCurrencyCode;
  final Map<String, double> usdRates;

  MoneyFormatResult convert(MoneyAmount source) {
    // Normalize the source to USD major units, multiply by the target rate,
    // and round once to the target minor-unit scale.
  }

  String format(MoneyAmount source, {bool approximateWhenConverted = false}) {
    // Use CurrencyCatalog grouping, symbol placement, and fraction digits.
  }

  String formatWithCode(MoneyAmount source) {
    // Produce an exact settlement label such as `USD 18.00`.
  }

  String formatRange(MoneyAmount? minimum, MoneyAmount? maximum) {
    // Convert both endpoints with the same rate map.
  }
}
```

Implement `CurrencyCatalogEntry` and catalog entries for all currencies already listed by `CurrencyRepository`, with exponents `0` for VND/JPY/KRW and `2` for the others. Reject non-positive or non-finite rates and add equality/hashCode to value objects for tests.

- [ ] **Step 4: Add tests for negative values, ranges, rounding, and shared symbols**

Add assertions that USD `1999` formats as `$19.99`, AUD uses `A$`, and a VND range converts both endpoints. Run the focused test until all cases pass.

- [ ] **Step 5: Commit the pure currency layer**

```powershell
git add frontend/lib/core/currency/app_money.dart frontend/test/core/currency/app_money_test.dart
git commit -m "feat: add shared money conversion and formatting"
```

---

### Task 2: Move shared currency contracts to core and initialize them globally

**Files:**
- Create: `frontend/lib/core/currency/currency_controller.dart`
- Create: `frontend/lib/core/currency/currency_scope.dart`
- Modify: `frontend/lib/features/profile/data/currency_service.dart`
- Modify: `frontend/lib/app/app_bootstrap.dart`
- Modify: `frontend/lib/app/app.dart`
- Modify: `frontend/test/app/app_bootstrap_loading_test.dart`
- Create: `frontend/test/core/currency/currency_scope_test.dart`

**Interfaces:**
- Consumes: `CurrencyRepository`, `CurrencyRatesSnapshot`, and `AppMoneyFormatter` from Task 1.
- Produces: `CurrencyScope.of(context)`, `context.moneyFormatter`, and startup-ready currency state.

- [ ] **Step 1: Write failing scope and bootstrap tests**

```dart
testWidgets('CurrencyScope rebuilds dependent money when selection changes',
    (tester) async {
  final controller = FakeCurrencyController(selectedCode: 'USD', rates: rates);
  await tester.pumpWidget(
    CurrencyScope(
      controller: controller,
      child: Builder(
        builder: (context) => Text(
          context.moneyFormatter.format(const MoneyAmount('USD', 1800)),
        ),
      ),
    ),
  );
  expect(find.text(r'$18.00'), findsOneWidget);
  controller.selectForTest('VND');
  await tester.pump();
  expect(find.text('450,000 ₫'), findsOneWidget);
});
```

Extend the bootstrap test's injected initializer/controller seam and assert currency initialization completes before the ready app is shown.

- [ ] **Step 2: Run the focused tests and confirm RED**

Run: `cd frontend; flutter test test/core/currency/currency_scope_test.dart test/app/app_bootstrap_loading_test.dart`

Expected: `CurrencyScope` and the context extension are missing, and bootstrap has no currency initialization.

- [ ] **Step 3: Move contracts without changing repository behavior**

Delete the duplicate `CurrencyCatalogEntry` definition from `currency_service.dart` and use the core catalog entry from Task 1. Move `CurrencyRatesSnapshot`, `CurrencyController`, and `CurrencyOptionViewModel` into `core/currency/currency_controller.dart`. Re-export the core contracts from `currency_service.dart` so existing Currency-page imports remain source-compatible.

Create an `InheritedNotifier<CurrencyController>`:

```dart
class CurrencyScope extends InheritedNotifier<CurrencyController> {
  const CurrencyScope({
    super.key,
    required CurrencyController controller,
    required super.child,
  }) : super(notifier: controller);

  static CurrencyController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrencyScope>()!.notifier!;
}

extension CurrencyBuildContext on BuildContext {
  AppMoneyFormatter get moneyFormatter {
    final controller = CurrencyScope.of(this);
    return AppMoneyFormatter(
      selectedCurrencyCode: controller.selectedCurrencyCode,
      usdRates: controller.snapshot?.rates ?? const <String, double>{},
    );
  }
}
```

- [ ] **Step 4: Initialize and install the root scope**

Call `await CurrencyRepository.instance.initialize()` in production bootstrap after local storage and language initialization. Wrap `MaterialApp.router` with `CurrencyScope(controller: CurrencyRepository.instance, ...)` in `app.dart`.

- [ ] **Step 5: Run Currency page, scope, and bootstrap tests**

Run: `cd frontend; flutter test test/core/currency test/features/profile/data/currency_service_test.dart test/features/profile/presentation/currency_page_test.dart test/app/app_bootstrap_loading_test.dart`

Expected: all selected tests pass and existing cache/account persistence behavior remains unchanged.

- [ ] **Step 6: Commit global currency state**

```powershell
git add frontend/lib/core/currency frontend/lib/features/profile/data/currency_service.dart frontend/lib/app/app_bootstrap.dart frontend/lib/app/app.dart frontend/test/core/currency frontend/test/app/app_bootstrap_loading_test.dart
git commit -m "feat: initialize reactive currency state app-wide"
```

---

### Task 3: Synchronize Trip, Recommend, and Explore monetary surfaces

**Files:**
- Modify: `frontend/lib/features/planner/presentation/trip_budget_page.dart`
- Modify: `frontend/lib/features/planner/presentation/trip_day_detail_page.dart`
- Modify: `frontend/lib/features/recommend/presentation/recommended_place_detail_page.dart`
- Modify: `frontend/lib/features/explore/presentation/widgets/destination_card.dart`
- Create: `frontend/test/features/currency/customer_travel_currency_test.dart`

**Interfaces:**
- Consumes: `context.moneyFormatter`, VND major-unit place prices, and USD major-unit Explore prices.
- Produces: selected-currency budget input, price ranges, and per-night prices.

- [ ] **Step 1: Write failing representative widget tests**

Pump each surface under a fake `CurrencyScope` selected to USD or VND. Assert:

```dart
expect(find.textContaining('32.00'), findsOneWidget); // 800,000 VND at 25,000
expect(find.textContaining('From $4.00'), findsOneWidget); // 100,000 VND
expect(find.text(r'$120.00'), findsOneWidget); // Explore USD source
```

Change the fake selection after the first pump and verify dependent text updates without reconstructing the page.

- [ ] **Step 2: Run the new widget test and confirm RED**

Run: `cd frontend; flutter test test/features/currency/customer_travel_currency_test.dart`

Expected: existing screens still render literal `VND`/`$` values and do not react to the scope.

- [ ] **Step 3: Replace feature-local formatters**

Use these source mappings:

```dart
final price = MoneyAmount.fromMajor('VND', minimumPrice);
final hotelNight = MoneyAmount.fromMajor('USD', destination.pricePerNight);
final label = context.moneyFormatter.format(price);
```

Delete `_formatVnd` from Trip Detail and Recommend. Replace the Explore dollar interpolation with the shared formatter. Preserve non-money suffixes such as `night` and localized `From`/`Up to` copy.

- [ ] **Step 4: Make Trip budget input selected-currency aware**

Format typed digits using the selected currency's exponent and symbol/code. Parse the numeric portion as a selected-currency `MoneyAmount`; expose a conversion-to-VND helper at the request boundary without changing existing qualitative presets. Update the example hint from a literal VND sentence to a generated selected-currency example.

- [ ] **Step 5: Run planner and customer-travel tests**

Run: `cd frontend; flutter test test/features/currency/customer_travel_currency_test.dart test/features/planner/presentation`

Expected: all tests pass and travel-time/planner behavior is unchanged.

- [ ] **Step 6: Commit travel currency integration**

```powershell
git add frontend/lib/features/planner frontend/lib/features/recommend/presentation/recommended_place_detail_page.dart frontend/lib/features/explore/presentation/widgets/destination_card.dart frontend/test/features/currency/customer_travel_currency_test.dart
git commit -m "feat: sync travel prices with selected currency"
```

---

### Task 4: Add structured AI Recognition prices with legacy compatibility

**Files:**
- Modify: `backend/supabase/functions/ai-search/recognition_prompt.ts`
- Modify: `backend/supabase/functions/ai-search/recognition_contract.ts`
- Modify: `backend/supabase/functions/ai-search/recognition_contract_test.ts`
- Modify: `frontend/lib/features/ai_search/domain/ai_recognition_result.dart`
- Modify: `frontend/lib/features/ai_search/presentation/widgets/ai_recognition_result_sections.dart`
- Modify: `frontend/test/features/ai_search/presentation/ai_recognition_result_sections_test.dart`
- Modify: `frontend/test/features/ai_search/data/ai_search_service_test.dart`

**Interfaces:**
- Consumes: new optional AI fields `price_min`, `price_max`, and `currency_code`, plus legacy `price_range`.
- Produces: `AiRecognitionPrice? price`, legacy JSON compatibility, and selected-currency typical-price rendering.

- [ ] **Step 1: Write failing Deno contract tests**

```ts
Deno.test("normalizes structured recognition price fields", () => {
  const result = normalizeRecognitionResult({
    price_range: "40000-70000 VND",
    price_min: 40000,
    price_max: 70000,
    currency_code: "vnd",
  });
  assertEquals(result.price_min, 40000);
  assertEquals(result.price_max, 70000);
  assertEquals(result.currency_code, "VND");
});
```

- [ ] **Step 2: Run the contract test and confirm RED**

Run: `npx --yes deno@2.5.6 test --config backend/supabase/functions/ai-search/deno.json backend/supabase/functions/ai-search/recognition_contract_test.ts`

Expected: structured fields are absent from the contract.

- [ ] **Step 3: Extend the prompt schema and normalizer**

Add nullable numeric fields and an uppercase three-letter currency field. Instruct the model to report Vietnamese local prices in VND unless a reliable source currency is explicit. Keep `price_range` required for old clients.

- [ ] **Step 4: Write failing Flutter model and widget tests**

Add `AiRecognitionPrice(minimum, maximum, currencyCode)` expectations for new JSON. Add legacy parser cases for `40,000-70,000 VND`, and assert unparseable strings remain unchanged. Pump the result section under a USD `CurrencyScope` and expect a converted range.

- [ ] **Step 5: Implement frontend structured/legacy mapping**

Prefer structured fields. For old history, accept only conservative patterns containing one currency code and one or two numeric endpoints; never infer a currency when the code is absent.

- [ ] **Step 6: Run backend and frontend AI tests**

Run:

```powershell
npx --yes deno@2.5.6 test --config backend/supabase/functions/ai-search/deno.json backend/supabase/functions/ai-search/recognition_contract_test.ts
cd frontend
flutter test test/features/ai_search
```

Expected: all AI contract, repository, history, and presentation tests pass.

- [ ] **Step 7: Commit structured AI prices**

```powershell
git add backend/supabase/functions/ai-search frontend/lib/features/ai_search frontend/test/features/ai_search
git commit -m "feat: structure and convert AI recognition prices"
```

---

### Task 5: Synchronize Premium display while preserving USD settlement

**Files:**
- Modify: `frontend/lib/features/profile/data/subscription_repository.dart`
- Modify: `frontend/lib/features/profile/presentation/upgrade_account_page.dart`
- Modify: `frontend/lib/features/profile/presentation/upgrade_payment_page.dart`
- Modify: `frontend/test/features/profile/data/subscription_repository_test.dart`
- Modify: `frontend/test/features/profile/presentation/upgrade_account_entitlement_test.dart`
- Create: `frontend/test/features/profile/presentation/subscription_currency_display_test.dart`

**Interfaces:**
- Consumes: USD-cent plan, voucher, checkout, and history amounts.
- Produces: selected-currency display labels and exact `Stripe charge: USD …` settlement labels.

- [ ] **Step 1: Write failing display and safety tests**

Pump Upgrade Account and Payment under a VND scope and assert the selected equivalent appears. Assert the confirmation review also contains the exact USD settlement line.

Extend repository tests to capture the Edge Function request and assert it remains:

```dart
expect(body, <String, dynamic>{
  'action': 'create_checkout',
  'planCode': '6m',
  'voucherCode': 'LOY-TEST',
  'platform': 'android',
  'webOrigin': null,
});
```

No selected display currency or client-calculated amount may be added to the payment request.

- [ ] **Step 2: Run Premium tests and confirm RED**

Run: `cd frontend; flutter test test/features/profile/presentation/subscription_currency_display_test.dart test/features/profile/data/subscription_repository_test.dart`

Expected: Premium still renders hard-coded USD and lacks the settlement disclosure.

- [ ] **Step 3: Remove presentation labels from repository models**

Keep `priceMinor`, `amountMinor`, and `currency` as source data. Remove or stop using `_money`, `priceLabel`, and `amountLabel`; render them through `context.moneyFormatter` at widget boundaries.

- [ ] **Step 4: Convert every Premium monetary surface**

Replace `_SubscriptionPlan.price` strings with USD cents, replace `_formatMoney`, and route plan price, voucher discount, minimum spend, totals, confirmation, success details, and payment history through the shared formatter.

Render the exact settlement value with a formatter pinned to USD rather than the selected target:

```dart
final exactCharge = AppMoneyFormatter.sourceOnly()
    .formatWithCode(MoneyAmount('USD', data.finalAmountMinor));
Text('Stripe charge: $exactCharge');
```

- [ ] **Step 5: Run all profile payment tests**

Run: `cd frontend; flutter test test/features/profile/data/subscription_repository_test.dart test/features/profile/presentation/upgrade_account_entitlement_test.dart test/features/profile/presentation/subscription_currency_display_test.dart`

Expected: display tests pass and checkout payload assertions prove USD settlement is unchanged.

- [ ] **Step 6: Commit Premium display conversion**

```powershell
git add frontend/lib/features/profile/data/subscription_repository.dart frontend/lib/features/profile/presentation/upgrade_account_page.dart frontend/lib/features/profile/presentation/upgrade_payment_page.dart frontend/test/features/profile
git commit -m "feat: convert Premium prices for display only"
```

---

### Task 6: Structure Voucher and Rank monetary copy

**Files:**
- Modify: `frontend/lib/features/profile/presentation/voucher_page.dart`
- Modify: `frontend/lib/features/profile/presentation/voucher_detail_page.dart`
- Modify: `frontend/lib/features/profile/presentation/rank_benefits_page.dart`
- Modify: `frontend/lib/app/router.dart`
- Modify: `frontend/lib/core/language/app_language.dart`
- Create: `frontend/test/features/profile/presentation/voucher_currency_test.dart`
- Create: `frontend/test/features/profile/presentation/rank_benefits_currency_test.dart`

**Interfaces:**
- Consumes: structured USD thresholds/discounts and existing non-money localized copy.
- Produces: dynamic voucher titles/descriptions and rank thresholds in the selected currency.

- [ ] **Step 1: Write failing voucher and rank widget tests**

Under a VND scope with `1 USD = 25,000 VND`, assert `$5 off on orders over $20` becomes a localized title containing `125,000 ₫` and `500,000 ₫`. Assert the Silver benefit contains the converted equivalent of USD 20.

- [ ] **Step 2: Run tests and confirm RED**

Run: `cd frontend; flutter test test/features/profile/presentation/voucher_currency_test.dart test/features/profile/presentation/rank_benefits_currency_test.dart`

Expected: static dollar strings remain visible.

- [ ] **Step 3: Replace embedded money with structured terms**

Add small presentation data types whose monetary fields are `MoneyAmount`, for example:

```dart
class VoucherMoneyTerms {
  const VoucherMoneyTerms({this.discount, this.minimumOrder, this.maximumDiscount});
  final MoneyAmount? discount;
  final MoneyAmount? minimumOrder;
  final MoneyAmount? maximumDiscount;
}
```

Generate monetary clauses at build time and pass already formatted values into localization helpers. Keep free shipping, gifts, percentages, points, tokens, and expiry dates unchanged.

- [ ] **Step 4: Remove obsolete dollar translations and router fallback copy**

Replace exact dollar-bearing translation keys with parameterized helpers. Update the voucher-detail fallback payload in `router.dart` to structured monetary terms rather than dollar text.

- [ ] **Step 5: Run voucher, rank, language, and router tests**

Run: `cd frontend; flutter test test/features/profile/presentation/voucher_currency_test.dart test/features/profile/presentation/rank_benefits_currency_test.dart test/core/language`

Expected: both languages retain their copy while all monetary fragments follow the selected currency.

- [ ] **Step 6: Commit structured monetary copy**

```powershell
git add frontend/lib/features/profile/presentation/voucher_page.dart frontend/lib/features/profile/presentation/voucher_detail_page.dart frontend/lib/features/profile/presentation/rank_benefits_page.dart frontend/lib/app/router.dart frontend/lib/core/language/app_language.dart frontend/test/features/profile/presentation/voucher_currency_test.dart frontend/test/features/profile/presentation/rank_benefits_currency_test.dart
git commit -m "feat: sync voucher and rank money copy"
```

---

### Task 7: Add hard-code guard and complete verification

**Files:**
- Create: `frontend/test/core/currency/customer_currency_hardcode_test.dart`
- Modify: `docs/superpowers/specs/2026-08-07-app-wide-currency-sync-design.md` only if implementation revealed a documented constraint that changed.

**Interfaces:**
- Consumes: all customer-facing Dart presentation files.
- Produces: a regression guard against new literal monetary formatting and final verification evidence.

- [ ] **Step 1: Write the source guard and confirm it catches current violations**

Scan `lib/features` customer presentation files for:

```dart
final forbidden = <RegExp>[
  RegExp(r"'\\\$[0-9]"),
  RegExp(r'"\\\$[0-9]'),
  RegExp(r"return .* VND['\"]"),
  RegExp(r'_formatVnd\s*\('),
];
```

Allow only `core/currency/app_money.dart`, source-currency declarations, and the explicit `Stripe charge: USD` disclosure. Run the test before the final cleanup and verify it reports any remaining user-facing hard-code.

- [ ] **Step 2: Remove only the violations identified by the guard**

Route remaining customer-facing monetary values through `AppMoneyFormatter`. Do not modify Admin files or non-monetary uses of words such as price level.

- [ ] **Step 3: Run formatting and static analysis**

```powershell
dart format frontend/lib/core/currency frontend/lib/features/planner frontend/lib/features/recommend frontend/lib/features/explore frontend/lib/features/ai_search frontend/lib/features/profile frontend/test/core/currency frontend/test/features/currency frontend/test/features/ai_search frontend/test/features/profile
cd frontend
flutter analyze
```

Expected: formatter exits successfully and analysis reports no errors.

- [ ] **Step 4: Run the full Flutter suite**

Run: `cd frontend; flutter test`

Expected: all Flutter tests pass.

- [ ] **Step 5: Run affected Deno tests**

```powershell
npx --yes deno@2.5.6 test --config backend/supabase/functions/ai-search/deno.json backend/supabase/functions/ai-search/recognition_contract_test.ts
npx --yes deno@2.5.6 test --config backend/supabase/functions/subscription-payment/deno.json --allow-env --allow-net backend/supabase/functions/_shared/stripe_payment_store_test.ts backend/supabase/functions/subscription-payment/subscription_payment_domain_test.ts backend/supabase/functions/subscription-payment/subscription_payment_handler_test.ts
```

Expected: AI contract and Stripe payment tests all pass.

- [ ] **Step 6: Review the final diff and commit the guard/cleanup**

```powershell
git diff --check
git status --short
git add frontend/test/core/currency/customer_currency_hardcode_test.dart
git commit -m "test: guard customer currency formatting"
```

Confirm the diff contains no Admin changes, no selected currency in Stripe request bodies, and no unrelated user files.
