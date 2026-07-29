import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/network/supabase_function_client.dart';
import '../../../core/network/supabase_table_client.dart';

class SubscriptionPlanInfo {
  const SubscriptionPlanInfo({
    required this.code,
    required this.name,
    required this.durationDays,
    required this.priceMinor,
    required this.currency,
    this.id,
  });

  final String? id;
  final String code;
  final String name;
  final int durationDays;
  final int priceMinor;
  final String currency;

  String get priceLabel => _money(priceMinor);

  static String _money(int amountMinor) =>
      '\$${(amountMinor / 100).toStringAsFixed(2)}';
}

class VoucherPreview {
  const VoucherPreview({
    required this.code,
    required this.discountMinor,
    required this.finalAmountMinor,
    required this.message,
  });

  final String code;
  final int discountMinor;
  final int finalAmountMinor;
  final String message;
}

class SubscriptionVoucherOption {
  const SubscriptionVoucherOption({
    required this.code,
    required this.title,
    required this.description,
    required this.discountLabel,
    required this.expiryLabel,
    required this.type,
    required this.value,
    this.minAmountMinor,
  });

  final String code;
  final String title;
  final String description;
  final String discountLabel;
  final String expiryLabel;
  final String type;
  final int value;
  final int? minAmountMinor;
}

class SubscriptionPurchaseResult {
  const SubscriptionPurchaseResult({
    required this.paymentId,
    required this.subscriptionId,
    required this.originalAmountMinor,
    required this.discountMinor,
    required this.finalAmountMinor,
    required this.voucherCode,
    required this.subscriptionEndDate,
  });

  final String paymentId;
  final String subscriptionId;
  final int originalAmountMinor;
  final int discountMinor;
  final int finalAmountMinor;
  final String? voucherCode;
  final DateTime? subscriptionEndDate;
}

class CurrentSubscriptionInfo {
  const CurrentSubscriptionInfo({
    required this.planCode,
    required this.planName,
    required this.durationDays,
    required this.endDate,
  });

  final String planCode;
  final String planName;
  final int durationDays;
  final DateTime? endDate;
}

class SubscriptionPaymentHistoryItem {
  const SubscriptionPaymentHistoryItem({
    required this.paymentId,
    required this.planCode,
    required this.planName,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.provider,
    required this.method,
    required this.createdAt,
    required this.confirmedAt,
    this.externalRef,
  });

  final String paymentId;
  final String planCode;
  final String planName;
  final int amountMinor;
  final String currency;
  final String status;
  final String provider;
  final String method;
  final DateTime? createdAt;
  final DateTime? confirmedAt;
  final String? externalRef;

  String get amountLabel =>
      '${currency.toUpperCase()} ${(amountMinor / 100).toStringAsFixed(2)}';
}

class SubscriptionCheckoutResult {
  const SubscriptionCheckoutResult({
    required this.status,
    this.checkoutUrl,
    this.sessionId,
    this.purchaseResult,
  });

  final String status;
  final String? checkoutUrl;
  final String? sessionId;
  final SubscriptionPurchaseResult? purchaseResult;

  bool get requiresCheckout => status == 'requires_checkout';
  bool get isCompleted => status == 'completed';
}

typedef SubscriptionCurrentUserId = String? Function();

class SubscriptionRepository {
  SubscriptionRepository({
    SupabaseClient? client,
    SupabaseFunctionClient? functionClient,
    SupabaseTableClient? tableClient,
    SubscriptionCurrentUserId? currentUserIdProvider,
  }) : _clientOverride = client,
       _functionClient = functionClient,
       _tableClient = tableClient,
       _currentUserIdProvider = currentUserIdProvider;

  final SupabaseClient? _clientOverride;
  final SupabaseFunctionClient? _functionClient;
  final SupabaseTableClient? _tableClient;
  final SubscriptionCurrentUserId? _currentUserIdProvider;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  SupabaseFunctionClient get _resolvedFunctionClient =>
      _functionClient ?? SupabaseFunctionClient(client: _client);

  SupabaseTableClient get _resolvedTableClient =>
      _tableClient ?? const SupabaseTableClient();

  static const Map<String, SubscriptionPlanInfo> fallbackPlans =
      <String, SubscriptionPlanInfo>{
        '1m': SubscriptionPlanInfo(
          id: null,
          code: '1m',
          name: 'Premium 1 Month',
          durationDays: 30,
          priceMinor: 499,
          currency: 'USD',
        ),
        '6m': SubscriptionPlanInfo(
          id: null,
          code: '6m',
          name: 'Premium 6 Months',
          durationDays: 180,
          priceMinor: 1999,
          currency: 'USD',
        ),
        '12m': SubscriptionPlanInfo(
          id: null,
          code: '12m',
          name: 'Premium 12 Months',
          durationDays: 365,
          priceMinor: 2999,
          currency: 'USD',
        ),
      };

