import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/app_loading_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/loyalty_award_service.dart';
import '../data/loyalty_models.dart';
import '../data/loyalty_repository.dart';

class LoyaltyPage extends StatefulWidget {
  const LoyaltyPage({super.key});

  @override
  State<LoyaltyPage> createState() => _LoyaltyPageState();
}

class _LoyaltyPageState extends State<LoyaltyPage> {
  static const String _loyaltyNotificationsKey =
      'loyalty_rewards_notifications_enabled';

  final LoyaltyRepository _repository = LoyaltyRepository();
  late Future<LoyaltyDashboardData> _future;
  bool _busy = false;
  bool _loyaltyNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _future = _repository.loadDashboard();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _loyaltyNotificationsEnabled =
          prefs.getBool(_loyaltyNotificationsKey) ?? true;
    });
  }

  Future<void> _setNotificationPreference(bool value) async {
    setState(() => _loyaltyNotificationsEnabled = value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loyaltyNotificationsKey, value);
  }

  void _refresh() {
    setState(() {
      _future = _repository.loadDashboard();
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.ui('Loyalty updated successfully.')),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openEarnDestination(LoyaltyRule rule) {
    final String? route = _routeForAction(rule.actionType);
    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.ui('Daily login is awarded automatically.'),
          ),
        ),
      );
      return;
    }

    context.push(route);
  }

  String? _routeForAction(String actionType) {
    switch (actionType) {
      case 'daily_login':
        return null;
      case 'wishlist_add':
        return AppRoutes.wishlist;
      case 'forum_post':
        return AppRoutes.forumCreate;
      case 'review_submit':
        return AppRoutes.recommendWhereSearch;
      case 'check_in':
        return AppRoutes.explore;
      case 'subscription_purchase':
        return AppRoutes.upgradeAccount;
      default:
        return AppRoutes.home;
    }
  }

  Future<void> _earnTestPoints() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final LoyaltyTransaction? transaction = await LoyaltyAwardService.instance
          .award(
            actionType: 'test_bonus',
            description: 'Test loyalty bonus (+500)',
            metadata: <String, dynamic>{'temporary': true},
          );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            transaction == null
                ? 'Unable to add test loyalty points.'
                : 'Added ${transaction.pointChange} test loyalty points.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAFBFF),
      body: SafeArea(
        child: FutureBuilder<LoyaltyDashboardData>(
          future: _future,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<LoyaltyDashboardData> snapshot,
              ) {
                return Column(
                  children: <Widget>[
                    _Header(onBack: () => context.pop(), onRefresh: _refresh),
                    Expanded(
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const AppLoadingScreen(
                              message: 'Loading loyalty rewards',
                              compact: true,
                            )
                          : snapshot.hasError
                          ? _ErrorState(
                              error: snapshot.error.toString(),
                              onRetry: _refresh,
                            )
                          : _Content(
                              data: snapshot.requireData,
                              busy: _busy,
                              loyaltyNotificationsEnabled:
                                  _loyaltyNotificationsEnabled,
                              onToggleLoyaltyNotifications:
                                  _setNotificationPreference,
                              onRefresh: () async => _refresh(),
                              onEarn: _openEarnDestination,
                              onEarnTestPoints: _earnTestPoints,
                              onRedeemTokens: (int amount) => _runAction(
                                () => _repository
                                    .redeemPointsToTokens(amount)
                                    .then((_) {}),
                              ),
                              onRedeemVoucher: (String voucherId) => _runAction(
                                () => _repository
                                    .redeemVoucher(voucherId)
                                    .then((_) {}),
                              ),
                            ),
                    ),
                  ],
                );
              },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onRefresh});

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFFEAFBFF), Color(0xFFD9FFF8)],
        ),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Expanded(
            child: Text(
              'Loyalty Rewards',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.data,
    required this.busy,
    required this.loyaltyNotificationsEnabled,
    required this.onToggleLoyaltyNotifications,
    required this.onRefresh,
    required this.onEarn,
    required this.onEarnTestPoints,
    required this.onRedeemTokens,
    required this.onRedeemVoucher,
  });

  final LoyaltyDashboardData data;
  final bool busy;
  final bool loyaltyNotificationsEnabled;
  final ValueChanged<bool> onToggleLoyaltyNotifications;
  final Future<void> Function() onRefresh;
  final ValueChanged<LoyaltyRule> onEarn;
  final VoidCallback onEarnTestPoints;
  final ValueChanged<int> onRedeemTokens;
  final ValueChanged<String> onRedeemVoucher;

  @override
  Widget build(BuildContext context) {
    final LoyaltyAccount account = data.account;
    final LoyaltyTier? currentTier = data.currentTier;
    final LoyaltyTier? nextTier = data.nextTier;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: <Widget>[
          _SummaryCard(account: account, currentTier: currentTier),
          const SizedBox(height: 14),
          _LoyaltyNotificationSettingsCard(
            enabled: loyaltyNotificationsEnabled,
            onChanged: onToggleLoyaltyNotifications,
          ),
          const SizedBox(height: 14),
          _TierProgressCard(
            account: account,
            currentTier: currentTier,
            nextTier: nextTier,
          ),
          const SizedBox(height: 14),
          _EarnPointsCard(rules: data.rules, busy: busy, onEarn: onEarn),
          const SizedBox(height: 14),
          _TestLoyaltyCard(busy: busy, onAdd: onEarnTestPoints),
          const SizedBox(height: 14),
          _ExchangeCard(
            account: account,
            busy: busy,
            onRedeemTokens: onRedeemTokens,
          ),
          const SizedBox(height: 14),
          _VoucherExchangeCard(
            vouchers: data.availableVouchers,
            account: account,
            busy: busy,
            onRedeemVoucher: onRedeemVoucher,
          ),
          const SizedBox(height: 14),
          _WalletCard(wallet: data.wallet),
          const SizedBox(height: 14),
          _TransactionsCard(transactions: data.transactions),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.account, required this.currentTier});

  final LoyaltyAccount account;
  final LoyaltyTier? currentTier;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _CircleIcon(
                Icons.workspace_premium_rounded,
                const Color(0xFF12B8D7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      currentTier?.name ?? account.currentTier,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Highest tier: ${account.highestTier}',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              _Metric(
                label: 'Available points',
                value: account.availablePoints.toString(),
              ),
              _Metric(label: 'Tokens', value: account.tokenBalance.toString()),
              _Metric(
                label: 'Lifetime points',
                value: account.lifetimePoints.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoyaltyNotificationSettingsCard extends StatelessWidget {
  const _LoyaltyNotificationSettingsCard({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: <Widget>[
          _CircleIcon(
            enabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            const Color(0xFF2EB8EC),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Loyalty notifications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  'Only affects points and rewards notifications.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: const Color(0xFF19C4D2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TierProgressCard extends StatelessWidget {
  const _TierProgressCard({
    required this.account,
    required this.currentTier,
    required this.nextTier,
  });

  final LoyaltyAccount account;
  final LoyaltyTier? currentTier;
  final LoyaltyTier? nextTier;

  @override
  Widget build(BuildContext context) {
    final int currentMin = currentTier?.minTierPoints ?? 0;
    final int nextMin = nextTier?.minTierPoints ?? account.tierPoints;
    final int span = (nextMin - currentMin).clamp(1, 999999);
    final int earned = (account.tierPoints - currentMin).clamp(0, span);
    final double progress = nextTier == null ? 1 : earned / span;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Tier progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 10,
            borderRadius: BorderRadius.circular(99),
            value: progress,
            backgroundColor: const Color(0xFFE2E8F0),
            color: const Color(0xFF19C4D2),
          ),
          const SizedBox(height: 8),
          Text(
            nextTier == null
                ? 'You are at the highest tier.'
                : '${account.tierPoints}/$nextMin tier points to ${nextTier!.name}',
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (account.tierCycleEndsAt != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Cycle ends: ${_formatDate(account.tierCycleEndsAt!)}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ],
      ),
    );
  }
}

class _EarnPointsCard extends StatelessWidget {
  const _EarnPointsCard({
    required this.rules,
    required this.busy,
    required this.onEarn,
  });

  final List<LoyaltyRule> rules;
  final bool busy;
  final ValueChanged<LoyaltyRule> onEarn;

  @override
  Widget build(BuildContext context) {
    final List<LoyaltyRule> earnRules = rules
        .where(
          (LoyaltyRule rule) =>
              rule.actionType != 'test_bonus' &&
              (rule.pointAmount > 0 || rule.tierPointAmount > 0),
        )
        .take(6)
        .toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Earn points',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...earnRules.map((LoyaltyRule rule) {
            final bool isDailyLogin = rule.actionType == 'daily_login';
            return _ActionRow(
              icon: isDailyLogin
                  ? Icons.login_rounded
                  : Icons.arrow_forward_rounded,
              title: rule.name,
              subtitle:
                  '+${rule.pointAmount} points, +${rule.tierPointAmount} tier points'
                  '${rule.requiresApproval ? ' . Needs review' : ''}'
                  '${isDailyLogin ? ' . Automatic' : ''}',
              buttonLabel: isDailyLogin ? 'Auto' : 'Go',
              enabled: !busy && !isDailyLogin,
              onTap: () => onEarn(rule),
            );
          }),
        ],
      ),
    );
  }
}

