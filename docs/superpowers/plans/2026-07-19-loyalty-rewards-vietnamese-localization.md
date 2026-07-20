# Loyalty Rewards Vietnamese Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Localize every user-facing part of Loyalty Rewards in Vietnamese mode while preserving English copy and all existing loyalty behavior.

**Architecture:** Extend the existing `AppStrings` catalog for static copy and add typed helpers for sentences containing points, tiers, dates, statuses, and other runtime values. Render all Loyalty Rewards copy through `BuildContext.l10n`; add an optional dashboard loader to `LoyaltyPage` solely as a deterministic widget-test seam.

**Tech Stack:** Flutter, Dart, `AppLanguageScope`, `AppStrings`, `flutter_test`, `shared_preferences`

## Global Constraints

- Preserve the current English interface and fallback behavior.
- Do not hardcode Vietnamese strings inside Loyalty Rewards presentation widgets.
- Do not change points, tiers, tokens, redemption, routing, notification persistence, repository behavior, or layout.
- Unknown/custom backend content remains unchanged when no exact system translation exists.
- Preserve unrelated uncommitted changes in `app_language.dart` and all other files.
- Follow red-green-refactor and run the failing test before each production change.

---

### Task 1: Define the complete Loyalty Rewards copy contract

**Files:**
- Create: `frontend/test/core/language/app_language_loyalty_test.dart`
- Modify: `frontend/lib/core/language/app_language.dart`

**Interfaces:**
- Consumes: `AppStrings.of(AppLanguage)` and `AppStrings.ui(String english)`.
- Produces:
  - `String loyaltyHighestTier(String tier)`
  - `String loyaltyTierProgress(int current, int target, String tier)`
  - `String loyaltyCycleEnds(String date)`
  - `String loyaltyEarnSummary(int points, int tierPoints, {required bool requiresApproval, required bool automatic})`
  - `String loyaltyTestPointsAdded(int points)`
  - `String loyaltyVoucherRequirement(int points, String description)`
  - `String loyaltyWalletExpiry(String date)`
  - `String loyaltyTransactionSummary(String status, int pointChange, int tokenChange, String? date)`

- [ ] **Step 1: Write failing static-copy tests**

Create `app_language_loyalty_test.dart` with a table that checks all static sections, actions, statuses, empty states, rule names, and errors:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/core/language/app_language.dart';

