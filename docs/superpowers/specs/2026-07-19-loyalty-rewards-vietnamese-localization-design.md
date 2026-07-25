# Loyalty Rewards Vietnamese Localization Design

## Goal

Localize the complete Loyalty Rewards screen when the application language is Vietnamese while preserving the existing English interface and all loyalty behavior.

## Scope

The change covers every user-facing section of `LoyaltyPage`:

- Page header, loading state, refresh action, error state, and retry action
- Current and highest membership tiers
- Available points, token balance, and lifetime points
- Loyalty notification setting and description
- Tier progress, next-tier requirement, highest-tier state, and cycle end date
- Earn-points rules, approval state, automatic daily login, and navigation actions
- Temporary loyalty testing controls and result messages
- Point-to-token exchange actions and limits
- Voucher redemption, empty states, and affordability state
- Voucher wallet entries and expiry information
- Transaction history, statuses, point changes, token changes, and dates
- Success, failure, and informational snack bars

The task does not change loyalty calculations, database values, routes, notification persistence, redemption behavior, or visual layout.

## Localization Architecture

Static interface strings will use the existing `context.l10n.ui(english)` lookup. Missing English-to-Vietnamese mappings will be added to `AppStrings._viText`, keeping the English string as the fallback key.

Dynamic sentences will use typed `AppStrings` methods so interpolated values do not break map lookups. These methods will cover highest-tier copy, progress toward the next tier, cycle dates, points and tier-points summaries, token exchange costs, voucher requirements, wallet expiry, and transaction summaries.

Server-backed names and statuses will be passed through `ui(...)` at render time when they represent known system vocabulary. Custom voucher titles, codes, and other user- or administrator-authored content will remain unchanged unless an exact translation already exists.

## Vietnamese Copy

Representative action and status translations include:

| English | Vietnamese |
| --- | --- |
| Loyalty Rewards | Điểm thưởng thành viên |
| Available points | Điểm hiện có |
| Tokens | Token |
| Lifetime points | Tổng điểm tích lũy |
| Loyalty notifications | Thông báo điểm thưởng |
| Tier progress | Tiến trình xếp hạng |
| Earn points | Kiếm điểm |
| Go | Đi |
| Auto | Tự động |
| Redeem | Đổi |
| Retry | Thử lại |
| Needs review | Cần xét duyệt |
| Automatic | Tự động |
| Transaction history | Lịch sử giao dịch |

The final catalog will include every static label discovered in the complete screen, not only the portion visible in the supplied screenshot.

## Component Changes

`LoyaltyPage` and its private presentation widgets will resolve copy from the current `BuildContext`. Const widgets containing localized text will become non-const only where required. Existing data models and repository interfaces will not change unless a minimal dependency seam is needed for a widget test.

`app_language.dart` already contains unrelated uncommitted user changes. The implementation will add only focused localization entries and helpers without rewriting, discarding, or staging unrelated hunks.

## Error Handling

Known local errors and status messages will be localized before display. Unknown backend error strings will retain their original content rather than being hidden or replaced with an inaccurate translation. Loading, retry, successful update, automatic daily login, test-point outcomes, redemption failures, and empty states will all have Vietnamese copy.

## Testing

Implementation will follow test-driven development:

1. Add unit tests for static and dynamic Loyalty Rewards copy in Vietnamese.
2. Verify that English mode returns the unchanged English copy.
3. Add widget coverage for representative header, summary, notification, progress, earn-points, redemption, wallet, transaction, loading, and error states.
4. Run focused loyalty/localization tests and `flutter analyze` for regression detection.

## Success Criteria

- No actionable or explanatory English UI copy remains on Loyalty Rewards in Vietnamese mode, except unknown/custom backend content.
- English mode retains its current labels and behavior.
- All sections below the supplied screenshot are included.
- Loyalty calculations, routing, redemption, notification settings, and layout remain unchanged.
- Focused tests and static analysis pass without new issues.