class _TestLoyaltyCard extends StatelessWidget {
  const _TestLoyaltyCard({required this.busy, required this.onAdd});

  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Add loyalty for testing',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.bug_report_outlined,
            title: 'Add 500 test points',
            subtitle: '+500 points, +500 tier points. Temporary test action.',
            buttonLabel: 'Add',
            enabled: !busy,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ExchangeCard extends StatelessWidget {
  const _ExchangeCard({
    required this.account,
    required this.busy,
    required this.onRedeemTokens,
  });

  final LoyaltyAccount account;
  final bool busy;
  final ValueChanged<int> onRedeemTokens;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Exchange points to tokens',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _ActionRow(
            icon: Icons.token_rounded,
            title: 'Get 1 token',
            subtitle: 'Cost: 10 points. Daily limit: 50 tokens.',
            buttonLabel: 'Redeem',
            enabled: !busy && account.availablePoints >= 10,
            onTap: () => onRedeemTokens(1),
          ),
          _ActionRow(
            icon: Icons.toll_rounded,
            title: 'Get 5 tokens',
            subtitle: 'Cost: 50 points.',
            buttonLabel: 'Redeem',
            enabled: !busy && account.availablePoints >= 50,
            onTap: () => onRedeemTokens(5),
          ),
        ],
      ),
    );
  }
}