void main() {
  const Map<String, String> expectedVietnamese = <String, String>{
    'Loyalty Rewards': 'Điểm thưởng thành viên',
    'Available points': 'Điểm hiện có',
    'Tokens': 'Token',
    'Lifetime points': 'Tổng điểm tích lũy',
    'Loyalty notifications': 'Thông báo điểm thưởng',
    'Only affects points and rewards notifications.':
        'Chỉ áp dụng cho thông báo về điểm và phần thưởng.',
    'Tier progress': 'Tiến trình xếp hạng',
    'Earn points': 'Kiếm điểm',
    'Add item to wishlist': 'Thêm mục vào danh sách yêu thích',
    'Create a forum post': 'Tạo bài viết trên diễn đàn',
    'Submit a review': 'Gửi đánh giá',
    'Check in at a place': 'Check-in tại một địa điểm',
    'Daily login': 'Đăng nhập hằng ngày',
    'Go': 'Đi',
    'Auto': 'Tự động',
    'Redeem': 'Đổi',
    'Add': 'Cộng',
    'Retry': 'Thử lại',
    'Needs review': 'Cần xét duyệt',
    'Automatic': 'Tự động',
    'Exchange points to tokens': 'Đổi điểm thành token',
    'Redeem vouchers': 'Đổi voucher',
    'Voucher wallet': 'Ví voucher',
    'Transaction history': 'Lịch sử giao dịch',
    'No active loyalty vouchers yet.': 'Chưa có voucher điểm thưởng.',
    'Your loyalty voucher wallet is empty.': 'Ví voucher của bạn đang trống.',
    'No loyalty transactions yet.': 'Chưa có giao dịch điểm thưởng.',
    'Load loyalty failed.': 'Không tải được điểm thưởng.',
    'Loading loyalty rewards': 'Đang tải điểm thưởng',
  };

  test('localizes every static Loyalty Rewards label', () {
    final AppStrings strings = AppStrings.of(AppLanguage.vietnamese);
    expectedVietnamese.forEach((String english, String vietnamese) {
      expect(strings.ui(english), vietnamese, reason: english);
    });
  });

  test('preserves every Loyalty Rewards label in English', () {
    final AppStrings strings = AppStrings.of(AppLanguage.english);
    for (final String english in expectedVietnamese.keys) {
      expect(strings.ui(english), english, reason: english);
    }
  });
}
```

Extend this exact map with `Add loyalty for testing`, `Add 500 test points`, `Get 1 token`, `Get 5 tokens`, `pending`, `completed`, `active`, `Gold`, `Platinum`, and every remaining system label found in `loyalty_page.dart`.

- [ ] **Step 2: Write failing dynamic-copy tests**

Add assertions for every typed helper:

```dart
test('localizes dynamic Loyalty Rewards summaries', () {
  final AppStrings strings = AppStrings.of(AppLanguage.vietnamese);

  expect(strings.loyaltyHighestTier('Hạng Vàng'), 'Hạng cao nhất: Hạng Vàng');
  expect(
    strings.loyaltyTierProgress(2155, 3500, 'Bạch kim'),
    '2155/3500 điểm hạng để đạt Bạch kim',
  );
  expect(strings.loyaltyCycleEnds('03/12/2026'), 'Chu kỳ kết thúc: 03/12/2026');
  expect(
    strings.loyaltyEarnSummary(
      20,
      20,
      requiresApproval: true,
      automatic: false,
    ),
    '+20 điểm, +20 điểm hạng · Cần xét duyệt',
  );
  expect(strings.loyaltyTestPointsAdded(500), 'Đã cộng 500 điểm kiểm thử.');
  expect(
    strings.loyaltyVoucherRequirement(200, 'Giảm 10%'),
    '200 điểm · Giảm 10%',
  );
  expect(
    strings.loyaltyWalletExpiry('03/12/2026'),
    'Hết hạn 03/12/2026',
  );
  expect(
    strings.loyaltyTransactionSummary(
      'Đang chờ',
      15,
      0,
      '03/12/2026',
    ),
    'Đang chờ +15 điểm · 03/12/2026',
  );
});
```

Add corresponding English assertions, including `Highest tier: Gold`, `2155/3500 tier points to Platinum`, and the existing punctuation for summaries.

- [ ] **Step 3: Run the copy tests and verify RED**

Run:

```bash
cd frontend
flutter test test/core/language/app_language_loyalty_test.dart
```

Expected: FAIL because most static mappings and all typed Loyalty Rewards helpers are missing.

- [ ] **Step 4: Implement the minimal catalog and typed helpers**

Add the tested mappings to `_viText` without rewriting unrelated entries. Add typed methods near the existing dynamic localization helpers:

```dart
String loyaltyHighestTier(String tier) =>
    _vi ? 'Hạng cao nhất: $tier' : 'Highest tier: $tier';

String loyaltyTierProgress(int current, int target, String tier) => _vi
    ? '$current/$target điểm hạng để đạt $tier'
    : '$current/$target tier points to $tier';

String loyaltyCycleEnds(String date) =>
    _vi ? 'Chu kỳ kết thúc: $date' : 'Cycle ends: $date';

String loyaltyEarnSummary(
  int points,
  int tierPoints, {
  required bool requiresApproval,
  required bool automatic,
}) {
  final String base = _vi
      ? '+$points điểm, +$tierPoints điểm hạng'
      : '+$points points, +$tierPoints tier points';
  final String suffix = requiresApproval
      ? (_vi ? ' · Cần xét duyệt' : ' . Needs review')
      : automatic
          ? (_vi ? ' · Tự động' : ' . Automatic')
          : '';
  return '$base$suffix';
}
```

Implement the remaining tested signatures using the same `_vi ? ... : ...` contract. Preserve the English formatting already displayed by the screen.

```dart
String loyaltyTestPointsAdded(int points) => _vi
    ? 'Đã cộng $points điểm kiểm thử.'
    : 'Added $points test loyalty points.';

String loyaltyVoucherRequirement(int points, String description) => _vi
    ? '$points điểm · $description'
    : '$points points . $description';

