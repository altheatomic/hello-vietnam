# Premium Entitlement Synchronization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace independent Premium checks with one reactive entitlement state so active subscribers cannot be incorrectly locked out of AI Chat, Premium Translate, or Upgrade status.

**Architecture:** Add an application-scoped `PremiumEntitlementController` that loads the current subscription through `SubscriptionRepository`, observes authentication and app lifecycle changes, deduplicates requests, and exposes `loading`, `active`, `inactive`, and `error` states. Migrate every Flutter Premium consumer to this controller, remove the AI Chat boolean cache, and keep the AI Chat Edge Function as the final server-side authorization layer.

**Tech Stack:** Flutter 3.41, Dart 3.11, `ChangeNotifier`, Supabase Flutter, GoRouter, Flutter Test, Deno tests

## Global Constraints

- Do not change the `premium_subscription` schema, subscription prices, plan durations, Stripe checkout contract, or AI provider behavior.
- Keep server-side Premium enforcement in `backend/supabase/functions/ai-chat`.
- Only a successful empty subscription query may produce `inactive`.
- Authentication, network, timeout, RLS, parsing, and Supabase errors must produce `error`, never `inactive`.
- Retain a previously confirmed active entitlement through a transient refresh failure only while its end date remains in the future.
- Do not add persistent offline Premium storage.
- Remove `AiChatPremiumAccessCache`; no feature may keep a second Premium boolean.
- Basic Google ML Kit on-device translation must remain unchanged.
- Use dependency injection for controller widget tests; do not require live Supabase access in tests.
- Preserve all unrelated dirty-worktree files and commit only files named by each task.

---

## File Structure

### New Files

- `frontend/lib/features/profile/application/premium_entitlement_controller.dart`
  - Owns the shared state, refresh lifecycle, concurrency control, and failure policy.
- `frontend/test/features/profile/application/premium_entitlement_controller_test.dart`
  - Covers state transitions, user switching, refresh races, lifecycle refresh, and error retention.
- `frontend/test/features/profile/presentation/upgrade_account_entitlement_test.dart`
  - Verifies Upgrade and payment-facing widgets consume the shared state.

### Modified Files

- `frontend/lib/features/profile/data/subscription_repository.dart`
  - Stops converting request failures into an inactive result.
- `frontend/test/features/profile/data/subscription_repository_test.dart`
  - Defines the repository's active, inactive, and error contract.
- `frontend/lib/app/app_bootstrap.dart`
  - Initializes the shared controller after Supabase initialization.
- `frontend/lib/features/profile/presentation/upgrade_account_page.dart`
  - Renders current plan and purchase eligibility from the controller.
- `frontend/lib/features/profile/presentation/upgrade_payment_page.dart`
  - Refreshes entitlement after payment confirmation and exposes retry if verification fails.
- `frontend/lib/features/ai_chat/presentation/widgets/ai_chat_home_launcher.dart`
  - Observes the controller; lock is shown only for confirmed inactive.
- `frontend/lib/features/ai_chat/presentation/ai_chat_page.dart`
  - Uses the shared state for its gate and composer.
- `frontend/test/features/ai_chat/presentation/ai_chat_home_launcher_test.dart`
  - Covers active, inactive, loading, error, and live state updates.
- `frontend/test/features/ai_chat/presentation/ai_chat_page_test.dart`
  - Covers shared-state gate behavior.
- `frontend/lib/features/translate/presentation/translate_page.dart`
  - Uses the controller when entering Premium mode.
- `frontend/test/features/translate/presentation/translate_page_test.dart`
  - Covers active, inactive, and verification-error mode switching.

### Deleted Files

- `frontend/lib/features/ai_chat/data/ai_chat_premium_access_cache.dart`
- `frontend/test/features/ai_chat/data/ai_chat_premium_access_cache_test.dart`

---

### Task 1: Make the subscription repository distinguish inactive from error

**Files:**
- Modify: `frontend/lib/features/profile/data/subscription_repository.dart:232-267`
- Modify: `frontend/test/features/profile/data/subscription_repository_test.dart`

**Interfaces:**
- Consumes: `SupabaseTableClient.list(String, SupabaseTableRequest)`.
- Produces: `Future<CurrentSubscriptionInfo?> loadCurrentSubscription()` where `null` means a successful query found no active row and exceptions remain exceptions.

- [ ] **Step 1: Extend the fake table client for list results and failures**

Add explicit list behavior to `_FakeTableClient`:

```dart
class _FakeTableClient extends SupabaseTableClient {
  _FakeTableClient({
    List<List<Map<String, dynamic>>>? listRows,
    Object? listError,
    List<Map<String, dynamic>?>? maybeSingleRows,
  }) : _listRows = List<List<Map<String, dynamic>>>.of(
         listRows ?? const <List<Map<String, dynamic>>>[],
       ),
       _listError = listError,
       _maybeSingleRows = List<Map<String, dynamic>?>.of(
         maybeSingleRows ?? const <Map<String, dynamic>?>[],
       );

  final List<List<Map<String, dynamic>>> _listRows;
  final Object? _listError;
  final List<String> listLabels = <String>[];

  @override
  Future<List<Map<String, dynamic>>> list(
    String label,
    SupabaseTableRequest request, {
    Duration? timeout,
  }) async {
    listLabels.add(label);
    if (_listError case final Object error) throw error;
    if (_listRows.isEmpty) return const <Map<String, dynamic>>[];
    return _listRows.removeAt(0);
  }
}
```

- [ ] **Step 2: Write repository contract tests**

Add an injectable current-user provider to the repository constructor and use
it in tests:

```dart
test('loadCurrentSubscription returns an active row', () async {
  final SubscriptionRepository repository = SubscriptionRepository(
    currentUserIdProvider: () => 'user-1',
    tableClient: _FakeTableClient(
      listRows: <List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[
          <String, dynamic>{
            'end_date': '2026-12-14T00:00:00Z',
            'subscription_plan': <String, dynamic>{
              'code': '6m',
              'name': 'Premium 6 Months',
              'duration_days': 180,
            },
          },
        ],
      ],
    ),
  );

  final CurrentSubscriptionInfo? result =
      await repository.loadCurrentSubscription();

  expect(result?.planCode, '6m');
  expect(result?.endDate, DateTime.parse('2026-12-14T00:00:00Z'));
});

test('loadCurrentSubscription returns null for a confirmed empty query',
    () async {
  final SubscriptionRepository repository = SubscriptionRepository(
    currentUserIdProvider: () => 'user-1',
    tableClient: _FakeTableClient(
      listRows: <List<Map<String, dynamic>>>[
        const <Map<String, dynamic>>[],
      ],
    ),
  );

  expect(await repository.loadCurrentSubscription(), isNull);
});

test('loadCurrentSubscription propagates table failures', () async {
  final Object failure = SupabaseTableException('current subscription failed');
  final SubscriptionRepository repository = SubscriptionRepository(
    currentUserIdProvider: () => 'user-1',
    tableClient: _FakeTableClient(listError: failure),
  );

  await expectLater(
    repository.loadCurrentSubscription(),
    throwsA(same(failure)),
  );
});

test('loadCurrentSubscription rejects a malformed plan relation', () async {
  final SubscriptionRepository repository = SubscriptionRepository(
    currentUserIdProvider: () => 'user-1',
    tableClient: _FakeTableClient(
      listRows: <List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[
          <String, dynamic>{
            'end_date': '2026-12-14T00:00:00Z',
            'subscription_plan': 'invalid',
          },
        ],
      ],
    ),
  );

  await expectLater(
    repository.loadCurrentSubscription(),
    throwsA(isA<SupabaseTableException>()),
  );
});
```

The production constructor change is:

```dart
typedef SubscriptionCurrentUserId = String? Function();

SubscriptionRepository({
  SupabaseClient? client,
  SupabaseFunctionClient? functionClient,
  SupabaseTableClient? tableClient,
  SubscriptionCurrentUserId? currentUserIdProvider,
}) : _clientOverride = client,
     _functionClient = functionClient,
     _tableClient = tableClient,
     _currentUserIdProvider = currentUserIdProvider;

final SubscriptionCurrentUserId? _currentUserIdProvider;
```

- [ ] **Step 3: Run the repository tests and verify RED**

Run from `frontend`:

```powershell
flutter test test/features/profile/data/subscription_repository_test.dart
```

Expected: the failure and malformed-response tests fail because
`loadCurrentSubscription` currently catches the error and returns `null`.

- [ ] **Step 4: Implement strict repository semantics**

Replace the broad `try/catch` in `loadCurrentSubscription` with:

```dart
Future<CurrentSubscriptionInfo?> loadCurrentSubscription() async {
  final String? userId =
      _currentUserIdProvider?.call() ?? _client.auth.currentUser?.id;
  if (userId == null) return null;

  final List<Map<String, dynamic>> rows =
      await _resolvedTableClient.list('current subscription', () async {
    return _client
        .from('premium_subscription')
        .select(
          'end_date, subscription_plan:id_plan(code, name, duration_days)',
        )
        .eq('id_user', userId)
        .eq('status', 'active')
        .gt('end_date', DateTime.now().toUtc().toIso8601String())
        .order('end_date', ascending: false)
        .limit(1);
  });

  if (rows.isEmpty) return null;

  final Map<String, dynamic> row = rows.first;
  final Object? rawPlan = row['subscription_plan'];
  if (rawPlan is! Map) {
    throw SupabaseTableException(
      'Unexpected current subscription plan response.',
      details: rawPlan,
    );
  }

  final Map<String, dynamic> plan = Map<String, dynamic>.from(rawPlan);
  return CurrentSubscriptionInfo(
    planCode: plan['code']?.toString() ?? '',
    planName: plan['name']?.toString() ?? '',
    durationDays: (plan['duration_days'] as num?)?.toInt() ?? 0,
    endDate: DateTime.tryParse(row['end_date']?.toString() ?? ''),
  );
}
```

- [ ] **Step 5: Run the repository tests and verify GREEN**

Run:

```powershell
flutter test test/features/profile/data/subscription_repository_test.dart
```

Expected: all subscription repository tests pass.

- [ ] **Step 6: Commit the repository contract**

```powershell
git add -- frontend/lib/features/profile/data/subscription_repository.dart frontend/test/features/profile/data/subscription_repository_test.dart
git commit -m "fix: distinguish premium lookup errors"
```

---

### Task 2: Build the shared Premium entitlement controller

**Files:**
- Create: `frontend/lib/features/profile/application/premium_entitlement_controller.dart`
- Create: `frontend/test/features/profile/application/premium_entitlement_controller_test.dart`

**Interfaces:**
- Consumes: `SubscriptionRepository.loadCurrentSubscription()`, current user ID, auth-user stream, `DateTime.now`.
- Produces:
  - `enum PremiumEntitlementStatus { loading, active, inactive, error }`
  - immutable `PremiumEntitlementState`
  - singleton `PremiumEntitlementController.instance`
  - `void initialize()`
  - `Future<void> refresh({bool force = false})`
  - `Future<void> retry()`
  - `PremiumEntitlementState get state`

- [ ] **Step 1: Write state-transition tests**

Create `premium_entitlement_controller_test.dart` with a mutable loader:

```dart
typedef Loader = Future<CurrentSubscriptionInfo?> Function();

CurrentSubscriptionInfo activeSubscription([DateTime? endDate]) {
  return CurrentSubscriptionInfo(
    planCode: '6m',
    planName: 'Premium 6 Months',
    durationDays: 180,
    endDate: endDate ?? DateTime.utc(2026, 12, 14),
  );
}

test('successful active row produces active', () async {
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async => activeSubscription(),
    currentUserId: () => 'user-1',
    now: () => DateTime.utc(2026, 7, 27),
  );

  await controller.refresh();

  expect(controller.state.status, PremiumEntitlementStatus.active);
  expect(controller.canUsePremium, isTrue);
});

test('successful empty result produces confirmed inactive', () async {
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async => null,
    currentUserId: () => 'user-1',
  );

  await controller.refresh();

  expect(controller.state.status, PremiumEntitlementStatus.inactive);
  expect(controller.state.isConfirmedInactive, isTrue);
});

test('request failure produces error instead of inactive', () async {
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async => throw const SupabaseTableException('failed'),
    currentUserId: () => 'user-1',
  );

  await controller.refresh();

  expect(controller.state.status, PremiumEntitlementStatus.error);
  expect(controller.state.isConfirmedInactive, isFalse);
});
```

