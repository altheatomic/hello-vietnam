# Premium Entitlement Synchronization Design

## Goal

Provide one authoritative client-side Premium entitlement state for every
Flutter feature that gates paid functionality. An active subscriber must not
be shown an upgrade lock because authentication restoration, a transient
Supabase failure, stale cache data, or navigation lifecycle timing produced a
false negative.

The server remains authoritative. The existing AI Chat Edge Function continues
to verify the active subscription before processing paid requests.

## Current Failure

The Home AI Chat launcher, AI Chat page, Translate page, and Upgrade page check
Premium independently.

The observed failure occurs because:

1. `AiChatHomeLauncher` checks Premium once in `initState`.
2. A missing current user or any subscription-query exception becomes `false`.
3. `SubscriptionRepository.loadCurrentSubscription` catches every exception
   and returns `null`, making a failed query indistinguishable from a confirmed
   inactive subscription.
4. AI Chat stores that boolean in a feature-specific cache and local widget
   state.
5. The indexed Home branch remains mounted while Upgrade performs a fresh
   successful query, so returning to Home does not refresh the stale lock.

The subscription record itself is valid; the disagreement is client state.

## Scope

The change covers:

- Home AI Chat launcher;
- AI Chat page;
- Premium mode in Translate;
- Upgrade Account current-plan status;
- successful subscription purchase and Stripe confirmation;
- authentication changes;
- application resume.

The change does not alter:

- subscription pricing or durations;
- the `premium_subscription` database schema;
- Stripe checkout behavior;
- AI Chat provider behavior;
- server-side Premium enforcement;
- unrelated feature state management.

## Chosen Architecture

Create one application-scoped `PremiumEntitlementController` under the profile
feature's application layer. It owns the current user's entitlement state and
notifies every Premium consumer through `ChangeNotifier`.

The controller follows the singleton pattern already used by authentication,
notifications, theme, language, travel preferences, and other application-wide
state in this codebase. Consumers may receive an injected controller in tests.

### State Model

Use an immutable `PremiumEntitlementState` with:

- `status`: `loading`, `active`, `inactive`, or `error`;
- `subscription`: the last confirmed `CurrentSubscriptionInfo`, when present;
- `error`: the most recent refresh error, when present;
- `userId`: the user for whom the state was loaded;
- `lastCheckedAt`: the time of the last successful server response.

Derived values include:

- `isActive`: true only when status is `active` and the subscription end date
  remains in the future;
- `isConfirmedInactive`: true only when the server successfully returned no
  active subscription;
- `canUsePremium`: equivalent to `isActive`.

Signed-out users use the confirmed `inactive` state with no `userId`. This
keeps the state model focused while authentication routing remains the
responsibility of existing app navigation.

### Repository Contract

`SubscriptionRepository.loadCurrentSubscription` must distinguish outcomes:

- return `CurrentSubscriptionInfo` when an active row exists;
- return `null` when the authenticated query succeeds and no active row exists;
- throw a typed request exception when authentication, network, timeout, RLS,
  parsing, or Supabase access fails.

It must not convert exceptions into `null`.

The controller, not the repository, decides how a failed refresh affects the
visible state.

### Controller Lifecycle

`PremiumEntitlementController.initialize` is idempotent and:

1. registers an authentication-state listener;
2. registers an application-lifecycle observer;
3. starts an initial refresh without delaying the entire app bootstrap.

The controller refreshes when:

- the authenticated user changes;
- the app returns to the foreground;
- Upgrade Account is opened;
- a direct purchase or Stripe confirmation succeeds;
- a consumer explicitly requests retry.

Concurrent refreshes for the same user are deduplicated. Every request captures
the user ID and a request generation number; a response is ignored if the user
changed or a newer forced refresh started before it completed.

Signing out clears the subscription, errors, and in-flight result ownership so
one user's entitlement can never leak to another user.

## State Transition Rules

### Initial and Confirmed States

- Initial authenticated load: `loading`.
- Successful active row: `active`.
- Successful empty result: `inactive`.
- Signed out: `inactive` with no user ID.

### Refresh Failures

A request failure is never converted to `inactive`.

- If there is no previously confirmed active subscription, transition to
  `error`. Premium surfaces show retry UI rather than an upgrade lock.
- If a previously confirmed active subscription still has a future end date,
  retain `active`, store the refresh error, and allow the server to make the
  final authorization decision when the user sends a paid request.