String loyaltyWalletExpiry(String date) =>
    _vi ? 'Hết hạn $date' : 'Expires $date';

String loyaltyTransactionSummary(
  String status,
  int pointChange,
  int tokenChange,
  String? date,
) {
  final String points = pointChange == 0
      ? ''
      : ' ${pointChange > 0 ? '+' : ''}$pointChange ${_vi ? 'điểm' : 'pts'}';
  final String tokens = tokenChange == 0
      ? ''
      : ' ${tokenChange > 0 ? '+' : ''}$tokenChange token';
  final String dateSuffix = date == null
      ? ''
      : _vi
          ? ' · $date'
          : ' . $date';
  return '$status$points$tokens$dateSuffix';
}
```

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```bash
cd frontend
flutter test test/core/language/app_language_loyalty_test.dart test/core/language/app_language_review_test.dart
```

Expected: PASS; Loyalty copy is complete and unrelated localization tests remain green.

- [ ] **Step 6: Commit the copy contract**

Stage only new loyalty hunks from the already-dirty localization file:

```bash
git add -p frontend/lib/core/language/app_language.dart
git add frontend/test/core/language/app_language_loyalty_test.dart
git commit -m "test: define Loyalty Rewards Vietnamese copy"
```

Review the staged diff before committing to ensure existing user changes are excluded.

---

### Task 2: Render the complete Loyalty Rewards screen through localization

**Files:**
- Create: `frontend/test/features/loyalty/presentation/loyalty_page_localization_test.dart`
- Modify: `frontend/lib/features/loyalty/presentation/loyalty_page.dart`

**Interfaces:**
- Consumes: Task 1 `AppStrings.ui` mappings and typed loyalty helper methods.
- Produces: `LoyaltyPage({Key? key, Future<LoyaltyDashboardData> Function()? dashboardLoader})` and a fully localized screen.

- [ ] **Step 1: Write a failing Vietnamese widget test**

Initialize shared preferences and the language controller, then construct a dashboard containing every screen section:

```dart
TestWidgetsFlutterBinding.ensureInitialized();

setUp(() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await LocalStorage.instance.initialize();
  await AppLanguageController.instance.setLanguage(AppLanguage.vietnamese);
});

tearDown(() async {
  await AppLanguageController.instance.setLanguage(AppLanguage.english);
});