- [ ] **Step 2: Write last-known-active and expiry tests**

```dart
test('transient failure retains an unexpired active entitlement', () async {
  var fail = false;
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async {
      if (fail) throw const SupabaseTableException('temporary');
      return activeSubscription(DateTime.utc(2026, 12, 14));
    },
    currentUserId: () => 'user-1',
    now: () => DateTime.utc(2026, 7, 27),
  );

  await controller.refresh();
  fail = true;
  await controller.refresh(force: true);

  expect(controller.state.status, PremiumEntitlementStatus.active);
  expect(controller.state.error, isNotNull);
});

test('failure after local expiry does not retain active access', () async {
  var now = DateTime.utc(2026, 7, 27);
  var fail = false;
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async {
      if (fail) throw const SupabaseTableException('temporary');
      return activeSubscription(DateTime.utc(2026, 7, 28));
    },
    currentUserId: () => 'user-1',
    now: () => now,
  );

  await controller.refresh();
  now = DateTime.utc(2026, 7, 29);
  fail = true;
  await controller.refresh(force: true);

  expect(controller.state.status, PremiumEntitlementStatus.error);
  expect(controller.state.canUsePremium, isFalse);
});
```

- [ ] **Step 3: Write concurrency and user-isolation tests**

Use `Completer<CurrentSubscriptionInfo?>` instances to verify:

```dart
test('deduplicates non-forced refreshes for the same user', () async {
  var calls = 0;
  final Completer<CurrentSubscriptionInfo?> pending =
      Completer<CurrentSubscriptionInfo?>();
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () {
      calls++;
      return pending.future;
    },
    currentUserId: () => 'user-1',
  );

  final Future<void> first = controller.refresh();
  final Future<void> second = controller.refresh();
  expect(calls, 1);

  pending.complete(activeSubscription());
  await Future.wait(<Future<void>>[first, second]);
});
```

Add the forced-refresh race test:

```dart
test('forced refresh supersedes an older response', () async {
  final List<Completer<CurrentSubscriptionInfo?>> requests =
      <Completer<CurrentSubscriptionInfo?>>[];
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () {
      final Completer<CurrentSubscriptionInfo?> request =
          Completer<CurrentSubscriptionInfo?>();
      requests.add(request);
      return request.future;
    },
    currentUserId: () => 'user-1',
  );

  final Future<void> older = controller.refresh();
  final Future<void> newer = controller.refresh(force: true);
  requests[1].complete(null);
  await newer;
  requests[0].complete(activeSubscription());
  await older;

  expect(controller.state.status, PremiumEntitlementStatus.inactive);
});
```

Add the user-isolation race test:

```dart
test('response from a previous user is ignored', () async {
  var userId = 'user-1';
  final List<Completer<CurrentSubscriptionInfo?>> requests =
      <Completer<CurrentSubscriptionInfo?>>[];
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () {
      final Completer<CurrentSubscriptionInfo?> request =
          Completer<CurrentSubscriptionInfo?>();
      requests.add(request);
      return request.future;
    },
    currentUserId: () => userId,
  );

  final Future<void> first = controller.refresh();
  userId = 'user-2';
  final Future<void> second = controller.refresh(force: true);
  requests[1].complete(null);
  await second;
  requests[0].complete(activeSubscription());
  await first;

  expect(controller.state.userId, 'user-2');
  expect(controller.state.status, PremiumEntitlementStatus.inactive);
});
```

- [ ] **Step 4: Write auth and lifecycle tests**

Inject a `StreamController<String?>` as `authUserIds`. Verify:

```dart
test('auth user change refreshes and sign-out clears state', () async {
  var currentUserId = 'user-1';
  final StreamController<String?> authChanges =
      StreamController<String?>.broadcast();
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async => activeSubscription(),
    currentUserId: () => currentUserId,
    authUserIds: authChanges.stream,
  );
  addTearDown(controller.dispose);
  addTearDown(authChanges.close);

  controller.initialize();
  await controller.refresh();
  expect(controller.state.canUsePremium, isTrue);

  currentUserId = null;
  authChanges.add(null);
  await Future<void>.delayed(Duration.zero);
  expect(controller.state.status, PremiumEntitlementStatus.inactive);
  expect(controller.state.userId, isNull);
});
```

Add the lifecycle refresh test:

```dart
test('app resume forces a fresh entitlement request', () async {
  var calls = 0;
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async {
      calls++;
      return activeSubscription();
    },
    currentUserId: () => 'user-1',
  );
  addTearDown(controller.dispose);

  controller.initialize();
  await Future<void>.delayed(Duration.zero);
  final int callsAfterInitialize = calls;

  controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
  await Future<void>.delayed(Duration.zero);

  expect(calls, callsAfterInitialize + 1);
});
```

- [ ] **Step 5: Run controller tests and verify RED**

Run:

```powershell
flutter test test/features/profile/application/premium_entitlement_controller_test.dart
```

Expected: compilation fails because the controller does not exist.

- [ ] **Step 6: Implement the state model and controller**

Create the production interface:

```dart
enum PremiumEntitlementStatus { loading, active, inactive, error }

@immutable
class PremiumEntitlementState {
  const PremiumEntitlementState({
    required this.status,
    this.subscription,
    this.error,
    this.userId,
    this.lastCheckedAt,
  });

  const PremiumEntitlementState.loading({String? userId})
      : this(status: PremiumEntitlementStatus.loading, userId: userId);

  final PremiumEntitlementStatus status;
  final CurrentSubscriptionInfo? subscription;
  final Object? error;
  final String? userId;
  final DateTime? lastCheckedAt;

  bool get isActive => status == PremiumEntitlementStatus.active;
  bool get isConfirmedInactive =>
      status == PremiumEntitlementStatus.inactive;
}

typedef PremiumSubscriptionLoader =
    Future<CurrentSubscriptionInfo?> Function();
typedef PremiumCurrentUserId = String? Function();
typedef PremiumClock = DateTime Function();
```

Use the injected clock inside the controller's own `canUsePremium` decision;
do not rely on the state getter's system clock in tests. If necessary, expose
`canUsePremium` on the controller and keep state `isActive` as a status check.

