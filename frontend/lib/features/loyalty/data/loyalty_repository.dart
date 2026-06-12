import 'package:supabase_flutter/supabase_flutter.dart';

import 'loyalty_models.dart';

class LoyaltyRepository {
  LoyaltyRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to use loyalty rewards.');
    }
    return user.id;
  }

  Future<LoyaltyDashboardData> loadDashboard() async {
    final LoyaltyAccount account = await ensureMyLoyaltyAccount();
    final List<dynamic> results = await Future.wait(<Future<dynamic>>[
      getTiers(),
      getRules(),
      getMyTransactions(),
      getAvailableVouchers(),
      getMyVouchers(),
    ]);

    return LoyaltyDashboardData(
      account: account,
      tiers: results[0] as List<LoyaltyTier>,
      rules: results[1] as List<LoyaltyRule>,
      transactions: results[2] as List<LoyaltyTransaction>,
      availableVouchers: results[3] as List<LoyaltyVoucher>,
      wallet: results[4] as List<LoyaltyWalletVoucher>,
    );
  }

  Future<LoyaltyAccount> ensureMyLoyaltyAccount() async {
    final Map<String, dynamic> row = _asMap(
      await _client.rpc(
        'ensure_loyalty_account',
        params: <String, dynamic>{'p_user': _userId},
      ),
    );
    return LoyaltyAccount.fromMap(row);
  }

  Future<LoyaltyAccount> getMyLoyaltyAccount() async {
    final Map<String, dynamic>? row = await _client
        .from('user_loyalty_account')
        .select()
        .eq('id_user', _userId)
        .maybeSingle();

    if (row == null) return ensureMyLoyaltyAccount();
    return LoyaltyAccount.fromMap(row);
  }

  Future<List<LoyaltyTier>> getTiers() async {
    final List<dynamic> rows = await _client
        .from('loyalty_tier_config')
        .select()
        .eq('is_active', true)
        .order('priority');
    return rows.map((Object? row) => LoyaltyTier.fromMap(_asMap(row))).toList();
  }

  Future<List<LoyaltyRule>> getRules() async {
    final List<dynamic> rows = await _client
        .from('loyalty_rule_config')
        .select()
        .eq('is_active', true)
        .order('created_at');
    return rows.map((Object? row) => LoyaltyRule.fromMap(_asMap(row))).toList();
  }

  Future<List<LoyaltyTransaction>> getMyTransactions({int limit = 20}) async {
    final List<dynamic> rows = await _client
        .from('loyalty_transaction')
        .select()
        .eq('id_user', _userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map((Object? row) => LoyaltyTransaction.fromMap(_asMap(row)))
        .toList();
  }

  Future<List<LoyaltyWalletVoucher>> getMyVouchers() async {
    final List<dynamic> rows = await _client
        .from('voucher_wallet')
        .select(
          'id_wallet, wallet_code, status, redeemed_at, expires_at, voucher_config:id_voucher(id_voucher, voucher_code, title, description, points_required, discount_type, discount_value, target_type, valid_days)',
        )
        .eq('id_user', _userId)
        .order('redeemed_at', ascending: false);
    return rows
        .map((Object? row) => LoyaltyWalletVoucher.fromMap(_asMap(row)))
        .toList();
  }

  Future<List<LoyaltyVoucher>> getAvailableVouchers() async {
    final List<dynamic> rows = await _client
        .from('voucher_config')
        .select(
          'id_voucher, voucher_code, title, description, points_required, discount_type, discount_value, target_type, valid_days',
        )
        .eq('is_active', true)
        .order('points_required');
    return rows
        .map((Object? row) => LoyaltyVoucher.fromMap(_asMap(row)))
        .toList();
  }

  Future<LoyaltyTransaction> redeemPointsToTokens(int tokenAmount) async {
    final Map<String, dynamic> row = _asMap(
      await _client.rpc(
        'redeem_points_to_tokens',
        params: <String, dynamic>{
          'p_user': _userId,
          'p_token_amount': tokenAmount,
        },
      ),
    );
    return LoyaltyTransaction.fromMap(row);
  }

  Future<LoyaltyWalletVoucher> redeemVoucher(String voucherId) async {
    final Map<String, dynamic> row = _asMap(
      await _client.rpc(
        'redeem_voucher',
        params: <String, dynamic>{'p_user': _userId, 'p_voucher_id': voucherId},
      ),
    );
    return LoyaltyWalletVoucher.fromMap(row);
  }

  Future<LoyaltyTransaction> earnPoints({
    required String actionType,
    String? referenceTable,
    String? referenceId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final Map<String, dynamic> row = _asMap(
      await _client.rpc(
        'earn_loyalty_points',
        params: <String, dynamic>{
          'p_user': _userId,
          'p_action_type': actionType,
          'p_reference_table': referenceTable,
          'p_reference_id': referenceId,
          'p_description': description,
          'p_metadata': metadata ?? <String, dynamic>{},
        },
      ),
    );
    return LoyaltyTransaction.fromMap(row);
  }

  Future<void> useTokens({
    required String featureType,
    String? referenceId,
  }) async {
    await _client.rpc(
      'use_tokens',
      params: <String, dynamic>{
        'p_user': _userId,
        'p_feature_type': featureType,
        'p_reference_id': referenceId,
      },
    );
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    }
    throw Exception('Invalid loyalty response.');
  }
}