testWidgets('renders the complete Loyalty Rewards screen in Vietnamese', (
  WidgetTester tester,
) async {
  final LoyaltyDashboardData dashboard = loyaltyDashboardFixture();

  await tester.pumpWidget(
    AppLanguageScope(
      controller: AppLanguageController.instance,
      child: MaterialApp(
        home: LoyaltyPage(dashboardLoader: () async => dashboard),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Điểm thưởng thành viên'), findsOneWidget);
  expect(find.text('Điểm hiện có'), findsOneWidget);
  expect(find.text('Thông báo điểm thưởng'), findsOneWidget);
  expect(find.text('Tiến trình xếp hạng'), findsOneWidget);
  expect(find.text('Kiếm điểm'), findsOneWidget);
  expect(find.text('Đi'), findsWidgets);

  await tester.drag(find.byType(ListView), const Offset(0, -1600));
  await tester.pumpAndSettle();

  expect(find.text('Đổi điểm thành token'), findsOneWidget);
  expect(find.text('Đổi voucher'), findsOneWidget);
  expect(find.text('Ví voucher'), findsOneWidget);
  expect(find.text('Lịch sử giao dịch'), findsOneWidget);
});
```

Implement `loyaltyDashboardFixture()` in the test with a Gold account, Platinum next tier, wishlist/forum/review/check-in/daily-login rules, one voucher, one wallet voucher, and one pending transaction. Use the exact constructors from `loyalty_models.dart` so no repository or network mock is required.

- [ ] **Step 2: Write a failing English regression widget test**

Set the controller to English and pump the same fixture:

```dart
expect(find.text('Loyalty Rewards'), findsOneWidget);
expect(find.text('Available points'), findsOneWidget);
expect(find.text('Earn points'), findsOneWidget);
```

This test protects the existing English interface while production text is routed through localization.

- [ ] **Step 3: Run widget tests and verify RED**

Run:

```bash
cd frontend
flutter test test/features/loyalty/presentation/loyalty_page_localization_test.dart
```

Expected: compilation initially fails because `dashboardLoader` does not exist; after adding only the seam, assertions still fail because the UI renders English.

- [ ] **Step 4: Add the deterministic dashboard-loader seam**

Modify `LoyaltyPage` without changing the default production path:

```dart
class LoyaltyPage extends StatefulWidget {
  const LoyaltyPage({super.key, this.dashboardLoader});

  final Future<LoyaltyDashboardData> Function()? dashboardLoader;

  @override
  State<LoyaltyPage> createState() => _LoyaltyPageState();
}
```

In state, centralize loading and refreshing:

```dart
Future<LoyaltyDashboardData> _loadDashboard() =>
    widget.dashboardLoader?.call() ?? _repository.loadDashboard();

@override
void initState() {
  super.initState();
  _future = _loadDashboard();
  _loadNotificationPreference();
}

void _refresh() {
  setState(() {
    _future = _loadDashboard();
  });
}
```

- [ ] **Step 5: Localize every static and dynamic presentation value**

Replace hardcoded text at its render site:

```dart
Text(context.l10n.ui('Loyalty Rewards'))
Text(context.l10n.ui('Available points'))
Text(context.l10n.ui('Loyalty notifications'))
Text(context.l10n.loyaltyHighestTier(context.l10n.ui(account.highestTier)))
```

Use typed helpers for all interpolated copy:

```dart
context.l10n.loyaltyTierProgress(
  account.tierPoints,
  nextMin,
  context.l10n.ui(nextTier.name),
)
```

```dart
subtitle: context.l10n.loyaltyEarnSummary(
  rule.pointAmount,
  rule.tierPointAmount,
  requiresApproval: rule.requiresApproval,
  automatic: isDailyLogin,
),
buttonLabel: context.l10n.ui(isDailyLogin ? 'Auto' : 'Go'),
```

Apply localization to header tooltips/semantics, loading message, summary metrics, notification card, progress/highest-tier state, cycle date, rule names, testing actions and outcomes, token exchange copy, voucher sections, wallet status/expiry, transaction status/amount/date, error state, retry action, and local snack bars. Remove `const` only from widgets whose descendants now access `context.l10n`.

- [ ] **Step 6: Format and verify widget tests GREEN**

Run:

```bash
dart format frontend/lib/core/language/app_language.dart frontend/lib/features/loyalty/presentation/loyalty_page.dart frontend/test/core/language/app_language_loyalty_test.dart frontend/test/features/loyalty/presentation/loyalty_page_localization_test.dart
cd frontend
flutter test test/core/language/app_language_loyalty_test.dart test/features/loyalty/presentation/loyalty_page_localization_test.dart
```

Expected: PASS in both Vietnamese and English modes.

- [ ] **Step 7: Audit raw Loyalty Rewards strings**

Run:

```bash
rg -n "const Text\('[A-Za-z]|Text\('[A-Za-z]|label: '[A-Za-z]|title: '[A-Za-z]|subtitle: '[A-Za-z]|buttonLabel: '[A-Za-z]|message: '[A-Za-z]" frontend/lib/features/loyalty/presentation/loyalty_page.dart
```

Expected: no user-facing English literal bypasses `context.l10n`; remaining matches, if any, are backend identifiers or strings passed immediately into localization.

- [ ] **Step 8: Run focused regression checks and analyzer**

Run:

```bash
cd frontend
flutter test test/core/language/app_language_loyalty_test.dart test/features/loyalty/presentation/loyalty_page_localization_test.dart test/core/language/app_language_review_test.dart test/features/profile/presentation/language_page_test.dart
flutter analyze
```

Expected: tests PASS and analysis reports no new issues.

- [ ] **Step 9: Commit the localized screen**

```bash
git add frontend/lib/features/loyalty/presentation/loyalty_page.dart frontend/test/features/loyalty/presentation/loyalty_page_localization_test.dart
git commit -m "feat: localize Loyalty Rewards screen"
```

Do not stage the unrelated Trip Planner plan or pre-existing item-detail/review changes.
