import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';

// ── Data ─────────────────────────────────────────────────────────────

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

// ── Page ─────────────────────────────────────────────────────────────

/// Pushed from UpgradeAccountPage after a plan is selected.
///
/// Shows VISA / Google Pay / PayPal payment options.
class UpgradePaymentPage extends StatefulWidget {
  const UpgradePaymentPage({super.key, required this.planId});

  /// The plan id selected on the previous screen (passed for potential
  /// order-creation logic; not displayed in this MVP).
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
      labelColor: Color(0xFF1A1F71), // VISA navy
    ),
    _PaymentMethod(
      id: 'gpay',
      label: 'G Pay',
      icon: Icons.g_mobiledata_rounded,
      labelColor: AppColors.textPrimary,
    ),
    _PaymentMethod(
      id: 'paypal',
      label: 'PayPal',
      icon: Icons.account_balance_wallet_rounded,
      labelColor: Color(0xFF003087), // PayPal navy
    ),
  ];

  String? _selectedId;

  void _showPrivileges() {
    // Re-uses the same dialog from the plan page — delegates through Navigator
    // so we don't import the private class. Shown inline here.
    showDialog<void>(
      context: context,
      builder: (_) => const _PrivilegesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          // ── Header — same style as UpgradeAccountPage ─────────
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
                  // Help button
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

          // ── Payment banner ────────────────────────────────────
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

          // ── Payment method cards ──────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                28,
                AppConstants.pagePadding,
                0,
              ),
              child: Column(
                children: _methods
                    .map(
                      (method) => _PaymentCard(
                        method: method,
                        isSelected: method.id == _selectedId,
                        onTap: () => setState(() => _selectedId = method.id),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment method card ───────────────────────────────────────────────

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
          boxShadow: [
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

// ── Privileges dialog (duplicated here to keep page self-contained) ───

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
              (p) => Container(
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
                  p,
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
