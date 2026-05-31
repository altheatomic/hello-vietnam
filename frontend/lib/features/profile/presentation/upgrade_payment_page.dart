import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/profile/data/subscription_repository.dart';

class _PaymentMethod {
  const _PaymentMethod({
    required this.id,
    required this.label,
    required this.icon,
    this.iconColor = AppColors.textPrimary,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color iconColor;
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
      iconColor: Color(0xFFFFD166),
    ),
    _PaymentMethod(
      id: 'gpay',
      label: 'G Pay',
      icon: Icons.phone_iphone_rounded,
      iconColor: Color(0xFF111827),
    ),
  ];

  final SubscriptionRepository _repository = SubscriptionRepository();
  final TextEditingController _voucherController = TextEditingController();

  late Future<SubscriptionPlanInfo> _planFuture;
  SubscriptionPlanInfo? _plan;
  VoucherPreview? _voucherPreview;
  String? _selectedMethodId = 'visa';
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
          title: Text(context.l10n.ui('Payment confirmed')),
          content: Text(
            '${context.l10n.ui('Your premium subscription is active.')}\n'
            '${context.l10n.ui('Paid')}: ${_formatMoney(result.finalAmountMinor)}'
            '${result.discountMinor > 0 ? '\n${context.l10n.ui('Voucher discount')}: ${_formatMoney(result.discountMinor)}' : ''}',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.ui('OK')),
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
      backgroundColor: const Color(0xFFEFFBFC),
      body: Column(
        children: <Widget>[
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFF3FBFF), Color(0xFFE6FCF8)],
              ),
            ),
            padding: EdgeInsets.fromLTRB(20, topInset + 28, 20, 24),
            child: SizedBox(
              height: 56,
              child: Row(
                children: <Widget>[
                  _HeaderCircleButton(
                    onPressed: () => context.pop(),
                    icon: Icons.arrow_back_rounded,
                  ),
                  Expanded(
                    child: Text(
                      context.l10n.ui('Upgrade account'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  _HeaderCircleButton(
                    onPressed: _showPrivileges,
                    icon: Icons.help_outline_rounded,
                  ),
                ],
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
                      padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
                      children: <Widget>[
                        const Text(
                          'Select your payment method:',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _OrderSummaryCard(
                          plan: plan,
                          discountMinor: discount,
                          finalAmountMinor: finalAmount,
                          formatMoney: _formatMoney,
                        ),
                        const SizedBox(height: 32),
                        _VoucherApplyCard(
                          controller: _voucherController,
                          preview: _voucherPreview,
                          isApplying: _isApplyingVoucher,
                          onApply: () => _applyVoucher(plan),
                          onRemove: _removeVoucher,
                        ),
                        const SizedBox(height: 30),
                        ..._methods.map(
                          (method) => _PaymentCard(
                            method: method,
                            isSelected: method.id == _selectedMethodId,
                            onTap: () =>
                                setState(() => _selectedMethodId = method.id),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _AddPaymentMethodCard(),
                      ],
                    );
                  },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed:
                      _selectedMethodId == null ||
                          _isPurchasing ||
                          _plan == null
                      ? null
                      : () => _purchase(_plan!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF11BED4),
                    disabledBackgroundColor: const Color(0xFFD9E6EA),
                    elevation: 8,
                    shadowColor: const Color(0x6611BED4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    _isPurchasing
                        ? 'Processing...'
                        : context.l10n.ui('Continue'),
                    style: const TextStyle(
                      fontSize: 19,
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

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({required this.onPressed, required this.icon});

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 14,
      shadowColor: const Color(0x2F64748B),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, size: 32, color: const Color(0xFF334155)),
        ),
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
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFF00C7DF), Color(0xFF4AA8FF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 34,
                  color: Color(0xFFFFD84D),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Premium subscription',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatMoney(plan.priceMinor),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const Divider(height: 48, thickness: 1.4, color: Color(0xFFE5E7EB)),
          if (discountMinor > 0)
            _AmountRow(
              label: 'Voucher',
              value: '-${formatMoney(discountMinor)}',
            ),
          _AmountRow(
            label: context.l10n.ui('Total'),
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
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.local_offer_outlined,
                size: 26,
                color: Color(0xFF25BDF0),
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.ui('Voucher'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !hasVoucher,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: context.l10n.ui('Enter voucher code'),
                    hintStyle: const TextStyle(
                      color: Color(0xFF98A2B3),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                        color: Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                        color: Color(0xFF16C5DD),
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 104,
                height: 62,
                child: ElevatedButton(
                  onPressed: isApplying
                      ? null
                      : (hasVoucher ? onRemove : onApply),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF88DDF0),
                    disabledBackgroundColor: const Color(0xFFCFE7EE),
                    elevation: 10,
                    shadowColor: const Color(0x3388DDF0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Text(
                    hasVoucher ? 'Remove' : (isApplying ? '...' : 'Apply'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
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
        margin: const EdgeInsets.only(bottom: 24),
        height: 104,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD9F2FF).withValues(alpha: 0.82)
              : Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected ? const Color(0xFF10C4DA) : Colors.transparent,
            width: isSelected ? 3.0 : 0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF64748B).withValues(alpha: 0.13),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: method.id == 'gpay' ? const Color(0xFFF3F4F6) : null,
                gradient: method.id == 'visa'
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF00C7DF), Color(0xFF4AA8FF)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(method.icon, size: 38, color: method.iconColor),
            ),
            const SizedBox(width: 24),
            Text(
              method.label,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const Spacer(),
            _PaymentSelectionIndicator(isSelected: isSelected),
          ],
        ),
      ),
    );
  }
}

class _PaymentSelectionIndicator extends StatelessWidget {
  const _PaymentSelectionIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      return Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Color(0xFF10C4DA),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
      );
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFA8B0BE), width: 4),
        color: const Color(0xFFE5E7EB),
      ),
    );
  }
}

class _AddPaymentMethodCard extends StatelessWidget {
  const _AddPaymentMethodCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.13),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Text(
              'Add another payment method',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
          SizedBox(width: 18),
          Icon(Icons.chevron_right_rounded, size: 32, color: Color(0xFF334155)),
        ],
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
              color: isStrong
                  ? const Color(0xFF1F2937)
                  : const Color(0xFF667085),
              fontWeight: weight,
              fontSize: isStrong ? 24 : 16,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: isStrong
                  ? const Color(0xFF35B7F0)
                  : const Color(0xFF1F2937),
              fontWeight: weight,
              fontSize: isStrong ? 28 : 17,
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