class _VoucherExchangeCard extends StatelessWidget {
  const _VoucherExchangeCard({
    required this.vouchers,
    required this.account,
    required this.busy,
    required this.onRedeemVoucher,
  });

  final List<LoyaltyVoucher> vouchers;
  final LoyaltyAccount account;
  final bool busy;
  final ValueChanged<String> onRedeemVoucher;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Redeem vouchers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (vouchers.isEmpty)
            const Text(
              'No active loyalty vouchers yet.',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else
            ...vouchers.map(
              (LoyaltyVoucher voucher) => _ActionRow(
                icon: Icons.confirmation_number_outlined,
                title: voucher.title,
                subtitle:
                    '${voucher.pointsRequired} points . ${voucher.description ?? voucher.code}',
                buttonLabel: 'Redeem',
                enabled:
                    !busy && account.availablePoints >= voucher.pointsRequired,
                onTap: () => onRedeemVoucher(voucher.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet});

  final List<LoyaltyWalletVoucher> wallet;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Voucher wallet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (wallet.isEmpty)
            const Text(
              'Your loyalty voucher wallet is empty.',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else
            ...wallet
                .take(6)
                .map(
                  (LoyaltyWalletVoucher item) => _InfoRow(
                    icon: Icons.local_offer_outlined,
                    title: item.voucher?.title ?? item.walletCode,
                    subtitle:
                        '${item.walletCode} . ${item.status}'
                        '${item.expiresAt == null ? '' : ' . Expires ${_formatDate(item.expiresAt!)}'}',
                  ),
                ),
        ],
      ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.transactions});

  final List<LoyaltyTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Transaction history',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            const Text(
              'No loyalty transactions yet.',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else
            ...transactions.map((LoyaltyTransaction tx) {
              final String points = tx.pointChange == 0
                  ? ''
                  : ' ${tx.pointChange > 0 ? '+' : ''}${tx.pointChange} pts';
              final String tokens = tx.tokenChange == 0
                  ? ''
                  : ' ${tx.tokenChange > 0 ? '+' : ''}${tx.tokenChange} token';
              return _InfoRow(
                icon: tx.status == 'pending'
                    ? Icons.pending_outlined
                    : Icons.receipt_long_outlined,
                title: tx.description ?? tx.type,
                subtitle:
                    '${tx.status}$points$tokens'
                    '${tx.createdAt == null ? '' : ' . ${_formatDate(tx.createdAt!)}'}',
              );
            }),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          _CircleIcon(icon, const Color(0xFF2EB8EC)),
          const SizedBox(width: 10),
          Expanded(
            child: _TwoLine(title: title, subtitle: subtitle),
          ),
          TextButton(
            onPressed: enabled ? onTap : null,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          _CircleIcon(icon, const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Expanded(
            child: _TwoLine(title: title, subtitle: subtitle),
          ),
        ],
      ),
    );
  }
}

class _TwoLine extends StatelessWidget {
  const _TwoLine({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            const Text(
              'Load loyalty failed.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final DateTime local = date.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
