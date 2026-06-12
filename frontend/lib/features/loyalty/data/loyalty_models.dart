class LoyaltyAccount {
  const LoyaltyAccount({
    required this.userId,
    required this.availablePoints,
    required this.lifetimePoints,
    required this.tierPoints,
    required this.tokenBalance,
    required this.currentTier,
    required this.highestTier,
    required this.tierCycleStartedAt,
    required this.tierCycleEndsAt,
  });

  final String userId;
  final int availablePoints;
  final int lifetimePoints;
  final int tierPoints;
  final int tokenBalance;
  final String currentTier;
  final String highestTier;
  final DateTime? tierCycleStartedAt;
  final DateTime? tierCycleEndsAt;

  factory LoyaltyAccount.fromMap(Map<String, dynamic> row) {
    return LoyaltyAccount(
      userId: row['id_user']?.toString() ?? '',
      availablePoints: (row['available_points'] as num?)?.toInt() ?? 0,
      lifetimePoints: (row['lifetime_points'] as num?)?.toInt() ?? 0,
      tierPoints: (row['tier_points'] as num?)?.toInt() ?? 0,
      tokenBalance: (row['token_balance'] as num?)?.toInt() ?? 0,
      currentTier: row['current_tier']?.toString() ?? 'member',
      highestTier: row['highest_tier']?.toString() ?? 'member',
      tierCycleStartedAt: DateTime.tryParse(
        row['tier_cycle_started_at']?.toString() ?? '',
      ),
      tierCycleEndsAt: DateTime.tryParse(
        row['tier_cycle_ends_at']?.toString() ?? '',
      ),
    );
  }
}

class LoyaltyTier {
  const LoyaltyTier({
    required this.code,
    required this.name,
    required this.minTierPoints,
    required this.priority,
    required this.tokenBonusOnUpgrade,
    this.colorHex,
  });

  final String code;
  final String name;
  final int minTierPoints;
  final int priority;
  final int tokenBonusOnUpgrade;
  final String? colorHex;

  factory LoyaltyTier.fromMap(Map<String, dynamic> row) {
    return LoyaltyTier(
      code: row['tier_code']?.toString() ?? '',
      name: row['tier_name']?.toString() ?? '',
      minTierPoints: (row['min_tier_points'] as num?)?.toInt() ?? 0,
      priority: (row['priority'] as num?)?.toInt() ?? 0,
      tokenBonusOnUpgrade:
          (row['token_bonus_on_upgrade'] as num?)?.toInt() ?? 0,
      colorHex: row['color_hex']?.toString(),
    );
  }
}

class LoyaltyRule {
  const LoyaltyRule({
    required this.code,
    required this.name,
    required this.actionType,
    required this.pointAmount,
    required this.tierPointAmount,
    required this.tokenCost,
    required this.requiresApproval,
  });

  final String code;
  final String name;
  final String actionType;
  final int pointAmount;
  final int tierPointAmount;
  final int tokenCost;
  final bool requiresApproval;

  factory LoyaltyRule.fromMap(Map<String, dynamic> row) {
    return LoyaltyRule(
      code: row['rule_code']?.toString() ?? '',
      name: row['rule_name']?.toString() ?? '',
      actionType: row['action_type']?.toString() ?? '',
      pointAmount: (row['point_amount'] as num?)?.toInt() ?? 0,
      tierPointAmount: (row['tier_point_amount'] as num?)?.toInt() ?? 0,
      tokenCost: (row['token_cost'] as num?)?.toInt() ?? 0,
      requiresApproval: row['requires_approval'] == true,
    );
  }
}

class LoyaltyTransaction {
  const LoyaltyTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.pointChange,
    required this.tierPointChange,
    required this.tokenChange,
    required this.createdAt,
    this.sourceType,
    this.description,
  });

  final String id;
  final String type;
  final String status;
  final int pointChange;
  final int tierPointChange;
  final int tokenChange;
  final DateTime? createdAt;
  final String? sourceType;
  final String? description;

  factory LoyaltyTransaction.fromMap(Map<String, dynamic> row) {
    return LoyaltyTransaction(
      id: row['id_transaction']?.toString() ?? '',
      type: row['transaction_type']?.toString() ?? '',
      status: row['status']?.toString() ?? '',
      pointChange: (row['point_change'] as num?)?.toInt() ?? 0,
      tierPointChange: (row['tier_point_change'] as num?)?.toInt() ?? 0,
      tokenChange: (row['token_change'] as num?)?.toInt() ?? 0,
      sourceType: row['source_type']?.toString(),
      description: row['description']?.toString(),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    );
  }
}

class LoyaltyVoucher {
  const LoyaltyVoucher({
    required this.id,
    required this.code,
    required this.title,
    required this.pointsRequired,
    required this.discountType,
    required this.discountValue,
    required this.validDays,
    this.description,
    this.targetType,
  });

  final String id;
  final String code;
  final String title;
  final int pointsRequired;
  final String discountType;
  final int discountValue;
  final int validDays;
  final String? description;
  final String? targetType;

  factory LoyaltyVoucher.fromMap(Map<String, dynamic> row) {
    return LoyaltyVoucher(
      id: row['id_voucher']?.toString() ?? '',
      code: row['voucher_code']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      description: row['description']?.toString(),
      pointsRequired: (row['points_required'] as num?)?.toInt() ?? 0,
      discountType: row['discount_type']?.toString() ?? '',
      discountValue: (row['discount_value'] as num?)?.toInt() ?? 0,
      targetType: row['target_type']?.toString(),
      validDays: (row['valid_days'] as num?)?.toInt() ?? 0,
    );
  }
}

class LoyaltyWalletVoucher {
  const LoyaltyWalletVoucher({
    required this.id,
    required this.walletCode,
    required this.status,
    required this.redeemedAt,
    required this.expiresAt,
    required this.voucher,
  });

  final String id;
  final String walletCode;
  final String status;
  final DateTime? redeemedAt;
  final DateTime? expiresAt;
  final LoyaltyVoucher? voucher;

  factory LoyaltyWalletVoucher.fromMap(Map<String, dynamic> row) {
    final Object? rawVoucher = row['voucher_config'];
    return LoyaltyWalletVoucher(
      id: row['id_wallet']?.toString() ?? '',
      walletCode: row['wallet_code']?.toString() ?? '',
      status: row['status']?.toString() ?? '',
      redeemedAt: DateTime.tryParse(row['redeemed_at']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(row['expires_at']?.toString() ?? ''),
      voucher: rawVoucher is Map
          ? LoyaltyVoucher.fromMap(Map<String, dynamic>.from(rawVoucher))
          : null,
    );
  }
}

class LoyaltyDashboardData {
  const LoyaltyDashboardData({
    required this.account,
    required this.tiers,
    required this.rules,
    required this.transactions,
    required this.availableVouchers,
    required this.wallet,
  });

  final LoyaltyAccount account;
  final List<LoyaltyTier> tiers;
  final List<LoyaltyRule> rules;
  final List<LoyaltyTransaction> transactions;
  final List<LoyaltyVoucher> availableVouchers;
  final List<LoyaltyWalletVoucher> wallet;

  LoyaltyTier? get currentTier {
    for (final LoyaltyTier tier in tiers) {
      if (tier.code == account.currentTier) return tier;
    }
    return tiers.isEmpty ? null : tiers.first;
  }

  LoyaltyTier? get nextTier {
    final LoyaltyTier? current = currentTier;
    if (current == null) return null;
    for (final LoyaltyTier tier in tiers) {
      if (tier.priority == current.priority + 1) return tier;
    }
    return null;
  }
}
