# Truthful Stripe Checkout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove app-invented Google Pay/VISA choices and other non-functional payment controls while keeping the existing Stripe Sandbox Checkout, voucher, and Premium activation flow intact.

**Architecture:** Keep Stripe Checkout as the sole payment boundary and let Stripe choose eligible cards or wallets. Simplify the Flutter presentation model so it carries purchase data only, then render truthful provider copy on entry, confirmation, and success screens.

**Tech Stack:** Flutter/Dart widget tests, Flutter localization map, Supabase Edge Functions and Stripe Checkout as unchanged integration boundaries.

## Global Constraints

- Do not change `SubscriptionRepository.createStripeCheckout`, its request payload, Supabase Edge Functions, or Stripe Dashboard settings.
- Preserve voucher calculation, loyalty award, returned-session retry, and Premium entitlement activation behavior.
- Do not claim that Google Pay, VISA, or any other card brand is selected by the app.
- Google Pay may still appear on Stripe's hosted page when Stripe considers it eligible.
- Do not modify or commit unrelated untracked user files.

---

### Task 1: Lock the truthful payment UI contract with widget tests

**Files:**
- Modify: `frontend/test/features/profile/presentation/upgrade_account_entitlement_test.dart`

**Interfaces:**
- Consumes: `UpgradePaymentPage`, `_FakePaymentRepository`, and `PremiumEntitlementController` already defined by the test file.
- Produces: regression coverage for entry, confirmation, and successful-return payment copy.

- [x] **Step 1: Add a failing entry/confirmation test**

Add a widget test that pumps `UpgradePaymentPage` without a returned session, waits for the fallback plan, and asserts:

```dart
expect(find.text('Stripe Sandbox Checkout'), findsOneWidget);
expect(
  find.text('Choose an eligible card or wallet securely on Stripe.'),
  findsOneWidget,
);
expect(find.text('G Pay'), findsNothing);
expect(find.text('VISA'), findsNothing);
expect(find.text('Add another payment method'), findsNothing);
expect(find.text('Select your payment method:'), findsNothing);
```

Tap `payment-continue`, settle, and assert the confirmation page still shows `Stripe Sandbox Checkout`, shows `Payment provider`, and has no `Change` action.

- [x] **Step 2: Add a failing successful-return test**

Pump `UpgradePaymentPage` with `checkoutSessionId: 'cs_test_123'` and the existing fake dependencies. Assert the success transaction summary contains `Stripe Sandbox`, contains neither `VISA` nor `G Pay`, and does not render `Download Receipt`.

- [x] **Step 3: Run the widget test and verify RED**

Run:

```powershell
cd frontend
flutter test test/features/profile/presentation/upgrade_account_entitlement_test.dart
```

Expected: FAIL because the old UI renders VISA/G Pay and does not render the new Stripe provider copy.

---

### Task 2: Remove fake method state and render Stripe as the provider

**Files:**
- Modify: `frontend/lib/features/profile/presentation/upgrade_payment_page.dart`
- Test: `frontend/test/features/profile/presentation/upgrade_account_entitlement_test.dart`

**Interfaces:**
- Consumes: the unchanged `SubscriptionRepository.createStripeCheckout({planCode, voucherCode, isWeb, webOrigin})` boundary.
- Produces: `_StripeCheckoutProviderCard`, a presentation-only provider card with no selection or change callback.

- [x] **Step 1: Remove the app-invented method model**

Delete `_PaymentMethod`, `_methods`, `_selectedMethodId`, `_PaymentCard`, `_PaymentSelectionIndicator`, `_AddPaymentMethodCard`, `_ConfirmPaymentMethodCard`, and `_PaymentMethodIcon`. Remove `method` from `_PaymentFlowData` and from every construction/consumer of that type.

- [x] **Step 2: Make Continue depend only on the loaded plan**

Change `_continueToConfirmation` to construct `_PaymentFlowData` directly from the plan and voucher. Change `payment-continue` to:

```dart
onPressed: _plan == null ? null : () => _continueToConfirmation(_plan!),
```

- [x] **Step 3: Add the non-interactive provider card**

Add `_StripeCheckoutProviderCard`, built from `_GlassPanel`, with a Stripe/payment icon, the localized label `Stripe Sandbox Checkout`, and localized supporting copy `Choose an eligible card or wallet securely on Stripe.` It takes no callback and cannot imply that the app selects a payment method.

Render it on the entry page below the `Payment provider` heading and on the confirmation page in place of `_ConfirmPaymentMethodCard`.

- [x] **Step 4: Make the success page provider-specific rather than method-specific**

Set the transaction detail trailing label to `context.l10n.ui('Stripe Sandbox')`. Remove the entire `_SecondaryActionButton` for `Download Receipt`; if that widget becomes unused, remove its class too.

- [x] **Step 5: Run the widget test and verify GREEN**

Run:

```powershell
cd frontend
dart format lib/features/profile/presentation/upgrade_payment_page.dart test/features/profile/presentation/upgrade_account_entitlement_test.dart
flutter test test/features/profile/presentation/upgrade_account_entitlement_test.dart
```