Implement:

```dart
class PremiumEntitlementController extends ChangeNotifier
    with WidgetsBindingObserver {
  PremiumEntitlementController({
    PremiumSubscriptionLoader? loadSubscription,
    PremiumCurrentUserId? currentUserId,
    Stream<String?>? authUserIds,
    PremiumClock? now,
  }) : _loadSubscription =
           loadSubscription ??
           (() => SubscriptionRepository().loadCurrentSubscription()),
       _currentUserId =
           currentUserId ??
           (() => Supabase.instance.client.auth.currentUser?.id),
       _authUserIds = authUserIds,
       _now = now ?? DateTime.now;

  static final PremiumEntitlementController instance =
      PremiumEntitlementController();

  PremiumEntitlementState _state =
      const PremiumEntitlementState.loading();
  Future<void>? _inFlight;
  String? _inFlightUserId;
  int _generation = 0;
  bool _initialized = false;
  StreamSubscription<String?>? _authSubscription;

  PremiumEntitlementState get state => _state;
  bool get canUsePremium {
    final DateTime? endDate = _state.subscription?.endDate;
    return _state.status == PremiumEntitlementStatus.active &&
        endDate != null &&
        endDate.isAfter(_now().toUtc());
  }

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    final Stream<String?> stream = _authUserIds ??
        Supabase.instance.client.auth.onAuthStateChange
            .map((AuthState event) => event.session?.user.id);
    _authSubscription = stream.listen(_handleAuthUserChanged);
    unawaited(refresh());
  }

  Future<void> retry() => refresh(force: true);
}
```

Complete `refresh`, `_handleAuthUserChanged`, stale-generation checks, active
retention, and `dispose` exactly as specified by the tests and design. Emit
redacted debug logs only inside `kDebugMode`.

- [ ] **Step 7: Run controller tests and verify GREEN**

Run:

```powershell
flutter test test/features/profile/application/premium_entitlement_controller_test.dart
```

Expected: all state, concurrency, auth, and lifecycle tests pass.

- [ ] **Step 8: Commit the shared controller**

```powershell
git add -- frontend/lib/features/profile/application/premium_entitlement_controller.dart frontend/test/features/profile/application/premium_entitlement_controller_test.dart
git commit -m "feat: centralize premium entitlement state"
```

---

### Task 3: Initialize the controller and migrate Upgrade/payment

**Files:**
- Modify: `frontend/lib/app/app_bootstrap.dart:36-66`
- Modify: `frontend/lib/features/profile/presentation/upgrade_account_page.dart`
- Modify: `frontend/lib/features/profile/presentation/upgrade_payment_page.dart`
- Create: `frontend/test/features/profile/presentation/upgrade_account_entitlement_test.dart`

**Interfaces:**
- Consumes: `PremiumEntitlementController.instance`, `.state`, `.canUsePremium`, `.initialize()`, `.refresh(force: true)`.
- Produces: Upgrade and payment screens that publish fresh state to every mounted Premium consumer.

- [ ] **Step 1: Write Upgrade shared-state widget tests**

Create an injected controller and render `UpgradeAccountPage`:

```dart
class _FakeUpgradeRepository extends SubscriptionRepository {
  @override
  Future<List<SubscriptionPaymentHistoryItem>> loadPaymentHistory() async {
    return const <SubscriptionPaymentHistoryItem>[];
  }
}

SubscriptionRepository fakeSubscriptionRepository() =>
    _FakeUpgradeRepository();

CurrentSubscriptionInfo activeSubscription() {
  return CurrentSubscriptionInfo(
    planCode: '6m',
    planName: 'Premium 6 Months',
    durationDays: 180,
    endDate: DateTime.utc(2026, 12, 14),
  );
}

testWidgets('Upgrade displays the controller active subscription',
    (WidgetTester tester) async {
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async => activeSubscription(),
    currentUserId: () => 'user-1',
    now: () => DateTime.utc(2026, 7, 27),
  );
  addTearDown(controller.dispose);
  await controller.refresh();

  await tester.pumpWidget(MaterialApp(
    home: UpgradeAccountPage(
      entitlementController: controller,
      repository: fakeSubscriptionRepository(),
    ),
  ));
  await tester.pumpAndSettle();

  expect(find.text('Premium active'), findsOneWidget);
  expect(find.textContaining('14/12/2026'), findsWidgets);
});
```

Add the error-to-active live update test:

```dart
testWidgets('Upgrade retries verification and updates without remounting',
    (WidgetTester tester) async {
  var fail = true;
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async {
      if (fail) throw const SupabaseTableException('temporary');
      return activeSubscription();
    },
    currentUserId: () => 'user-1',
    now: () => DateTime.utc(2026, 7, 27),
  );
  addTearDown(controller.dispose);
  await controller.refresh();

  await tester.pumpWidget(MaterialApp(
    home: UpgradeAccountPage(
      entitlementController: controller,
      repository: fakeSubscriptionRepository(),
    ),
  ));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('premium-entitlement-retry')), findsOneWidget);
  expect(find.text('No active subscription'), findsNothing);

  fail = false;
  await tester.tap(find.byKey(const Key('premium-entitlement-retry')));
  await tester.pumpAndSettle();

  expect(find.text('Premium active'), findsOneWidget);
});
```

Add the confirmed-inactive test:

```dart
testWidgets('confirmed inactive shows purchasable plans',
    (WidgetTester tester) async {
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async => null,
    currentUserId: () => 'user-1',
  );
  addTearDown(controller.dispose);
  await controller.refresh();

  await tester.pumpWidget(MaterialApp(
    home: UpgradeAccountPage(
      entitlementController: controller,
      repository: fakeSubscriptionRepository(),
    ),
  ));
  await tester.pumpAndSettle();

  expect(find.text('No active subscription'), findsOneWidget);
  expect(find.text('Premium 6 Months'), findsWidgets);
  expect(find.byKey(const Key('upgrade-continue')), findsOneWidget);
});
```

- [ ] **Step 2: Run the Upgrade tests and verify RED**

Run:

```powershell
flutter test test/features/profile/presentation/upgrade_account_entitlement_test.dart
```

Expected: compilation fails because `UpgradeAccountPage` does not accept the
controller and still owns `_currentSubscriptionFuture`.