  SubscriptionPlanInfo fallbackPlan(String code) =>
      fallbackPlans[code] ?? fallbackPlans['6m']!;

  Future<SubscriptionPlanInfo> loadPlan(String code) async {
    try {
      final Map<String, dynamic>? row = await _resolvedTableClient.maybeSingle(
        'subscription plan',
        () async {
          return _client
              .from('subscription_plan')
              .select(
                'id_subscription_plan, code, name, duration_days, price_minor',
              )
              .eq('code', code)
              .maybeSingle();
        },
      );
      if (row == null) return fallbackPlan(code);
      return SubscriptionPlanInfo(
        id: row['id_subscription_plan']?.toString(),
        code: (row['code'] as String?) ?? code,
        name: (row['name'] as String?) ?? fallbackPlan(code).name,
        durationDays:
            (row['duration_days'] as num?)?.toInt() ??
            fallbackPlan(code).durationDays,
        priceMinor:
            (row['price_minor'] as num?)?.toInt() ??
            fallbackPlan(code).priceMinor,
        currency: 'USD',
      );
    } catch (_) {
      return fallbackPlan(code);
    }
  }

  Future<CurrentSubscriptionInfo?> loadCurrentSubscription() async {
    final String? userId = _currentUserIdProvider != null
        ? _currentUserIdProvider()
        : _client.auth.currentUser?.id;
    if (userId == null) return null;

    final List<Map<String, dynamic>> rows = await _resolvedTableClient.list(
      'current subscription',
      () async {
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
      },
    );

    if (rows.isEmpty) return null;

    final Map<String, dynamic> row = rows.first;
    final Object? rawPlan = row['subscription_plan'];
    if (rawPlan is! Map) {
      throw const SupabaseTableException(
        'Unexpected current subscription plan response.',
      );
    }

    final Map<String, dynamic> plan = Map<String, dynamic>.from(rawPlan);
    final DateTime? endDate = DateTime.tryParse(
      row['end_date']?.toString() ?? '',
    );
    final Object? durationDays = plan['duration_days'];
    if (endDate == null ||
        plan['code'] == null ||
        plan['name'] == null ||
        durationDays is! num) {
      throw const SupabaseTableException(
        'Unexpected current subscription response.',
      );
    }

    return CurrentSubscriptionInfo(
      planCode: plan['code'].toString(),
      planName: plan['name'].toString(),
      durationDays: durationDays.toInt(),
      endDate: endDate,
    );
  }

  Future<List<SubscriptionPaymentHistoryItem>> loadPaymentHistory() async {
    final User? user = _client.auth.currentUser;
    if (user == null) return const <SubscriptionPaymentHistoryItem>[];

    try {
      final List<Map<String, dynamic>> rows = await _resolvedTableClient.list(
        'subscription payment history',
        () async {
          return _client
              .from('payment')
              .select(
                'id_payment, amount_minor, currency, status, provider, method, external_ref, created_at, confirmed_at, subscription_plan:id_subscription_plan(code, name)',
              )
              .eq('id_user', user.id)
              .order('created_at', ascending: false)
              .limit(12);
        },
      );

      return rows
          .map((Map<String, dynamic> row) {
            final Object? rawPlan = row['subscription_plan'];
            final Map<String, dynamic> plan = rawPlan is Map
                ? Map<String, dynamic>.from(rawPlan)
                : <String, dynamic>{};
            return SubscriptionPaymentHistoryItem(
              paymentId: row['id_payment']?.toString() ?? '',
              planCode: plan['code']?.toString() ?? '',
              planName: plan['name']?.toString() ?? 'Premium subscription',
              amountMinor: (row['amount_minor'] as num?)?.toInt() ?? 0,
              currency: row['currency']?.toString() ?? 'USD',
              status: row['status']?.toString() ?? '',
              provider: row['provider']?.toString() ?? '',
              method: row['method']?.toString() ?? '',
              externalRef: row['external_ref']?.toString(),
              createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
              confirmedAt: DateTime.tryParse(
                row['confirmed_at']?.toString() ?? '',
              ),
            );
          })
          .toList(growable: false);
    } catch (_) {
      return const <SubscriptionPaymentHistoryItem>[];
    }
  }

