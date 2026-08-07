# App-wide Currency Synchronization Design

## Goal

Synchronize every user-facing monetary value with the currency selected on the Currency page while preserving each value's source currency and keeping Stripe settlement in USD.

## Scope

The change covers the customer application only:

- Trip Planner budget input and trip price details
- Recommended-place price details
- Explore destination prices
- AI Recognition typical-price results and saved history
- Premium plans, checkout review, voucher discounts, confirmation, and payment history
- Loyalty/Voucher monetary terms
- Rank-benefit copy containing monetary thresholds

The Admin application, Admin forms, database source values, loyalty points, tokens, percentages, and non-monetary benefits are excluded.

## Current State

`CurrencyRepository` already stores the selected currency, loads USD-based live rates, and caches the last snapshot. It is currently initialized only when the Currency page opens and does not expose a shared conversion/formatting API.

User-facing money is rendered independently:

- Trip Planner and Recommend use hard-coded VND formatters.
- Explore uses a hard-coded dollar sign.
- Premium and payment use USD minor units and hard-coded dollar formatters.
- Voucher and rank-benefit content embeds dollar amounts in static strings.
- AI Recognition returns `price_range` as an unstructured string, normally in VND.

## Chosen Approach

Introduce one app-wide money model, converter, formatter, and reactive currency scope. Feature adapters declare the source currency and source-unit semantics; the shared formatter converts only for presentation.

This approach keeps source data authoritative, avoids duplicating conversion logic across screens, and permits immediate UI updates when the selected currency changes.

## Architecture

### Money model

`MoneyAmount` represents an integer number of minor units and an ISO currency code. Currency metadata defines the minor-unit exponent:

- VND, JPY, and KRW use exponent `0`.
- Other supported currencies use exponent `2`.

Feature boundaries convert existing values into `MoneyAmount`:

- Trip and Recommend numeric prices are VND major values and therefore VND minor units.
- Explore `pricePerNight` is an USD major value converted to USD cents.
- Subscription plans, checkout totals, discounts, and payment history already use USD cents.
- Structured voucher monetary terms use their explicitly declared source currency.

### Conversion

Rates remain USD-based, where each rate means `1 USD = rate[currency]`. Conversion from source `S` to target `T` uses:

```text
source major / rate[S] * rate[T] = target major
```

USD uses an implicit rate of `1`. The target value is rounded once to the target currency's minor-unit precision. Source amounts and server payloads are never mutated.

### Formatting

The formatter uses the selected currency's catalog symbol and grouping rules:

- VND, JPY, and KRW display no decimal fraction.
- All other supported currencies display two fractional digits.
- Catalog symbols disambiguate currencies that share `$`, for example `A$`, `C$`, and `S$`.
- Converted values may be prefixed with `≈` where the source value matters, especially Premium checkout.
- Ranges convert and format both endpoints using one rate snapshot.

### Reactive scope and initialization

The production bootstrap initializes `CurrencyRepository` after local storage and Supabase are ready. A root currency scope listens to the repository and exposes the selected currency and formatter through `BuildContext`.

Only widgets that depend on currency rebuild when selection or rates change. Opening the Currency page is no longer required to activate currency state.

### Feature integration

Trip Planner accepts and formats typed budget in the selected currency. When a downstream contract requires VND, the amount is converted back to VND at the boundary. Existing qualitative budget presets remain non-monetary.

Trip Detail and Recommend treat database minimum and maximum prices as VND and use the shared range formatter.

Explore treats `pricePerNight` as USD and formats it in the selected currency.

Premium screens show the selected-currency equivalent and a clear settlement line such as `Stripe charge: USD 18.00`. Checkout requests, voucher validation, stored minor amounts, and Stripe settlement remain USD.

Voucher and rank-benefit entries replace monetary text fragments with structured source amounts so titles, descriptions, thresholds, and maximum discounts can be rendered dynamically. Non-monetary voucher text is unchanged.

AI Recognition adds structured `price_min`, `price_max`, and `currency_code` fields to new responses while retaining `price_range` for compatibility. Existing saved results attempt a conservative parse of recognized ranges; unparseable values remain unchanged.

## Fallback and Error Handling

The repository uses the latest cached rate snapshot if refreshing live rates fails. If either the source or target rate is unavailable and no usable cache exists, the formatter returns the correctly formatted source amount and source currency rather than guessing, returning zero, or hiding the price.

Unsupported saved currency codes fall back to VND. Invalid or unparseable legacy AI price strings remain visible as their original text.

Currency selection remains locally responsive even if saving the preference remotely fails; the existing error state communicates the persistence failure.

## Payment Safety

Currency conversion is presentational only for Premium purchases. The app continues sending only the plan code and voucher code to the subscription-payment function. Server-owned USD pricing remains the source of truth, and Stripe Checkout continues charging USD.

The confirmation UI must never imply that the converted display amount is the settlement amount. It shows both the approximate selected-currency amount and the exact USD charge.

## Testing

Unit tests cover:

- USD-to-target and cross-currency conversion
- Zero-decimal and two-decimal currencies
- Single-value and range formatting
- Rounding at the target minor-unit boundary
- Cached-rate and missing-rate fallbacks
- Legacy AI range parsing

Widget tests cover reactive updates and representative monetary displays in Trip Planner, Trip Detail/Recommend, Explore, AI Recognition, Premium/Payment History, Voucher, and Rank Benefits.

Payment regression tests verify that selecting another display currency does not change the Stripe request body, server-owned USD cents, voucher calculations, or recorded payment currency.

A source guard test scans customer-facing presentation files for newly introduced hard-coded monetary tokens such as escaped dollar amounts or `VND` formatters, with a narrow allowlist for the currency catalog, source-currency declarations, and explicit Stripe settlement copy.

## Success Criteria

- Selecting a supported currency updates all customer-facing monetary values without reopening the app.
- The selection works from startup even if the Currency page has not been opened.
- Every converted value uses one shared calculation and formatting policy.
- Missing rates never produce fabricated or zero prices.
- Admin behavior and source data remain unchanged.
- Stripe continues charging and recording the exact server-owned USD amount.
