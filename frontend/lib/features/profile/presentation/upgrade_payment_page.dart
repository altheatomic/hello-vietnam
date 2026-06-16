import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/app_loading_screen.dart';
import 'package:hellovietnam/features/loyalty/data/loyalty_award_service.dart';
import 'package:hellovietnam/features/profile/data/subscription_repository.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _VoucherOption {
  const _VoucherOption({
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

  factory _VoucherOption.fromRepository(SubscriptionVoucherOption option) {
    return _VoucherOption(
      code: option.code,
      title: option.title,
      description: option.description,
      discountLabel: option.discountLabel,
      expiryLabel: option.expiryLabel,
      type: option.type,
      value: option.value,
      minAmountMinor: option.minAmountMinor,
    );
  }

  int discountFor(SubscriptionPlanInfo plan) {
    if (minAmountMinor != null && plan.priceMinor < minAmountMinor!) return 0;
    if (type == 'percent') {
      return (plan.priceMinor * value / 100).floor();
    }
    return value > plan.priceMinor ? plan.priceMinor : value;
  }

  bool isAvailableFor(SubscriptionPlanInfo plan) {
    final int? minimum = minAmountMinor;
    return minimum == null || plan.priceMinor >= minimum;
  }
}

class _PaymentFlowData {
  const _PaymentFlowData({
    required this.plan,
    required this.method,
    required this.discountMinor,
    required this.finalAmountMinor,
    this.voucherCode,
    this.purchaseResult,
  });

  final SubscriptionPlanInfo plan;
  final _PaymentMethod method;
  final String? voucherCode;
  final int discountMinor;
  final int finalAmountMinor;
  final SubscriptionPurchaseResult? purchaseResult;
}

class UpgradePaymentPage extends StatefulWidget {
  const UpgradePaymentPage({
    super.key,
    required this.planId,
    this.checkoutSessionId,
  });

  final String planId;
  final String? checkoutSessionId;

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
  bool _isConfirmingCheckout = false;

  @override
  void initState() {
    super.initState();
    _planFuture = _loadPlan();
    if (widget.checkoutSessionId?.trim().isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confirmReturnedCheckout(widget.checkoutSessionId!.trim());
      });
    }
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

  Future<void> _confirmReturnedCheckout(String sessionId) async {
    if (_isConfirmingCheckout) return;
    setState(() => _isConfirmingCheckout = true);
    try {
      final SubscriptionPlanInfo plan = await _planFuture;
      final SubscriptionPurchaseResult result = await _repository
          .confirmStripeCheckout(sessionId: sessionId);
      await _awardSubscriptionPurchase(result);
      if (!mounted) return;
      final _PaymentMethod method = _methods.firstWhere(
        (_PaymentMethod item) => item.id == 'visa',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _PaymentSuccessPage(
            data: _PaymentFlowData(
              plan: plan,
              method: method,
              voucherCode: result.voucherCode,
              discountMinor: result.discountMinor,
              finalAmountMinor: result.finalAmountMinor,
              purchaseResult: result,
            ),
            formatMoney: _formatMoney,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
    } finally {
      if (mounted) setState(() => _isConfirmingCheckout = false);
    }
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

  void _removeVoucher() {
    setState(() {
      _voucherPreview = null;
      _voucherController.clear();
    });
  }

  Future<void> _openVoucherSheet(SubscriptionPlanInfo plan) async {
    final List<SubscriptionVoucherOption> loyaltyVouchers = await _repository
        .loadLoyaltySubscriptionVouchers(plan: plan);
    final List<_VoucherOption> vouchers = <_VoucherOption>[
      ...loyaltyVouchers.map(_VoucherOption.fromRepository),
    ];
    if (!mounted) return;

    final VoucherPreview? selected = await showModalBottomSheet<VoucherPreview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (BuildContext sheetContext) => _VoucherSelectionSheet(
        plan: plan,
        initialCode: _voucherController.text,
        selectedCode: _voucherPreview?.code,
        vouchers: vouchers,
        repository: _repository,
        formatMoney: _formatMoney,
      ),
    );

    if (selected == null || !mounted) return;
    setState(() {
      _voucherPreview = selected;
      _voucherController.text = selected.code;
    });
  }

  Future<void> _awardSubscriptionPurchase(
    SubscriptionPurchaseResult result,
  ) async {
    await LoyaltyAwardService.instance.award(
      actionType: 'subscription_purchase',
      referenceTable: 'payment',
      referenceId: result.paymentId,
      description: 'Purchased premium subscription',
      metadata: <String, dynamic>{
        'subscription_id': result.subscriptionId,
        'final_amount_minor': result.finalAmountMinor,
        if (result.voucherCode != null) 'voucher_code': result.voucherCode,
      },
    );
  }

  void _continueToConfirmation(SubscriptionPlanInfo plan) {
    final String? methodId = _selectedMethodId;
    if (methodId == null) return;

    final _PaymentMethod method = _methods.firstWhere(
      (_PaymentMethod item) => item.id == methodId,
      orElse: () => _methods.first,
    );
    final int discount = _voucherPreview?.discountMinor ?? 0;
    final int finalAmount = plan.priceMinor - discount;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PaymentConfirmationPage(
          data: _PaymentFlowData(
            plan: plan,
            method: method,
            voucherCode: _voucherPreview?.code,
            discountMinor: discount,
            finalAmountMinor: finalAmount,
          ),
          repository: _repository,
          formatMoney: _formatMoney,
        ),
      ),
    );
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
            padding: EdgeInsets.fromLTRB(18, topInset + 14, 18, 14),
            child: SizedBox(
              height: 46,
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
                        fontSize: 24,
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
            child: _isConfirmingCheckout
                ? const AppLoadingScreen(
                    message: 'Confirming payment',
                    compact: true,
                  )
                : FutureBuilder<SubscriptionPlanInfo>(
                    future: _planFuture,
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<SubscriptionPlanInfo> snapshot,
                        ) {
                          final SubscriptionPlanInfo plan =
                              snapshot.data ??
                              _repository.fallbackPlan(widget.planId);
                          final int discount =
                              _voucherPreview?.discountMinor ?? 0;
                          final int finalAmount = plan.priceMinor - discount;

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                            children: <Widget>[
                              Text(
                                context.l10n.ui('Select your payment method:'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _OrderSummaryCard(
                                plan: plan,
                                discountMinor: discount,
                                finalAmountMinor: finalAmount,
                                formatMoney: _formatMoney,
                              ),
                              const SizedBox(height: 12),
                              _VoucherApplyCard(
                                preview: _voucherPreview,
                                formatMoney: _formatMoney,
                                onOpen: () => _openVoucherSheet(plan),
                                onRemove: _removeVoucher,
                              ),
                              const SizedBox(height: 12),
                              ..._methods.map(
                                (method) => _PaymentCard(
                                  method: method,
                                  isSelected: method.id == _selectedMethodId,
                                  onTap: () => setState(
                                    () => _selectedMethodId = method.id,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const _AddPaymentMethodCard(),
                            ],
                          );
                        },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _selectedMethodId == null || _plan == null
                      ? null
                      : () => _continueToConfirmation(_plan!),
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
                    context.l10n.ui('Continue'),
                    style: const TextStyle(
                      fontSize: 17,
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
          width: 46,
          height: 46,
          child: Icon(icon, size: 27, color: const Color(0xFF334155)),
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFF00C7DF), Color(0xFF4AA8FF)],
                  ),
                  borderRadius: BorderRadius.circular(14),
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
                  size: 26,
                  color: Color(0xFFFFD84D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.ui('Premium subscription'),
                      style: const TextStyle(
                        fontSize: 12,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const Divider(height: 22, thickness: 1.1, color: Color(0xFFE5E7EB)),
          if (discountMinor > 0)
            _AmountRow(
              label: context.l10n.ui('Voucher'),
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
    required this.preview,
    required this.formatMoney,
    required this.onOpen,
    required this.onRemove,
  });

  final VoucherPreview? preview;
  final String Function(int amountMinor) formatMoney;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bool hasVoucher = preview != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.11),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
                size: 22,
                color: Color(0xFF25BDF0),
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.ui('Voucher'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasVoucher)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      preview!.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF047857),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '-${formatMoney(preview!.discountMinor)}',
                    style: const TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextButton(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.only(left: 8),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      context.l10n.ui('Remove'),
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onOpen,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          context.l10n.ui('Select or enter voucher code'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF667085),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
        margin: const EdgeInsets.only(bottom: 10),
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD9F2FF).withValues(alpha: 0.82)
              : Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF10C4DA) : Colors.transparent,
            width: isSelected ? 3.0 : 0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF64748B).withValues(alpha: 0.13),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: method.id == 'gpay' ? const Color(0xFFF3F4F6) : null,
                gradient: method.id == 'visa'
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF00C7DF), Color(0xFF4AA8FF)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(method.icon, size: 27, color: method.iconColor),
            ),
            const SizedBox(width: 16),
            Text(
              method.label,
              style: const TextStyle(
                fontSize: 18,
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
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFF10C4DA),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 25),
      );
    }

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFA8B0BE), width: 3),
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
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.13),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Text(
              context.l10n.ui('Add another payment method'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: Color(0xFF334155),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: isStrong
                  ? const Color(0xFF1F2937)
                  : const Color(0xFF667085),
              fontWeight: weight,
              fontSize: isStrong ? 18 : 13,
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
              fontSize: isStrong ? 22 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherSelectionSheet extends StatefulWidget {
  const _VoucherSelectionSheet({
    required this.plan,
    required this.initialCode,
    required this.selectedCode,
    required this.vouchers,
    required this.repository,
    required this.formatMoney,
  });

  final SubscriptionPlanInfo plan;
  final String initialCode;
  final String? selectedCode;
  final List<_VoucherOption> vouchers;
  final SubscriptionRepository repository;
  final String Function(int amountMinor) formatMoney;

  @override
  State<_VoucherSelectionSheet> createState() => _VoucherSelectionSheetState();
}

class _VoucherSelectionSheetState extends State<_VoucherSelectionSheet> {
  late final TextEditingController _manualController;
  String? _selectedCode;
  String? _error;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController(text: widget.initialCode);
    _selectedCode = widget.selectedCode;
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  VoucherPreview _previewFromOption(_VoucherOption voucher) {
    final int discount = voucher.discountFor(widget.plan);
    return VoucherPreview(
      code: voucher.code,
      discountMinor: discount,
      finalAmountMinor: widget.plan.priceMinor - discount,
      message:
          '${context.l10n.ui('Voucher applied:')} -${widget.formatMoney(discount)}',
    );
  }

  Future<void> _applyManualCode() async {
    if (_isApplying) return;
    setState(() {
      _isApplying = true;
      _error = null;
    });

    try {
      final VoucherPreview preview = await widget.repository.previewVoucher(
        plan: widget.plan,
        code: _manualController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(preview);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  void _selectVoucher(_VoucherOption voucher) {
    if (!voucher.isAvailableFor(widget.plan)) {
      setState(
        () => _error = context.l10n.ui(
          'Selected plan does not meet voucher minimum spend.',
        ),
      );
      return;
    }
    setState(() {
      _selectedCode = voucher.code;
      _error = null;
    });
  }

  void _finish() {
    final _VoucherOption? selected = widget.vouchers
        .where((_VoucherOption voucher) => voucher.code == _selectedCode)
        .firstOrNull;
    if (selected == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(_previewFromOption(selected));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        context.l10n.ui('Select Voucher'),
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF667085),
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                  children: <Widget>[
                    Text(
                      context.l10n.ui('Available Vouchers'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...widget.vouchers.map(
                      (_VoucherOption voucher) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _VoucherOptionCard(
                          voucher: voucher,
                          isSelected: voucher.code == _selectedCode,
                          isEnabled: voucher.isAvailableFor(widget.plan),
                          minMessage: voucher.minAmountMinor == null
                              ? null
                              : '${context.l10n.ui('Min. purchase:')} ${widget.formatMoney(voucher.minAmountMinor!)}',
                          onTap: () => _selectVoucher(voucher),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.ui('Or enter code manually'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _manualController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: context.l10n.ui('Enter voucher code'),
                              hintStyle: const TextStyle(
                                color: Color(0xFF98A2B3),
                                fontWeight: FontWeight.w600,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                  width: 1.6,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF22D3EE),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _isApplying ? null : _applyManualCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7DDDF0),
                              disabledBackgroundColor: const Color(0xFFCFE7EE),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              _isApplying ? '...' : context.l10n.ui('Apply'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _finish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF11BED4),
                        elevation: 10,
                        shadowColor: const Color(0x4411BED4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        context.l10n.ui('Done'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VoucherOptionCard extends StatelessWidget {
  const _VoucherOptionCard({
    required this.voucher,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
    this.minMessage,
  });

  final _VoucherOption voucher;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;
  final String? minMessage;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: AppConstants.defaultAnimation,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF22D3EE)
                    : const Color(0xFFE5E7EB),
                width: 2,
              ),
              boxShadow: <BoxShadow>[
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFF22D3EE).withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: isEnabled
                                ? const LinearGradient(
                                    colors: <Color>[
                                      Color(0xFFFBBF24),
                                      Color(0xFFFACC15),
                                    ],
                                  )
                                : null,
                            color: isEnabled ? null : const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.percent_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                context.l10n.ui(voucher.title),
                                style: const TextStyle(
                                  color: Color(0xFF1F2937),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Code: ${voucher.code}',
                                style: const TextStyle(
                                  color: Color(0xFF667085),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.ui(voucher.description),
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Text(
                          voucher.discountLabel,
                          style: const TextStyle(
                            color: Color(0xFF00A63E),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          context.l10n.ui(voucher.expiryLabel),
                          style: const TextStyle(
                            color: Color(0xFF98A2B3),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (!isEnabled && minMessage != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        minMessage!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                if (isSelected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22D3EE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentConfirmationPage extends StatefulWidget {
  const _PaymentConfirmationPage({
    required this.data,
    required this.repository,
    required this.formatMoney,
  });

  final _PaymentFlowData data;
  final SubscriptionRepository repository;
  final String Function(int amountMinor) formatMoney;

  @override
  State<_PaymentConfirmationPage> createState() =>
      _PaymentConfirmationPageState();
}

class _PaymentConfirmationPageState extends State<_PaymentConfirmationPage> {
  bool _agreed = false;
  bool _isProcessing = false;

  Future<void> _confirm() async {
    if (!_agreed || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final SubscriptionCheckoutResult
      checkout = await widget.repository.createStripeCheckout(
        planCode: widget.data.plan.code,
        voucherCode: widget.data.voucherCode,
        successUrl: _checkoutReturnUrl(widget.data.plan.code, success: true),
        cancelUrl: _checkoutReturnUrl(widget.data.plan.code, success: false),
      );
      if (!mounted) return;
      if (checkout.requiresCheckout) {
        final String? checkoutUrl = checkout.checkoutUrl;
        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          throw Exception('Checkout URL was not returned.');
        }
        await _openCheckoutUrl(checkoutUrl);
        return;
      }

      final SubscriptionPurchaseResult? result = checkout.purchaseResult;
      if (checkout.isCompleted && result != null) {
        await _awardSubscriptionPurchase(result);
        _showSuccess(result);
        return;
      }

      throw Exception('Payment checkout could not be started.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _checkoutReturnUrl(String planCode, {required bool success}) {
    final String encodedPlan = Uri.encodeComponent(planCode);
    if (!kIsWeb) {
      if (success) {
        return 'intent://upgrade-payment?plan=$encodedPlan&stripe_session_id={CHECKOUT_SESSION_ID}#Intent;scheme=com.example.hellovietnam;package=com.example.hellovietnam;end';
      }
      return 'intent://upgrade-payment?plan=$encodedPlan&stripe_cancelled=1#Intent;scheme=com.example.hellovietnam;package=com.example.hellovietnam;end';
    }

    final String origin = Uri.base.origin;
    if (success) {
      return '$origin/#/upgrade-payment?plan=$encodedPlan&stripe_session_id={CHECKOUT_SESSION_ID}';
    }
    return '$origin/#/upgrade-payment?plan=$encodedPlan&stripe_cancelled=1';
  }

  Future<void> _openCheckoutUrl(String checkoutUrl) async {
    final Uri? uri = Uri.tryParse(checkoutUrl);
    if (uri == null) {
      throw Exception('Checkout URL is invalid.');
    }

    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: kIsWeb ? '_self' : null,
    );
    if (!launched) {
      throw Exception('Could not open checkout page.');
    }
  }

  void _showSuccess(SubscriptionPurchaseResult result) {
    if (!mounted) return;
    final _PaymentFlowData successData = _PaymentFlowData(
      plan: widget.data.plan,
      method: widget.data.method,
      voucherCode: result.voucherCode ?? widget.data.voucherCode,
      discountMinor: result.discountMinor,
      finalAmountMinor: result.finalAmountMinor,
      purchaseResult: result,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => _PaymentSuccessPage(
          data: successData,
          formatMoney: widget.formatMoney,
        ),
      ),
    );
  }

  Future<void> _awardSubscriptionPurchase(
    SubscriptionPurchaseResult result,
  ) async {
    await LoyaltyAwardService.instance.award(
      actionType: 'subscription_purchase',
      referenceTable: 'payment',
      referenceId: result.paymentId,
      description: 'Purchased premium subscription',
      metadata: <String, dynamic>{
        'subscription_id': result.subscriptionId,
        'final_amount_minor': result.finalAmountMinor,
        if (result.voucherCode != null) 'voucher_code': result.voucherCode,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final _PaymentFlowData data = widget.data;
    final int months = (data.plan.durationDays / 30).round();

    return Scaffold(
      backgroundColor: const Color(0xFFEFFBFC),
      body: Column(
        children: <Widget>[
          _SimpleGradientHeader(
            title: context.l10n.ui('Confirm Payment'),
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              children: <Widget>[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF10B981),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          context.l10n.ui('Secure Payment'),
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  context.l10n.ui('Review your purchase:'),
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _ConfirmationSummaryCard(
                  data: data,
                  formatMoney: widget.formatMoney,
                  months: months,
                ),
                const SizedBox(height: 16),
                _ConfirmPaymentMethodCard(
                  method: data.method,
                  onChange: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 16),
                const _ImportantInfoCard(),
                const SizedBox(height: 22),
                _TermsCheckbox(
                  value: _agreed,
                  onChanged: () => setState(() => _agreed = !_agreed),
                ),
                const SizedBox(height: 22),
                const _BenefitsPreviewCard(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _agreed && !_isProcessing ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF11BED4),
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    elevation: _agreed ? 10 : 0,
                    shadowColor: const Color(0x4411BED4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '${context.l10n.ui('Confirm Payment')} ${widget.formatMoney(data.finalAmountMinor)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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

class _SimpleGradientHeader extends StatelessWidget {
  const _SimpleGradientHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 18, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFF3FBFF), Color(0xFFE6FCF8)],
        ),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: <Widget>[
            _SmallCircleButton(onTap: onBack, icon: Icons.arrow_back_rounded),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class _SmallCircleButton extends StatelessWidget {
  const _SmallCircleButton({required this.onTap, required this.icon});

  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: const Color(0x2F64748B),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: const Color(0xFF334155), size: 26),
        ),
      ),
    );
  }
}

class _ConfirmationSummaryCard extends StatelessWidget {
  const _ConfirmationSummaryCard({
    required this.data,
    required this.formatMoney,
    required this.months,
  });

  final _PaymentFlowData data;
  final String Function(int amountMinor) formatMoney;
  final int months;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const _GradientIconBox(
                icon: Icons.workspace_premium_rounded,
                iconColor: Color(0xFFFFD84D),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      data.plan.name,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Color(0xFF667085),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${context.l10n.ui('Valid for')} $months ${context.l10n.ui('months')}',
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                formatMoney(data.plan.priceMinor),
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (data.discountMinor > 0) ...<Widget>[
            const Divider(height: 32, color: Color(0xFFE5E7EB)),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.local_offer_outlined,
                  color: Color(0xFF00A63E),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        data.voucherCode ?? 'Voucher',
                        style: const TextStyle(
                          color: Color(0xFF00A63E),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        context.l10n.ui('Discount applied'),
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '-${formatMoney(data.discountMinor)}',
                  style: const TextStyle(
                    color: Color(0xFF00A63E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 38, color: Color(0xFFE5E7EB)),
          Row(
            children: <Widget>[
              Text(
                context.l10n.ui('Total Amount'),
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                formatMoney(data.finalAmountMinor),
                style: const TextStyle(
                  color: Color(0xFF35B7F0),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmPaymentMethodCard extends StatelessWidget {
  const _ConfirmPaymentMethodCard({
    required this.method,
    required this.onChange,
  });

  final _PaymentMethod method;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        children: <Widget>[
          _PaymentMethodIcon(method: method, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.ui('Payment Method'),
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 13,
                  ),
                ),
                Text(
                  method.label,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: Text(
              context.l10n.ui('Change'),
              style: const TextStyle(
                color: Color(0xFF2EB9F8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodIcon extends StatelessWidget {
  const _PaymentMethodIcon({required this.method, this.size = 72});

  final _PaymentMethod method;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: method.id == 'gpay' ? const Color(0xFFF3F4F6) : null,
        gradient: method.id == 'visa'
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF00C7DF), Color(0xFF4AA8FF)],
              )
            : null,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(method.icon, size: size * 0.53, color: method.iconColor),
    );
  }
}

class _ImportantInfoCard extends StatelessWidget {
  const _ImportantInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFBD38D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFF59E0B),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.ui('Important Information'),
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.ui(
                    'Your subscription will automatically renew. You can cancel anytime from your account settings.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AnimatedContainer(
            duration: AppConstants.defaultAnimation,
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: value ? const Color(0xFF22D3EE) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: value
                    ? const Color(0xFF22D3EE)
                    : const Color(0xFFD1D5DB),
                width: 2,
              ),
            ),
            child: value
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: context.l10n.ui('I agree to the '),
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: context.l10n.ui('Terms & Conditions'),
                    style: const TextStyle(color: Color(0xFF2EB9F8)),
                  ),
                  TextSpan(text: context.l10n.ui(' and ')),
                  TextSpan(
                    text: context.l10n.ui('Privacy Policy'),
                    style: const TextStyle(color: Color(0xFF2EB9F8)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitsPreviewCard extends StatelessWidget {
  const _BenefitsPreviewCard();

  static const List<String> _items = <String>[
    'AI Object Identification',
    'Vietnamese Phrases Practice',
    'Personalized Itinerary',
    'Exclusive Vouchers',
  ];

  static const List<String> _icons = <String>['🤖', '💬', '✨', '🎁'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFEAFEFF), Color(0xFFEFF6FF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.ui("✨ You're getting:"),
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          for (int index = 0; index < _items.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: <Widget>[
                  Text(_icons[index], style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.ui(_items[index]),
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentSuccessPage extends StatelessWidget {
  const _PaymentSuccessPage({required this.data, required this.formatMoney});

  final _PaymentFlowData data;
  final String Function(int amountMinor) formatMoney;

  String _dateLabel(DateTime date) {
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime validUntil =
        data.purchaseResult?.subscriptionEndDate ??
        now.add(Duration(days: data.plan.durationDays));
    final String transactionId =
        data.purchaseResult?.paymentId
            .replaceAll('-', '')
            .substring(0, 10)
            .toUpperCase() ??
        'TXN${now.millisecondsSinceEpoch.toString().substring(4, 13)}';

    return Scaffold(
      backgroundColor: const Color(0xFFEFFBFC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
          children: <Widget>[
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        width: 10,
                      ),
                    ),
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF4ADE80), Color(0xFF10B981)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(
                            0xFF4ADE80,
                          ).withValues(alpha: 0.45),
                          blurRadius: 36,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 66,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              context.l10n.ui('Payment Successful! 🎉'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 31,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.ui('Your premium subscription is now active'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 40),
            _SuccessTransactionCard(
              data: data,
              transactionId: transactionId,
              dateLabel: _dateLabel(now),
              validUntilLabel: _dateLabel(validUntil),
              formatMoney: formatMoney,
            ),
            const SizedBox(height: 28),
            const _BenefitsActivatedCard(),
            const SizedBox(height: 28),
            _SecondaryActionButton(
              icon: Icons.download_rounded,
              label: context.l10n.ui('Download Receipt'),
              onTap: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.ui('Receipt download is coming soon.'),
                      ),
                    ),
                  );
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 64,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(
                  Icons.home_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                label: Text(
                  context.l10n.ui('Go to Home'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF11BED4),
                  elevation: 14,
                  shadowColor: const Color(0x4411BED4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessTransactionCard extends StatelessWidget {
  const _SuccessTransactionCard({
    required this.data,
    required this.transactionId,
    required this.dateLabel,
    required this.validUntilLabel,
    required this.formatMoney,
  });

  final _PaymentFlowData data;
  final String transactionId;
  final String dateLabel;
  final String validUntilLabel;
  final String Function(int amountMinor) formatMoney;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        children: <Widget>[
          Text(
            context.l10n.ui('Transaction ID'),
            style: const TextStyle(color: Color(0xFF667085), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            transactionId,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Divider(height: 38, color: Color(0xFFE5E7EB)),
          _SuccessDetailRow(
            icon: Icons.workspace_premium_rounded,
            iconColor: Color(0xFFFFD84D),
            bgColor: Color(0xFFFFF7CC),
            label: 'Plan',
            value: data.plan.name,
          ),
          _SuccessDetailRow(
            icon: Icons.credit_card_rounded,
            iconColor: Color(0xFF2EB9F8),
            bgColor: Color(0xFFDDF7FF),
            label: 'Amount Paid',
            value: formatMoney(data.finalAmountMinor),
            trailing: data.method.label,
            valueColor: const Color(0xFF35B7F0),
          ),
          if (data.discountMinor > 0)
            _SuccessDetailRow(
              icon: Icons.local_offer_outlined,
              iconColor: Color(0xFF00A63E),
              bgColor: Color(0xFFDCFCE7),
              label: 'Voucher',
              value: data.voucherCode ?? 'Voucher',
              trailing: '-${formatMoney(data.discountMinor)}',
              valueColor: const Color(0xFF00A63E),
              trailingColor: const Color(0xFF00A63E),
            ),
          _SuccessDetailRow(
            icon: Icons.calendar_month_rounded,
            iconColor: Color(0xFFA855F7),
            bgColor: Color(0xFFFCE7F3),
            label: 'Date',
            value: dateLabel,
          ),
          const Divider(height: 32, color: Color(0xFFE5E7EB)),
          Row(
            children: <Widget>[
              Text(
                context.l10n.ui('Valid Until'),
                style: const TextStyle(color: Color(0xFF667085), fontSize: 16),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  validUntilLabel,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuccessDetailRow extends StatelessWidget {
  const _SuccessDetailRow({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.value,
    this.trailing,
    this.valueColor,
    this.trailingColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;
  final String? trailing;
  final Color? valueColor;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.ui(label),
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? const Color(0xFF1F2937),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                color: trailingColor ?? const Color(0xFF667085),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _BenefitsActivatedCard extends StatelessWidget {
  const _BenefitsActivatedCard();

  static const List<String> _icons = <String>['🤖', '💬', '✨', '🎁'];
  static const List<String> _items = <String>[
    'AI Object Identification',
    'Vietnamese Phrases Practice',
    'Personalized Itinerary Generator',
    'Exclusive Vouchers & Coupons',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '✨ ${context.l10n.ui('Premium Benefits Activated')}',
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          for (int index = 0; index < _items.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${_icons[index]}  ${context.l10n.ui(_items[index])}',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(18),
      elevation: 8,
      shadowColor: const Color(0x2264748B),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: const Color(0xFF334155), size: 26),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.13),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GradientIconBox extends StatelessWidget {
  const _GradientIconBox({required this.icon, required this.iconColor});

  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF00C7DF), Color(0xFF4AA8FF)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: iconColor, size: 28),
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