  Future<VoucherPreview> previewVoucher({
    required SubscriptionPlanInfo plan,
    required String code,
  }) async {
    final String normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw Exception('Enter a voucher code first.');
    }

    final VoucherPreview? loyaltyPreview = await _previewLoyaltyWalletVoucher(
      plan: plan,
      code: normalized,
    );
    if (loyaltyPreview != null) return loyaltyPreview;

    final Map<String, dynamic>? row = await _resolvedTableClient.maybeSingle(
      'subscription voucher',
      () async {
        return _client
            .from('voucher')
            .select(
              'code, type, value, max_discount_value, min_order_amount_min, id_applicable_plan',
            )
            .ilike('code', normalized)
            .eq('status', 'active')
            .maybeSingle();
      },
    );

    if (row == null) {
      throw Exception('Voucher is invalid or expired.');
    }

    final String? applicablePlanId = row['id_applicable_plan']?.toString();
    if (applicablePlanId != null &&
        plan.id != null &&
        applicablePlanId != plan.id) {
      throw Exception('This voucher is not valid for the selected plan.');
    }

    final int minOrder = (row['min_order_amount_min'] as num?)?.toInt() ?? 0;
    if (plan.priceMinor < minOrder) {
      throw Exception('Selected plan does not meet voucher minimum spend.');
    }

    final String type = ((row['type'] as String?) ?? '').toLowerCase();
    final int value = (row['value'] as num?)?.toInt() ?? 0;
    final int? maxDiscount = (row['max_discount_value'] as num?)?.toInt();
    int discount;
    if (type == 'percent' || type == 'percentage') {
      discount = (plan.priceMinor * value / 100).floor();
      if (maxDiscount != null) {
        discount = discount > maxDiscount ? maxDiscount : discount;
      }
    } else {
      discount = value;
    }

    if (discount < 0) discount = 0;
    if (discount > plan.priceMinor) discount = plan.priceMinor;

