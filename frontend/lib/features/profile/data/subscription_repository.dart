import 'package:supabase_flutter/supabase_flutter.dart';

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

class SubscriptionRepository {
  SubscriptionRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
      final Map<String, dynamic>? row = await _client
          .from('subscription_plan')
          .select(
            'id_subscription_plan, code, name, duration_days, price_minor',
          )
          .eq('code', code)
          .maybeSingle();
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

  Future<VoucherPreview> previewVoucher({
    required SubscriptionPlanInfo plan,
    required String code,
  }) async {
    final String normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw Exception('Enter a voucher code first.');
    }

    final Map<String, dynamic>? row = await _client
        .from('voucher')
        .select(
          'code, type, value, max_discount_value, min_order_amount_min, id_applicable_plan',
        )
        .ilike('code', normalized)
        .eq('status', 'active')
        .maybeSingle();

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

  Future<SubscriptionPurchaseResult> purchase({
    required String planCode,
    required String provider,
    required String method,
    String? voucherCode,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in before purchasing a subscription.');
    }

    final List<dynamic> rows = await _client.rpc(
      'purchase_subscription_with_voucher',
      params: <String, dynamic>{
        'p_plan_code': planCode,
        'p_provider': provider,
        'p_method': method,
        'p_voucher_code': voucherCode,
      },
    );

    final Map<String, dynamic> row = Map<String, dynamic>.from(
      rows.first as Map,
    );
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
}