Expected: all tests in the file pass.

- [x] **Step 6: Commit the tested payment presentation change**

```powershell
git add frontend/lib/features/profile/presentation/upgrade_payment_page.dart frontend/test/features/profile/presentation/upgrade_account_entitlement_test.dart
git diff --cached --check
git commit -m "fix: make Stripe checkout payment UI truthful"
```

---

### Task 3: Localize the new provider copy and remove dead payment strings

**Files:**
- Modify: `frontend/test/core/language/app_language_requested_flows_test.dart`
- Modify: `frontend/lib/core/language/app_language.dart`

**Interfaces:**
- Consumes: `AppStrings.ui(String)`.
- Produces: Vietnamese translations for `Payment provider`, `Stripe Sandbox Checkout`, `Choose an eligible card or wallet securely on Stripe.`, and `Stripe Sandbox`.

- [x] **Step 1: Add failing Vietnamese localization expectations**

Add these literals to `expectedVietnamese`:

```dart
'Payment provider': 'Cổng thanh toán',
'Stripe Sandbox Checkout': 'Thanh toán thử nghiệm qua Stripe',
'Choose an eligible card or wallet securely on Stripe.':
    'Chọn thẻ hoặc ví điện tử đủ điều kiện một cách bảo mật trên Stripe.',
'Stripe Sandbox': 'Stripe thử nghiệm',
```

- [x] **Step 2: Run the localization test and verify RED**

Run:

```powershell
cd frontend
flutter test test/core/language/app_language_requested_flows_test.dart
```

Expected: FAIL because the new keys currently fall back to English.

- [x] **Step 3: Add the translations and remove unreachable copy**

Add the four exact mappings to `_uiVi`. Remove mappings for `Select your payment method:`, `Add another payment method`, `Payment Method`, `Change`, `Download Receipt`, and `Receipt download is coming soon.` after confirming repository-wide search finds no remaining consumer.

- [x] **Step 4: Run the localization and payment tests and verify GREEN**

Run:

```powershell
cd frontend
dart format lib/core/language/app_language.dart test/core/language/app_language_requested_flows_test.dart
flutter test test/core/language/app_language_requested_flows_test.dart test/features/profile/presentation/upgrade_account_entitlement_test.dart
```

Expected: both test files pass.

- [x] **Step 5: Commit the tested localization cleanup**

```powershell
git add frontend/lib/core/language/app_language.dart frontend/test/core/language/app_language_requested_flows_test.dart
git diff --cached --check
git commit -m "chore: localize Stripe checkout provider copy"
```

---

### Task 4: Verify the complete payment boundary and repository cleanliness

**Files:**
- Verify only; no planned production modifications.

**Interfaces:**
- Consumes: all payment UI, repository, and existing Supabase/Stripe boundary tests.
- Produces: fresh evidence that the complete requested behavior is implemented without backend drift.

- [x] **Step 1: Search for misleading or dead payment UI copy**

Run:

```powershell
rg -n -i "G Pay|Google Pay|VISA|Add another payment method|Download Receipt|Receipt download is coming soon|Select your payment method" frontend/lib
```

Expected: no matches in active Flutter source. Regression tests may retain these literals only in `findsNothing` assertions.

- [x] **Step 2: Run targeted payment and localization tests**

Run:

```powershell
cd frontend
flutter test test/features/profile/presentation/upgrade_account_entitlement_test.dart test/features/profile/data/subscription_repository_test.dart test/core/language/app_language_requested_flows_test.dart
```

Expected: all tests pass with zero failures.

- [x] **Step 3: Run Flutter static analysis**

Run:

```powershell
cd frontend
flutter analyze --no-fatal-infos
```

Expected: exit code 0 with no analyzer errors.

- [x] **Step 4: Review the final diff and protected boundaries**

Run `git diff HEAD~2 -- frontend backend/supabase/functions`, confirm no backend file or checkout payload changed, then run `git status --short --branch`. Confirm unrelated untracked user files remain untouched.

- [x] **Step 5: Record completion evidence**

Update the active goal only after every acceptance criterion in `docs/superpowers/specs/2026-08-13-truthful-stripe-checkout-design.md` has direct evidence from source, tests, searches, and git diff.

## Completion Evidence

- Widget RED: the new Stripe provider and returned-checkout tests failed on the old VISA/G Pay UI for the expected missing-copy reason.
- Localization RED: Vietnamese provider-copy expectations failed by receiving the English fallback.
- Targeted GREEN: 21 payment presentation, repository payload, and localization tests passed.
- Full GREEN: `flutter test` passed all 478 frontend tests.
- Static analysis: `flutter analyze --no-fatal-infos` exited 0; it reported only two pre-existing info-level notices in Trip Planner files outside this change.
- Source audit: no active Flutter source contains the removed G Pay/VISA selector, add-method control, receipt placeholder, empty tap/press callbacks, or explicit `coming soon`/`not implemented` markers.
- Boundary audit: the implementation diff contains no changes under `backend/supabase/functions` or `frontend/lib/features/profile/data/subscription_repository.dart`.