    return VoucherPreview(
      code: normalized,
      discountMinor: discount,
      finalAmountMinor: plan.priceMinor - discount,
      message: 'Voucher applied: -${SubscriptionPlanInfo._money(discount)}',
    );
  }

  Future<List<SubscriptionVoucherOption>> loadLoyaltySubscriptionVouchers({
    required SubscriptionPlanInfo plan,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) return const <SubscriptionVoucherOption>[];

    try {
      final List<Map<String, dynamic>> rows = await _resolvedTableClient.list(
        'loyalty subscription vouchers',
        () async {
          return _client
              .from('voucher_wallet')
              .select(
                'wallet_code, status, expires_at, voucher_config:id_voucher(title, description, discount_type, discount_value, target_type)',
              )
              .eq('id_user', user.id)
              .eq('status', 'available')
              .order('redeemed_at', ascending: false);
        },
      );

      return rows
          .map((Map<String, dynamic> row) {
            final DateTime? expiresAt = DateTime.tryParse(
              row['expires_at']?.toString() ?? '',
            );
            if (expiresAt != null &&
                expiresAt.isBefore(DateTime.now().toUtc())) {
              return null;
            }
            final Object? rawVoucher = row['voucher_config'];
            if (rawVoucher is! Map) return null;
            final Map<String, dynamic> voucher = Map<String, dynamic>.from(
              rawVoucher,
            );
            final String? targetType = voucher['target_type']?.toString();
            if (targetType != null && targetType != 'subscription') {
              return null;
            }

            final String type = voucher['discount_type']?.toString() ?? 'fixed';
            final int value = (voucher['discount_value'] as num?)?.toInt() ?? 0;
            return SubscriptionVoucherOption(
              code: row['wallet_code']?.toString() ?? '',
              title: voucher['title']?.toString() ?? 'Loyalty voucher',
              description:
                  voucher['description']?.toString() ??
                  'Redeemed from loyalty rewards',
              discountLabel: _discountLabel(type, value),
              expiryLabel: _expiryLabel(row['expires_at']),
              type: type,
              value: value,
            );
          })
          .whereType<SubscriptionVoucherOption>()
          .where((SubscriptionVoucherOption option) => option.code.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <SubscriptionVoucherOption>[];
    }
  }

  Future<VoucherPreview?> _previewLoyaltyWalletVoucher({
    required SubscriptionPlanInfo plan,
    required String code,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) return null;

    final Map<String, dynamic>? row = await _resolvedTableClient.maybeSingle(
      'loyalty wallet voucher',
      () async {
        return _client
            .from('voucher_wallet')
            .select(
              'wallet_code, status, expires_at, voucher_config:id_voucher(title, discount_type, discount_value, target_type)',
            )
            .eq('id_user', user.id)
            .eq('wallet_code', code)
            .maybeSingle();
      },
    );

    if (row == null) return null;

    if (row['status']?.toString() != 'available') {
      throw Exception('Voucher is already used or unavailable.');
    }

    final DateTime? expiresAt = DateTime.tryParse(
      row['expires_at']?.toString() ?? '',
    );
    if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
      throw Exception('Voucher is expired.');
    }

    final Object? rawVoucher = row['voucher_config'];
    if (rawVoucher is! Map) {
      throw Exception('Voucher configuration not found.');
    }
    final Map<String, dynamic> voucher = Map<String, dynamic>.from(rawVoucher);
    final String? targetType = voucher['target_type']?.toString();
    if (targetType != null && targetType != 'subscription') {
      throw Exception('This voucher is not valid for subscription upgrades.');
    }

    final String type = voucher['discount_type']?.toString() ?? 'fixed';
    final int value = (voucher['discount_value'] as num?)?.toInt() ?? 0;
    final int discount = _calculateDiscount(
      plan.priceMinor,
      type: type,
      value: value,
    );

    return VoucherPreview(
      code: code,
      discountMinor: discount,
      finalAmountMinor: plan.priceMinor - discount,
      message:
          'Loyalty voucher applied: -${SubscriptionPlanInfo._money(discount)}',
    );
  }

  int _calculateDiscount(
    int amountMinor, {
    required String type,
    required int value,
  }) {
    if (type == 'percent' || type == 'percentage') {
      return (amountMinor * value / 100).floor().clamp(0, amountMinor);
    }
    return value.clamp(0, amountMinor);
  }

  String _discountLabel(String type, int value) {
    if (type == 'percent' || type == 'percentage') return '$value% OFF';
    if (type == 'free_feature') return '$value FREE';
    return SubscriptionPlanInfo._money(value);
  }

  String _expiryLabel(Object? raw) {
    final DateTime? date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return 'Loyalty wallet';
    final DateTime local = date.toLocal();
    return 'Expires ${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  Future<SubscriptionCheckoutResult> createStripeCheckout({
    required String planCode,
    String? voucherCode,
    required bool isWeb,
    String? webOrigin,
  }) async {
    final Map<String, dynamic> data = await _resolvedFunctionClient.invokeJson(
      Env.subscriptionPaymentFunction,
      body: <String, dynamic>{
        'action': 'create_checkout',
        'planCode': planCode,
        'voucherCode': voucherCode,
        'platform': isWeb ? 'web' : 'android',
        'webOrigin': isWeb ? webOrigin : null,
      },
    );
    return _checkoutResultFromResponse(data);
  }

  Future<SubscriptionPurchaseResult> confirmStripeCheckout({
    required String sessionId,
  }) async {
    final Map<String, dynamic> data = await _resolvedFunctionClient.invokeJson(
      Env.subscriptionPaymentFunction,
      body: <String, dynamic>{
        'action': 'confirm_checkout',
        'sessionId': sessionId,
      },
    );
    return _purchaseResultFromMap(_asMap(data['purchase']));
  }

  SubscriptionCheckoutResult _checkoutResultFromResponse(Object? raw) {
    final Map<String, dynamic> data = _asMap(raw);
    final String status = data['status']?.toString() ?? '';
    return SubscriptionCheckoutResult(
      status: status,
      checkoutUrl: data['checkoutUrl']?.toString(),
      sessionId: data['sessionId']?.toString(),
      purchaseResult: data['purchase'] == null
          ? null
          : _purchaseResultFromMap(_asMap(data['purchase'])),
    );
  }

  SubscriptionPurchaseResult _purchaseResultFromMap(Map<String, dynamic> row) {
    return SubscriptionPurchaseResult(
      paymentId: row['id_payment'].toString(),
      subscriptionId: row['id_subscription'].toString(),
      originalAmountMinor: (row['original_amount_minor'] as num).toInt(),
      discountMinor: (row['discount_minor'] as num).toInt(),
      finalAmountMinor: (row['final_amount_minor'] as num).toInt(),
      voucherCode: row['voucher_code'] as String?,
      subscriptionEndDate: DateTime.tryParse(
        row['subscription_end_date']?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    }
    throw Exception('Invalid subscription payment response.');
  }
}
