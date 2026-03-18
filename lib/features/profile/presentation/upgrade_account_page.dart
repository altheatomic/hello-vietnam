import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';

// ── Data ─────────────────────────────────────────────────────────────

class _Plan {
  const _Plan({required this.id, required this.duration, required this.label});

  final String id;
  final String duration;

  /// Price line shown inside the card (e.g. "Just 4.99 $").
  final String label;
}

// ── Page ─────────────────────────────────────────────────────────────

/// Pushed from Profile → "Upgrade Account".
///
/// Shows three subscription plans. Tapping "?" shows a dialog listing
/// Premium privileges. Tapping "Continue" pushes the payment method page.
class UpgradeAccountPage extends StatefulWidget {
  const UpgradeAccountPage({super.key});

  @override
  State<UpgradeAccountPage> createState() => _UpgradeAccountPageState();
}

class _UpgradeAccountPageState extends State<UpgradeAccountPage> {
  static const List<_Plan> _plans = [
    _Plan(id: '1m', duration: '1 Month', label: 'Just 4.99 \$'),
    _Plan(id: '6m', duration: '6 Months', label: '19.99 \$'),
    _Plan(id: '12m', duration: '12 Months', label: '29.99 \$'),
  ];

  String _selectedId = '6m';

  void _showPrivileges() {
    showDialog<void>(
      context: context,
      builder: (_) => const _PrivilegesDialog(),
    );
  }

  void _onContinue() {
    context.push(AppRoutes.upgradePayment, extra: _selectedId);
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          // ── Header — mirrors Profile/Currency header ──────────
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
                      'Upgrade Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF121212),
                      ),
                    ),
                  ),
                  // Help button — dark square with "?" icon
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

          // ── Plan banner ───────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.primaryLight.withValues(alpha: 0.25),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Text(
              'Select your plan:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // ── Plan cards ────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                28,
                AppConstants.pagePadding,
                0,
              ),
              child: Column(
                children: _plans
                    .map(
                      (plan) => _PlanCard(
                        plan: plan,
                        isSelected: plan.id == _selectedId,
                        onTap: () => setState(() => _selectedId = plan.id),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),

          // ── Continue button ───────────────────────────────────
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
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.cardRadius,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

// ── Plan card ─────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  final _Plan plan;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.defaultAnimation,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Row(
          children: <Widget>[
            // ── Plan info pill ──────────────────────────────────
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(
                    AppConstants.buttonRadius,
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      plan.duration,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 14),

            // ── Checkbox ────────────────────────────────────────
            AnimatedContainer(
              duration: AppConstants.defaultAnimation,
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primaryLight.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Privileges dialog ─────────────────────────────────────────────────

/// Shown when the "?" help button is tapped.
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
            // ── Close button ──────────────────────────────────
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

            // ── Title in gold — matches spec ──────────────────
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

            // ── Privilege cards ───────────────────────────────
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

            // ── Continue dismiss ──────────────────────────────
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