- [ ] **Step 3: Initialize the controller during app bootstrap**

After `Supabase.initialize` and local controllers are initialized, add:

```dart
PremiumEntitlementController.instance.initialize();
```

Do not await the initial network refresh. The Home launcher displays loading
until the controller publishes a result.

- [ ] **Step 4: Migrate Upgrade Account to shared state**

Change the widget constructor:

```dart
class UpgradeAccountPage extends StatefulWidget {
  const UpgradeAccountPage({
    super.key,
    this.entitlementController,
    this.repository,
  });

  final PremiumEntitlementController? entitlementController;
  final SubscriptionRepository? repository;
}
```

In state:

```dart
late final PremiumEntitlementController _entitlementController;
late final SubscriptionRepository _repository;

@override
void initState() {
  super.initState();
  _entitlementController =
      widget.entitlementController ?? PremiumEntitlementController.instance;
  _repository = widget.repository ?? SubscriptionRepository();
  _entitlementController.addListener(_handleEntitlementChanged);
  unawaited(_entitlementController.refresh(force: true));
  _paymentHistoryFuture = _repository.loadPaymentHistory();
}

void _handleEntitlementChanged() {
  if (mounted) setState(() {});
}

@override
void dispose() {
  _entitlementController.removeListener(_handleEntitlementChanged);
  _controller.dispose();
  super.dispose();
}
```

Replace `_currentSubscriptionFuture` parameters in `_CurrentPlanStatus`,
`_SubscriptionDetailsCard`, and `_BottomContinueBar` with one
`PremiumEntitlementState entitlementState`. Render:

- loading spinner for `loading`;
- plan/end date for `active`;
- no-plan state for `inactive`;
- verification error plus Retry for `error`.

Change `_onContinue` to reject purchase only when
`_entitlementController.canUsePremium` is true. Do not interpret `error` as
inactive; require retry before purchase. Add
`key: const Key('upgrade-continue')` to the bottom continue button and
`key: const Key('premium-entitlement-retry')` to the verification retry
button so the state transitions remain testable.

- [ ] **Step 5: Add payment entitlement refresh tests**

Extract a small injected helper on `UpgradePaymentPage`:

```dart
Future<bool> _verifyPremiumAfterPurchase() async {
  await _entitlementController.refresh(force: true);
  return _entitlementController.canUsePremium;
}
```

Add this fake payment repository:

```dart
class _FakePaymentRepository extends SubscriptionRepository {
  @override
  Future<SubscriptionPlanInfo> loadPlan(String code) async {
    return fallbackPlan(code);
  }

  @override
  Future<SubscriptionPurchaseResult> confirmStripeCheckout({
    required String sessionId,
  }) async {
    return SubscriptionPurchaseResult(
      paymentId: 'payment-1',
      subscriptionId: 'subscription-1',
      originalAmountMinor: 1999,
      discountMinor: 0,
      finalAmountMinor: 1999,
      voucherCode: null,
      subscriptionEndDate: DateTime.utc(2026, 12, 14),
    );
  }
}
```

Add the payment-verification regression test:

```dart
testWidgets('payment result survives entitlement verification failure',
    (WidgetTester tester) async {
  var fail = true;
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async {
      if (fail) throw const SupabaseTableException('temporary');
      return activeSubscription();
    },
    currentUserId: () => 'user-1',
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(MaterialApp(
    home: UpgradePaymentPage(
      planId: '6m',
      checkoutSessionId: 'cs_test_123',
      repository: _FakePaymentRepository(),
      entitlementController: controller,
      awardPurchase: (_) async {},
    ),
  ));
  await tester.pumpAndSettle();

  expect(find.textContaining('Payment completed'), findsOneWidget);
  expect(find.textContaining('could not verify Premium'), findsOneWidget);
  expect(find.byKey(const Key('payment-premium-retry')), findsOneWidget);

  fail = false;
  await tester.tap(find.byKey(const Key('payment-premium-retry')));
  await tester.pumpAndSettle();

  expect(find.textContaining('Premium Benefits Activated'), findsOneWidget);
  expect(find.textContaining('could not verify Premium'), findsNothing);
});
```

Add the immediately verified test:

```dart
testWidgets('verified payment shows activated benefits immediately',
    (WidgetTester tester) async {
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async => activeSubscription(),
    currentUserId: () => 'user-1',
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(MaterialApp(
    home: UpgradePaymentPage(
      planId: '6m',
      checkoutSessionId: 'cs_test_123',
      repository: _FakePaymentRepository(),
      entitlementController: controller,
      awardPurchase: (_) async {},
    ),
  ));
  await tester.pumpAndSettle();

  expect(find.textContaining('Premium Benefits Activated'), findsOneWidget);
  expect(find.byKey(const Key('payment-premium-retry')), findsNothing);
});
```

No test may launch Stripe or access the network.

- [ ] **Step 6: Refresh entitlement after both payment completion paths**

Inject `PremiumEntitlementController` into `UpgradePaymentPage`,
`_PaymentConfirmationPage`, and `_PaymentSuccessPage`. Add production-default
dependencies to the public page:

```dart
typedef SubscriptionPurchaseAwarder =
    Future<void> Function(SubscriptionPurchaseResult result);

class UpgradePaymentPage extends StatefulWidget {
  const UpgradePaymentPage({
    super.key,
    required this.planId,
    this.checkoutSessionId,
    this.repository,
    this.entitlementController,
    this.awardPurchase,
  });

  final String planId;
  final String? checkoutSessionId;
  final SubscriptionRepository? repository;
  final PremiumEntitlementController? entitlementController;
  final SubscriptionPurchaseAwarder? awardPurchase;
}
```

Resolve the existing repository, controller singleton, and
`LoyaltyAwardService` awarder in state. Tests inject the no-op awarder shown
above.

After `confirmStripeCheckout` and after an immediate
`checkout.isCompleted` result:

```dart
await _entitlementController.refresh(force: true);
final bool premiumVerified = _entitlementController.canUsePremium;
_showSuccess(result, premiumVerified: premiumVerified);
```

The success page always retains `SubscriptionPurchaseResult`. When
`premiumVerified` is false because state is `error`, show:

```text
Payment completed. We could not verify Premium yet.
```

