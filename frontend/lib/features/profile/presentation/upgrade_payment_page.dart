import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/profile/data/subscription_repository.dart';

class _PaymentMethod {
  const _PaymentMethod({
    required this.id,
    required this.label,
    required this.icon,
    this.labelColor = AppColors.textPrimary,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color labelColor;
}

class UpgradePaymentPage extends StatefulWidget {
  const UpgradePaymentPage({super.key, required this.planId});

  final String planId;

  @override
  State<UpgradePaymentPage> createState() => _UpgradePaymentPageState();
}

class _UpgradePaymentPageState extends State<UpgradePaymentPage> {
  static const List<_PaymentMethod> _methods = <_PaymentMethod>[
    _PaymentMethod(
      id: 'visa',
      label: 'VISA',
      icon: Icons.credit_card_rounded,
      labelColor: Color(0xFF1A1F71),
    ),
    _PaymentMethod(
      id: 'gpay',
      label: 'G Pay',
      icon: Icons.g_mobiledata_rounded,
    ),
    _PaymentMethod(
      id: 'paypal',
      label: 'PayPal',
      icon: Icons.account_balance_wallet_rounded,
      labelColor: Color(0xFF003087),
    ),
  ];

  final SubscriptionRepository _repository = SubscriptionRepository();
  final TextEditingController _voucherController = TextEditingController();

  late Future<SubscriptionPlanInfo> _planFuture;
  SubscriptionPlanInfo? _plan;
  VoucherPreview? _voucherPreview;
  String? _selectedMethodId;
  bool _isApplyingVoucher = false;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _planFuture = _loadPlan();
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<SubscriptionPlanInfo> _loadPlan() async {
    final SubscriptionPlanInfo plan = await _repository.loadPlan(widget.planId);
    _plan = plan;
    return plan;
  }

  String _formatMoney(int amountMinor) {
    return '\$${(amountMinor / 100).toStringAsFixed(2)}';
  }

  void _showPrivileges() {
    showDialog<void>(
      context: context,
      builder: (_) => const _PrivilegesDialog(),
    );
  }

  Future<void> _applyVoucher(SubscriptionPlanInfo plan) async {
    if (_isApplyingVoucher) return;
    setState(() => _isApplyingVoucher = true);
    try {
      final VoucherPreview preview = await _repository.previewVoucher(
        plan: plan,
        code: _voucherController.text,
      );
      if (!mounted) return;
      setState(() => _voucherPreview = preview);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(preview.message)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _voucherPreview = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isApplyingVoucher = false);
    }
  }

  void _removeVoucher() {
    setState(() {
      _voucherPreview = null;
      _voucherController.clear();
    });
  }

  Future<void> _purchase(SubscriptionPlanInfo plan) async {
    final String? methodId = _selectedMethodId;
    if (methodId == null || _isPurchasing) return;

    setState(() => _isPurchasing = true);
    try {
      final SubscriptionPurchaseResult result = await _repository.purchase(
        planCode: plan.code,
        provider: methodId,
        method: methodId,
        voucherCode: _voucherPreview?.code,
      );
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Payment confirmed'),
          content: Text(
            'Your premium subscription is active.\n'
            'Paid: ${_formatMoney(result.finalAmountMinor)}'
            '${result.discountMinor > 0 ? '\nVoucher discount: ${_formatMoney(result.discountMinor)}' : ''}',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(10, topInset + 8, 10, 10),
            child: SizedBox(
              height: 48,
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 26,
                      color: Color(0xFF1C1C1C),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Upgrade account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF121212),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showPrivileges,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.question_mark_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: AppColors.primaryLight.withValues(alpha: 0.25),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Text(
              'Select your payment method:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<SubscriptionPlanInfo>(
              future: _planFuture,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<SubscriptionPlanInfo> snapshot,
                  ) {
                    final SubscriptionPlanInfo plan =
                        snapshot.data ??
                        _repository.fallbackPlan(widget.planId);
                    final int discount = _voucherPreview?.discountMinor ?? 0;
                    final int finalAmount = plan.priceMinor - discount;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.pagePadding,
                        24,
                        AppConstants.pagePadding,
                        24,
                      ),
                      children: <Widget>[
                        _OrderSummaryCard(
                          plan: plan,
                          discountMinor: discount,
                          finalAmountMinor: finalAmount,
                          formatMoney: _formatMoney,
                        ),
                        const SizedBox(height: 16),
                        _VoucherApplyCard(
                          controller: _voucherController,
                          preview: _voucherPreview,
                          isApplying: _isApplyingVoucher,
                          onApply: () => _applyVoucher(plan),
                          onRemove: _removeVoucher,
                        ),
                        const SizedBox(height: 20),
                        ..._methods.map(
                          (method) => _PaymentCard(
                            method: method,
                            isSelected: method.id == _selectedMethodId,
                            onTap: () =>
                                setState(() => _selectedMethodId = method.id),
                          ),
                        ),
                      ],
                    );
                  },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                8,
                AppConstants.pagePadding,
                16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      _selectedMethodId == null ||
                          _isPurchasing ||
                          _plan == null
                      ? null
                      : () => _purchase(_plan!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    disabledBackgroundColor: const Color(0xFFD9E6EA),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.cardRadius,
                      ),
                    ),
                  ),
                  child: Text(
                    _isPurchasing ? 'Processing...' : 'Pay now',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.plan,
    required this.discountMinor,
    required this.finalAmountMinor,
    required this.formatMoney,
  });

  final SubscriptionPlanInfo plan;
  final int discountMinor;
  final int finalAmountMinor;
  final String Function(int amountMinor) formatMoney;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            plan.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _AmountRow(label: 'Subtotal', value: formatMoney(plan.priceMinor)),
          if (discountMinor > 0)
            _AmountRow(
              label: 'Voucher',
              value: '-${formatMoney(discountMinor)}',
            ),
          const Divider(height: 22),
          _AmountRow(
            label: 'Total',
            value: formatMoney(finalAmountMinor),
            isStrong: true,
          ),
        ],
      ),
    );
  }
}

class _VoucherApplyCard extends StatelessWidget {
  const _VoucherApplyCard({
    required this.controller,
    required this.preview,
    required this.isApplying,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final VoucherPreview? preview;
  final bool isApplying;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bool hasVoucher = preview != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: const Color(0xFFE1E7EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Voucher',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !hasVoucher,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter voucher code',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF4F7F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: isApplying
                    ? null
                    : (hasVoucher ? onRemove : onApply),
                child: Text(
                  hasVoucher ? 'Remove' : (isApplying ? '...' : 'Apply'),
                ),
              ),
            ],
          ),
          if (hasVoucher) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              preview!.message,
              style: const TextStyle(
                color: Color(0xFF16865D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  final _PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.defaultAnimation,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFDDDDDD),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(method.icon, size: 24, color: method.labelColor),
            const SizedBox(width: 10),
            Text(
              method.label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: method.labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.isStrong = false,
  });

  final String label;
  final String value;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final FontWeight weight = isStrong ? FontWeight.w800 : FontWeight.w500;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: weight,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: weight,
              fontSize: isStrong ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivilegesDialog extends StatelessWidget {
  const _PrivilegesDialog();

  static const List<String> _privileges = <String>[
    'Access to AI Object Identification',
    'Practice Essential Vietnamese Phrases',
    'Generate Personalized Itinerary',
    'Many more exclusive voucher & coupon',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.close_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Premium Account Privileges',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.accentGold,
              ),
            ),
            const SizedBox(height: 16),
            ..._privileges.map(
              (String privilege) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                ),
                child: Text(
                  privilege,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