- If the last confirmed subscription has expired locally and refresh fails,
  transition to `error`; do not keep granting client-side Premium access.

No persistent offline Premium snapshot is introduced. AI Chat and Premium
translation require online services, so an in-memory last-known-good state is
sufficient and avoids a second durable entitlement authority.

## Consumer Behavior

### Home AI Chat Launcher

Remove its private Premium boolean loader and feature-specific cache.

Render from the shared controller:

- `loading`: progress indicator and disabled tap;
- `active`: normal AI Chat launcher;
- `inactive`: lock badge; tap opens Upgrade;
- `error`: retry badge; tap forces an entitlement refresh.

Only `inactive` may display an upgrade lock.

### AI Chat Page

Use the same controller state:

- `active`: show composer and allow new messages;
- `inactive`: show Premium gate;
- `loading`: show progress;
- `error`: show retry state without presenting the user as Free.

Existing conversations remain readable under the current product behavior.
The Edge Function remains the final check for message sending and speech.

### Translate

Premium translation and automatic language detection consult
`PremiumEntitlementController.canUsePremium`.

If status is `loading`, wait for the current refresh. If status is `error`, show
a retryable verification error. Open Upgrade only after a confirmed
`inactive` result.

Basic on-device translation remains unchanged.

### Upgrade Account

Use the shared subscription state for the current plan, active badge, end date,
remaining days, and purchase-button eligibility. Payment history remains a
separate repository query.

Opening the page forces a refresh. This refresh updates the Home launcher even
while Home remains mounted behind the route.

### Payment Completion

After direct purchase or Stripe confirmation succeeds:

1. force-refresh the controller;
2. wait for a successful entitlement result;
3. then show the activated state and navigate back.

If payment succeeded but entitlement refresh fails, show a retryable
verification message and retain payment success information. Do not label the
account inactive.

## Error Visibility

The repository preserves typed failure details. The controller records the
error and exposes a safe user-facing verification message.

Debug builds log:

- refresh trigger;
- user ID in redacted form;
- request generation;
- result category (`active`, `inactive`, or `error`);
- underlying typed error.

Logs must not include access tokens, payment secrets, or complete personal
identifiers.

## Cache Migration

Delete `AiChatPremiumAccessCache` and its tests after all consumers use the
shared controller. A 30-second boolean cache is no longer needed because the
controller itself deduplicates in-flight requests and retains the last
confirmed state.

There must be no second Premium boolean stored inside AI Chat widgets.

## Testing Strategy

### Controller Unit Tests

Cover:

- active row produces `active`;
- successful empty result produces `inactive`;
- request exception produces `error`, not `inactive`;
- transient refresh error retains an unexpired confirmed active state;
- refresh error after local expiry does not retain active access;
- concurrent refreshes are deduplicated;
- forced refresh supersedes an older request;
- stale response from a previous user is ignored;
- sign-out clears the previous user's state;
- app resume and authentication changes trigger refresh.

### Repository Tests

Cover:

- active subscription parsing;
- successful empty query returns `null`;
- timeout, RLS, network, and malformed response errors propagate rather than
  returning `null`.

### Widget Tests

Cover:

- AI launcher shows lock only for confirmed inactive;
- AI launcher shows retry for error;
- AI launcher updates from inactive/error to active without remounting Home;
- AI Chat composer appears when shared state becomes active;
- Translate opens Upgrade only for confirmed inactive;
- Upgrade and Home display the same active subscription;
- successful payment refresh unlocks AI Chat.

### Regression Scenario

Automate the reported sequence:

1. Home initially receives an entitlement request error.
2. AI launcher shows retry, not a lock.
3. Upgrade forces a refresh and receives an active six-month subscription.
4. Home remains mounted.
5. The launcher updates automatically and opens AI Chat.

### Verification

Run targeted Premium, AI Chat, Translate, Upgrade, repository, and payment
tests first, followed by the complete Flutter test suite. Existing AI Chat Edge
Function Premium tests must continue to pass because server enforcement is
unchanged.

## Acceptance Criteria

- An active subscriber shown on Upgrade is simultaneously active in AI Chat
  and Translate.
- A transient request failure never displays the account as Free.
- Returning from Upgrade updates Home without restarting the app.
- Payment completion unlocks Premium surfaces without sign-out or force-stop.
- User switching cannot reuse another user's entitlement.
- AI Chat server-side Premium enforcement remains enabled.
- Basic offline translation behavior is unchanged.
- No feature-specific Premium boolean cache remains.