and a Retry button that calls `refresh(force: true)`. Show activated benefits
only after `canUsePremium` becomes true. Assign
`key: const Key('payment-premium-retry')` to that Retry button.

- [ ] **Step 7: Run profile entitlement tests and verify GREEN**

Run:

```powershell
flutter test test/features/profile/application/premium_entitlement_controller_test.dart test/features/profile/data/subscription_repository_test.dart test/features/profile/presentation/upgrade_account_entitlement_test.dart
```

Expected: controller, repository, Upgrade, and payment verification tests pass.

- [ ] **Step 8: Commit Upgrade/payment synchronization**

```powershell
git add -- frontend/lib/app/app_bootstrap.dart frontend/lib/features/profile/presentation/upgrade_account_page.dart frontend/lib/features/profile/presentation/upgrade_payment_page.dart frontend/test/features/profile/presentation/upgrade_account_entitlement_test.dart
git commit -m "fix: synchronize premium upgrade state"
```

---

### Task 4: Migrate AI Chat and delete its boolean cache

**Files:**
- Modify: `frontend/lib/features/ai_chat/presentation/widgets/ai_chat_home_launcher.dart`
- Modify: `frontend/lib/features/ai_chat/presentation/ai_chat_page.dart`
- Modify: `frontend/test/features/ai_chat/presentation/ai_chat_home_launcher_test.dart`
- Modify: `frontend/test/features/ai_chat/presentation/ai_chat_page_test.dart`
- Delete: `frontend/lib/features/ai_chat/data/ai_chat_premium_access_cache.dart`
- Delete: `frontend/test/features/ai_chat/data/ai_chat_premium_access_cache_test.dart`

**Interfaces:**
- Consumes: injected or singleton `PremiumEntitlementController`.
- Produces: AI launcher and page that react to shared state without remounting.

- [ ] **Step 1: Rewrite launcher tests around the controller**

Replace `premiumLoader` setup with:

```dart
Widget buildLauncher({
  required PremiumEntitlementController controller,
  VoidCallback? onOpenChat,
  VoidCallback? onUpgrade,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AiChatHomeLauncher(
        entitlementController: controller,
        onOpenChat: onOpenChat,
        onUpgrade: onUpgrade,
      ),
    ),
  );
}
```

Add tests:

```dart
testWidgets('shows retry rather than lock for verification error',
    (WidgetTester tester) async {
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async => throw const SupabaseTableException('down'),
    currentUserId: () => 'user-1',
  );
  addTearDown(controller.dispose);
  await controller.refresh();

  await tester.pumpWidget(buildLauncher(controller: controller));
  await tester.pump();

  expect(find.byKey(const Key('ai-chat-home-retry')), findsOneWidget);
  expect(find.byKey(const Key('ai-chat-home-lock')), findsNothing);
});
```

Add the reported regression test:

```dart
testWidgets('mounted launcher unlocks after a later successful refresh',
    (WidgetTester tester) async {
  var fail = true;
  var openedChat = 0;
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async {
      if (fail) throw const SupabaseTableException('temporary');
      return activeSubscription();
    },
    currentUserId: () => 'user-1',
  );
  addTearDown(controller.dispose);
  await controller.refresh();

  await tester.pumpWidget(buildLauncher(
    controller: controller,
    onOpenChat: () => openedChat++,
  ));
  await tester.pump();
  expect(find.byKey(const Key('ai-chat-home-retry')), findsOneWidget);

  fail = false;
  await controller.refresh(force: true);
  await tester.pump();
  expect(find.byKey(const Key('ai-chat-home-lock')), findsNothing);

  await tester.tap(find.byKey(const Key('ai-chat-home-launcher')));
  expect(openedChat, 1);
});
```

- [ ] **Step 2: Rewrite AI Chat page tests around shared state**

Inject the same controller into `AiChatPage`. Add a table-driven state test:

```dart
for (final ({
  PremiumEntitlementStatus status,
  String expectedKey,
}) testCase in <({
  PremiumEntitlementStatus status,
  String expectedKey,
})>[
  (
    status: PremiumEntitlementStatus.active,
    expectedKey: 'ai-chat-composer',
  ),
  (
    status: PremiumEntitlementStatus.inactive,
    expectedKey: 'ai-chat-upgrade',
  ),
  (
    status: PremiumEntitlementStatus.error,
    expectedKey: 'ai-chat-premium-retry',
  ),
]) {
  testWidgets('AI Chat renders ${testCase.status.name}',
      (WidgetTester tester) async {
    final PremiumEntitlementController controller =
        await controllerInState(testCase.status);
    addTearDown(controller.dispose);
    await tester.pumpWidget(testApp(
      AiChatPage(entitlementController: controller),
    ));
    await tester.pump();
    expect(find.byKey(Key(testCase.expectedKey)), findsOneWidget);
  });
}
```

Add these local test helpers so this file does not depend on private helpers
from another test:

```dart
CurrentSubscriptionInfo activeSubscription() {
  return CurrentSubscriptionInfo(
    planCode: '6m',
    planName: 'Premium 6 Months',
    durationDays: 180,
    endDate: DateTime.utc(2026, 12, 14),
  );
}

Future<PremiumEntitlementController> controllerInState(
  PremiumEntitlementStatus status,
) async {
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async {
      return switch (status) {
        PremiumEntitlementStatus.active => activeSubscription(),
        PremiumEntitlementStatus.inactive => null,
        PremiumEntitlementStatus.error =>
          throw const SupabaseTableException('verification failed'),
        PremiumEntitlementStatus.loading =>
          throw StateError('Use an unrefreshed controller for loading tests'),
      };
    },
    currentUserId: () => 'user-1',
  );
  if (status != PremiumEntitlementStatus.loading) {
    await controller.refresh();
  }
  return controller;
}
```

Preserve the existing-conversation behavior with the real test repository and
controller already used in this file:

```dart
testWidgets('inactive user can still read an existing conversation',
    (WidgetTester tester) async {
  final PremiumEntitlementController controller =
      await controllerInState(PremiumEntitlementStatus.inactive);
  final _FakeRepository repository = _FakeRepository()
    ..messagePage = AiChatMessagePage(
      items: <AiChatMessage>[_assistantMessage()],
      nextCursor: null,
    );
  final AiChatController chat = AiChatController(
    repository: repository,
    audioPlayback: _FakeAudioPlayback(),
  );
  addTearDown(controller.dispose);
  addTearDown(chat.dispose);

  await tester.pumpWidget(testApp(AiChatPage(
    conversationId: 'conversation-1',
    controller: chat,
    entitlementController: controller,
  )));
  await tester.pumpAndSettle();

  expect(find.text('Try the Imperial City.'), findsOneWidget);
  expect(find.byKey(const Key('ai-chat-composer')), findsNothing);
});
```

- [ ] **Step 3: Run AI Chat presentation tests and verify RED**

Run:

```powershell
flutter test test/features/ai_chat/presentation/ai_chat_home_launcher_test.dart test/features/ai_chat/presentation/ai_chat_page_test.dart
```

Expected: compilation fails until the widgets accept the shared controller.

- [ ] **Step 4: Migrate the Home launcher**

Replace `premiumLoader` and private `_isPremium` with:

```dart
final PremiumEntitlementController? entitlementController;

late final PremiumEntitlementController _entitlementController;

@override
void initState() {
  super.initState();
  _positionStore = widget.positionStore ?? AiChatLauncherPositionStore();
  _entitlementController =
      widget.entitlementController ?? PremiumEntitlementController.instance;
  _entitlementController.addListener(_handleEntitlementChanged);
  unawaited(_positionStore.load().then(_applyPosition));
}
```

In `dispose`, remove the listener. Render state keys:

- `ai-chat-home-loading`;
- `ai-chat-home-lock`;
- `ai-chat-home-retry`.

Tap behavior:

```dart
switch (_entitlementController.state.status) {
  case PremiumEntitlementStatus.active:
    _openChat();
  case PremiumEntitlementStatus.inactive:
    _openUpgrade();
  case PremiumEntitlementStatus.error:
    unawaited(_entitlementController.retry());
  case PremiumEntitlementStatus.loading:
    return;
}
```

- [ ] **Step 5: Migrate the AI Chat page**

Accept `PremiumEntitlementController? entitlementController`, listen in
`initState`, and remove `premiumLoader`, `_checkingPremium`,
`_isPremium`, `_loadPremium`, and `_defaultPremiumLoader`.

Build from `entitlementController.state.status`. Use
`entitlementController.canUsePremium` for the composer and
`AiChatBubble.canUsePremium`.

Add `_PremiumVerificationError` with key `ai-chat-premium-retry` and a Retry
button. Only `_PremiumGate` may navigate to Upgrade, and it is rendered only
for `inactive`.

- [ ] **Step 6: Delete the feature-specific cache**

Delete:

```text
frontend/lib/features/ai_chat/data/ai_chat_premium_access_cache.dart
frontend/test/features/ai_chat/data/ai_chat_premium_access_cache_test.dart
```

Run:

```powershell
rg -n "AiChatPremiumAccessCache|premiumLoader|_isPremium" frontend/lib/features/ai_chat
```

Expected: no remaining feature-specific entitlement source.

- [ ] **Step 7: Run all AI Chat Flutter and server tests**

Run:

```powershell
flutter test test/features/ai_chat
```

Then from `backend`:

```powershell
deno test supabase/functions/ai-chat/ai_chat_domain_test.ts supabase/functions/ai-chat/ai_chat_handler_test.ts supabase/functions/_shared/vbee_tts_test.ts
```

Expected: all Flutter and Deno AI Chat tests pass; server Premium rejection
tests remain enabled.

- [ ] **Step 8: Commit AI Chat migration**

```powershell
git add -- frontend/lib/features/ai_chat frontend/test/features/ai_chat
git commit -m "fix: reactively gate ai chat premium"
```

---

### Task 5: Migrate Premium Translate to the shared controller

**Files:**
- Modify: `frontend/lib/features/translate/presentation/translate_page.dart:95-155`
- Modify: `frontend/test/features/translate/presentation/translate_page_test.dart`

**Interfaces:**
- Consumes: `PremiumEntitlementController.state`, `.canUsePremium`, `.refresh(force: true)`.
- Produces: Premium Translate mode that upgrades only after confirmed inactive and retries verification errors.

- [ ] **Step 1: Add Translate entitlement tests**

Add local helpers:

```dart
CurrentSubscriptionInfo activeSubscription() {
  return CurrentSubscriptionInfo(
    planCode: '6m',
    planName: 'Premium 6 Months',
    durationDays: 180,
    endDate: DateTime.utc(2026, 12, 14),
  );
}

Widget translateTestApp(PremiumEntitlementController controller) {
  final GoRouter router = GoRouter(
    initialLocation: '/translate',
    routes: <RouteBase>[
      GoRoute(
        path: '/translate',
        builder: (_, __) =>
            TranslatePage(entitlementController: controller),
      ),
      GoRoute(
        path: '/profile/upgrade',
        builder: (_, __) => const Scaffold(
          body: Text('Upgrade destination'),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

Future<void> selectPremiumMode(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Translation mode'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('AI Premium'));
  await tester.pump();
}
```

Add an active-state test:

```dart
testWidgets('active entitlement switches to Premium mode',
    (WidgetTester tester) async {
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async => activeSubscription(),
    currentUserId: () => 'user-1',
  );
  addTearDown(controller.dispose);
  await controller.refresh();

  await tester.pumpWidget(translateTestApp(controller));
  await selectPremiumMode(tester);
  await tester.pumpAndSettle();

  expect(find.text('AI'), findsOneWidget);
  expect(find.text('Upgrade destination'), findsNothing);
});
```

Add a confirmed-inactive navigation test:

```dart
testWidgets('confirmed inactive opens Upgrade',
    (WidgetTester tester) async {
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async => null,
    currentUserId: () => 'user-1',
  );
  addTearDown(controller.dispose);
  await controller.refresh();

  await tester.pumpWidget(translateTestApp(controller));
  await selectPremiumMode(tester);
  await tester.pumpAndSettle();

  expect(find.text('Upgrade destination'), findsOneWidget);
});
```

Add the verification-error regression. It must stay on Translate and recover
without rebuilding the page:

```dart
testWidgets('verification retry unlocks Premium without opening Upgrade',
    (WidgetTester tester) async {
  var shouldFail = true;
  final PremiumEntitlementController controller =
      PremiumEntitlementController(
    loadSubscription: () async {
      if (shouldFail) {
        throw const SupabaseTableException('down');
      }
      return activeSubscription();
    },
    currentUserId: () => 'user-1',
  );
  addTearDown(controller.dispose);
  await controller.refresh();

  await tester.pumpWidget(translateTestApp(controller));
  await selectPremiumMode(tester);
  await tester.pump();

  expect(find.byKey(const Key('translate-premium-retry')), findsOneWidget);
  expect(find.text('Upgrade destination'), findsNothing);

  shouldFail = false;
  await tester.tap(find.byKey(const Key('translate-premium-retry')));
  await tester.pumpAndSettle();

  expect(find.text('AI'), findsOneWidget);
  expect(find.text('Upgrade destination'), findsNothing);
});
```

Keep the existing `typing does not start translation until the user confirms`
and dark-surface tests unchanged. They protect the Basic/offline interaction
while this task only replaces entitlement selection.

- [ ] **Step 2: Run Translate tests and verify RED**

Run:

```powershell
flutter test test/features/translate/presentation/translate_page_test.dart
```

Expected: compilation fails because `TranslatePage` does not accept the
controller and its current catch block silently returns to Basic.

- [ ] **Step 3: Inject and observe the controller**

Add:

```dart
final PremiumEntitlementController? entitlementController;
```

Resolve the singleton in state. Replace the direct
`SubscriptionRepository().loadCurrentSubscription()` call in
`_handleModeChange`.

- [ ] **Step 4: Implement explicit mode-change outcomes**

Use:

```dart
Future<void> _handleModeChange(TranslateMode mode) async {
  if (mode == TranslateMode.basic) {
    setState(() => _mode = TranslateMode.basic);
    return;
  }

  final PremiumEntitlementState state = _entitlementController.state;
  if (state.status == PremiumEntitlementStatus.loading) {
    await _entitlementController.refresh();
  }

  if (_entitlementController.canUsePremium) {
    if (mounted) setState(() => _mode = TranslateMode.premium);
    return;
  }

  if (_entitlementController.state.isConfirmedInactive) {
    _showPremiumRequiredAndOpenUpgrade();
    return;
  }

  _showPremiumVerificationRetry();
}
```

The Retry action uses `refresh(force: true)` and re-evaluates the same requested
Premium mode. Give its `SnackBarAction` the key
`translate-premium-retry`. Do not modify `_translate` Basic ML Kit behavior.

- [ ] **Step 5: Run Translate and entitlement tests**

Run:

```powershell
flutter test test/features/translate/presentation/translate_page_test.dart test/features/profile/application/premium_entitlement_controller_test.dart
```

Expected: all tests pass, including Basic offline translation coverage.

- [ ] **Step 6: Commit Translate migration**

```powershell
git add -- frontend/lib/features/translate/presentation/translate_page.dart frontend/test/features/translate/presentation/translate_page_test.dart
git commit -m "fix: share premium state with translate"
```

---

### Task 6: Verify cross-screen consistency and full regression suite

**Files:**
- Read: all files changed in Tasks 1-5
- Test: `frontend/test/features/profile/application/premium_entitlement_controller_test.dart`
- Test: `frontend/test/features/profile/presentation/upgrade_account_entitlement_test.dart`
- Test: `frontend/test/features/ai_chat/presentation/ai_chat_home_launcher_test.dart`
- Test: `frontend/test/features/ai_chat/presentation/ai_chat_page_test.dart`
- Test: `frontend/test/features/translate/presentation/translate_page_test.dart`

**Interfaces:**
- Consumes: the completed shared entitlement flow.
- Produces: evidence that every Premium surface agrees and unrelated Flutter behavior remains green.

- [ ] **Step 1: Run static searches for forbidden duplicate state**

Run:

```powershell
rg -n "AiChatPremiumAccessCache|premiumLoader|loadCurrentSubscription\\(" frontend/lib/features/ai_chat frontend/lib/features/translate
```

Expected:

- no `AiChatPremiumAccessCache`;
- no AI Chat `premiumLoader`;
- no direct `loadCurrentSubscription` calls in AI Chat or Translate.

Run:

```powershell
rg -n "PremiumEntitlementController" frontend/lib/features/ai_chat frontend/lib/features/translate frontend/lib/features/profile frontend/lib/app/app_bootstrap.dart
```

Expected: Home launcher, AI Chat page, Translate, Upgrade, payment, and bootstrap
all use the shared controller.

- [ ] **Step 2: Run focused regression tests**

From `frontend`:

```powershell
flutter test test/features/profile/application/premium_entitlement_controller_test.dart test/features/profile/data/subscription_repository_test.dart test/features/profile/presentation/upgrade_account_entitlement_test.dart test/features/ai_chat test/features/translate/presentation/translate_page_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 3: Run the complete Flutter test suite**

From `frontend`:

```powershell
flutter test
```

Expected: all Flutter tests pass with zero failures.

- [ ] **Step 4: Run AI Chat server tests**

From `backend`:

```powershell
deno test supabase/functions/ai-chat/ai_chat_domain_test.ts supabase/functions/ai-chat/ai_chat_handler_test.ts supabase/functions/_shared/vbee_tts_test.ts
```

Expected: all tests pass, including non-Premium message and speech rejection.

- [ ] **Step 5: Perform a device smoke test**

On the authenticated Premium test account:

1. Open Home and verify the AI launcher has no lock.
2. Open Upgrade and verify the same plan/end date.
3. Return to Home without restarting and open AI Chat.
4. Send one AI Chat message.
5. Enter Premium Translate and perform one translation.
6. Disable network, force a refresh, and verify the UI shows retry rather than
   `Free` or an Upgrade lock.
7. Restore network, tap Retry, and verify Premium access returns.

- [ ] **Step 6: Verify Git scope and commit final adjustments**

Run:

```powershell
git status --short
git diff --check
git log -6 --oneline
```

Expected: only the planned Premium files differ from the base branch; unrelated
report, architecture, browser, and VS Code files are untouched.

If the final verification required small test or formatting corrections:

```powershell
git add -- frontend/lib frontend/test
git commit -m "test: cover premium entitlement regression"
```
