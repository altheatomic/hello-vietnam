import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/profile/application/premium_entitlement_controller.dart';
import 'package:hellovietnam/features/profile/data/subscription_repository.dart';

const Color _primaryCyan = Color(0xFF2EB9F8);
const Color _gradientStart = Color(0xFFEFF6FF);
const Color _gradientMiddle = Color(0xFFECFEFF);
const Color _gradientEnd = Color(0xFFF0FDFA);
const Color _selectedCardStart = Color(0xFF22D3EE);
const Color _selectedCardMiddle = Color(0xFF60A5FA);
const Color _selectedCardEnd = Color(0xFF06B6D4);
const Color _unselectedCardStart = Color(0xFF67E8F9);
const Color _unselectedCardMiddle = Color(0xFF93C5FD);
const Color _unselectedCardEnd = Color(0xFF5EEAD4);
const Color _darkBackground = Color(0xFF020B10);
const Color _darkSurface = Color(0xFF0B1A22);
const Color _darkSurfaceHigh = Color(0xFF122832);
const Color _darkText = Color(0xFFF5FBFF);
const Color _darkMuted = Color(0xFFA9BCC7);

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _upgradeText(BuildContext context) =>
    _isDark(context) ? _darkText : const Color(0xFF1F2937);

Color _upgradeMuted(BuildContext context) =>
    _isDark(context) ? _darkMuted : const Color(0xFF64748B);

class _SubscriptionPlan {
  const _SubscriptionPlan({
    required this.id,
    required this.duration,
    required this.price,
    required this.months,
    this.isPopular = false,
  });

  final String id;
  final String duration;
  final String price;
  final int months;
  final bool isPopular;
}

class _PrivilegeItem {
  const _PrivilegeItem({
    required this.icon,
    required this.title,
    required this.color,
  });

  final String icon;
  final String title;
  final Color color;
}

class UpgradeAccountPage extends StatefulWidget {
  const UpgradeAccountPage({
    super.key,
    this.entitlementController,
    this.repository,
  });

  final PremiumEntitlementController? entitlementController;
  final SubscriptionRepository? repository;

  @override
  State<UpgradeAccountPage> createState() => _UpgradeAccountPageState();
}

class _UpgradeAccountPageState extends State<UpgradeAccountPage>
    with SingleTickerProviderStateMixin {
  static const List<_SubscriptionPlan> _plans = <_SubscriptionPlan>[
    _SubscriptionPlan(id: '1m', duration: '1 Month', price: '4.99', months: 1),
    _SubscriptionPlan(
      id: '6m',
      duration: '6 Months',
      price: '19.99',
      months: 6,
      isPopular: true,
    ),
    _SubscriptionPlan(
      id: '12m',
      duration: '12 Months',
      price: '29.99',
      months: 12,
    ),
  ];

  static const List<_PrivilegeItem> _privileges = <_PrivilegeItem>[
    _PrivilegeItem(
      icon: '🤖',
      title: 'Access to AI Object Identification',
      color: Color(0xFF2EB9F8),
    ),
    _PrivilegeItem(
      icon: '💬',
      title: 'Practice Essential Vietnamese Phrases',
      color: Color(0xFF10B981),
    ),
    _PrivilegeItem(
      icon: '✨',
      title: 'Generate Personalized Itinerary',
      color: Color(0xFFF59E0B),
    ),
    _PrivilegeItem(
      icon: '🎁',
      title: 'Many more exclusive voucher & coupon',
      color: Color(0xFFEF4444),
    ),
  ];

  late final SubscriptionRepository _repository;
  late final PremiumEntitlementController _entitlementController;
  late final AnimationController _controller;
  late final Future<List<SubscriptionPaymentHistoryItem>> _paymentHistoryFuture;
  String _selectedPlanId = '6m';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SubscriptionRepository();
    _entitlementController =
        widget.entitlementController ?? PremiumEntitlementController.instance;
    _entitlementController.addListener(_handleEntitlementChanged);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _paymentHistoryFuture = _repository.loadPaymentHistory();
    unawaited(_entitlementController.refresh(force: true));
  }

  @override
  void dispose() {
    _entitlementController.removeListener(_handleEntitlementChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleEntitlementChanged() {
    if (mounted) setState(() {});
  }

  void _onPlanSelected(String planId) {
    setState(() => _selectedPlanId = planId);
  }

  Future<void> _onContinue() async {
    if (_entitlementController.canUsePremium) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.ui(
                'Your premium subscription is still active. You cannot buy another plan yet.',
              ),
            ),
          ),
        );
      return;
    }
    if (!mounted) return;
    context.push(AppRoutes.upgradePayment, extra: _selectedPlanId);
  }

  Future<void> _showPrivilegesModal() {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder:
          (BuildContext context, Animation<double> a1, Animation<double> a2) {
            return Center(
              child: _PrivilegesModal(
                privileges: _privileges,
                onClose: () => Navigator.of(context).pop(),
              ),
            );
          },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            final Animation<double> curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 4 * animation.value,
                sigmaY: 4 * animation.value,
              ),
              child: FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(curved),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
                    child: child,
                  ),
                ),
              ),
            );
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double bottomInset = media.padding.bottom;
    final bool isDark = _isDark(context);

    return Scaffold(
      backgroundColor: isDark ? _darkBackground : _gradientStart,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: _UpgradeBackground(isDark: isDark)),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                toolbarHeight: 72,
                expandedHeight: media.padding.top + 72,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: _GlassHeader(
                  topPadding: media.padding.top,
                  onBack: () => context.pop(),
                  onHelp: _showPrivilegesModal,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 24, bottomInset + 112),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: _Entrance(
                          controller: _controller,
                          begin: 0.18,
                          end: 0.56,
                          offset: Offset.zero,
                          scaleBegin: 0.9,
                          child: const _PremiumBadge(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _Entrance(
                        controller: _controller,
                        begin: 0.22,
                        end: 0.58,
                        offset: const Offset(0, 0.06),
                        child: _CurrentPlanStatus(
                          entitlementState: _entitlementController.state,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Entrance(
                        controller: _controller,
                        begin: 0.24,
                        end: 0.6,
                        offset: const Offset(0, 0.06),
                        child: _SubscriptionDetailsCard(
                          entitlementState: _entitlementController.state,
                          paymentHistoryFuture: _paymentHistoryFuture,
                          onRetry: _entitlementController.retry,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _Entrance(
                        controller: _controller,
                        begin: 0.28,
                        end: 0.64,
                        offset: const Offset(-0.08, 0),
                        child: Text(
                          context.l10n.ui('Select your plan:'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _upgradeText(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List<Widget>.generate(_plans.length, (int index) {
                        final _SubscriptionPlan plan = _plans[index];
                        return _Entrance(
                          controller: _controller,
                          begin: 0.36 + (index * 0.09),
                          end: 0.72 + (index * 0.07),
                          offset: const Offset(-0.08, 0),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PlanCard(
                              plan: plan,
                              isSelected: plan.id == _selectedPlanId,
                              onTap: () => _onPlanSelected(plan.id),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 18),
                      _Entrance(
                        controller: _controller,
                        begin: 0.72,
                        end: 0.96,
                        offset: const Offset(0, 0.08),
                        child: _BenefitsPreviewCard(
                          privileges: _privileges,
                          onMoreTap: _showPrivilegesModal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Entrance(
              controller: _controller,
              begin: 0.78,
              end: 1,
              offset: const Offset(0, 0.08),
              child: _BottomContinueBar(
                entitlementState: _entitlementController.state,
                canUsePremium: _entitlementController.canUsePremium,
                onContinue: () => _onContinue(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeBackground extends StatelessWidget {
  const _UpgradeBackground({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const <Color>[
                  _darkBackground,
                  Color(0xFF03131A),
                  _darkBackground,
                ]
              : const <Color>[_gradientStart, _gradientMiddle, _gradientEnd],
        ),
      ),
      child: Stack(
        children: <Widget>[
          if (!isDark) ...const <Widget>[
            Positioned(
              top: 80,
              right: 40,
              child: _BlurCircle(size: 112, color: Color(0x4D67E8F9)),
            ),
            Positioned(
              bottom: 160,
              left: 40,
              child: _BlurCircle(size: 160, color: Color(0x4D93C5FD)),
            ),
            Positioned(
              top: 360,
              right: 80,
              child: _BlurCircle(size: 96, color: Color(0x4D5EEAD4)),
            ),
            Positioned(
              top: 260,
              left: 92,
              child: _BlurCircle(size: 128, color: Color(0x33DDD6FE)),
            ),
          ] else ...<Widget>[
            Positioned(
              top: 90,
              right: 24,
              child: _BlurCircle(
                size: 150,
                color: _primaryCyan.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              bottom: 180,
              left: 20,
              child: _BlurCircle(
                size: 190,
                color: const Color(0xFF60A5FA).withValues(alpha: 0.07),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _GlassHeader extends StatelessWidget {
  const _GlassHeader({
    required this.topPadding,
    required this.onBack,
    required this.onHelp,
  });

  final double topPadding;
  final VoidCallback onBack;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDark(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? <Color>[
                      _darkBackground.withValues(alpha: 0.88),
                      _darkSurface.withValues(alpha: 0.78),
                    ]
                  : <Color>[
                      _gradientStart.withValues(alpha: 0.95),
                      _gradientMiddle.withValues(alpha: 0.95),
                      _gradientEnd.withValues(alpha: 0.95),
                    ],
            ),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
                tooltip: context.l10n.ui('Back'),
              ),
              Expanded(
                child: Text(
                  context.l10n.ui('Upgrade Account'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: _upgradeText(context),
                  ),
                ),
              ),
              _CircleIconButton(
                icon: Icons.help_outline_rounded,
                onTap: onHelp,
                tooltip: context.l10n.ui('Premium Account Privileges'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDark(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.8),
        shape: const CircleBorder(),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 24, color: _upgradeText(context)),
          ),
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: Transform.translate(
            offset: const Offset(0, 18),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                Color(0xFFFCD34D),
                Color(0xFFFDE047),
                Color(0xFFFBBF24),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.28),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('✨', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text(
                context.l10n.ui('Premium Account'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Text('✨', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrentPlanStatus extends StatelessWidget {
  const _CurrentPlanStatus({required this.entitlementState});

  final PremiumEntitlementState entitlementState;

  String _planLabel(
    BuildContext context,
    CurrentSubscriptionInfo? subscription,
  ) {
    if (subscription == null) return context.l10n.ui('Free');

    switch (subscription.planCode) {
      case '1m':
        return context.l10n.ui('1 Month');
      case '6m':
        return context.l10n.ui('6 Months');
      case '12m':
        return context.l10n.ui('12 Months');
    }

    final int days = subscription.durationDays;
    if (days >= 360) return context.l10n.ui('12 Months');
    if (days >= 170) return context.l10n.ui('6 Months');
    if (days >= 28) return context.l10n.ui('1 Month');

    return subscription.planName.trim().isEmpty
        ? context.l10n.ui('Free')
        : subscription.planName.trim();
  }

  @override
  Widget build(BuildContext context) {
    final CurrentSubscriptionInfo? subscription =
        entitlementState.status == PremiumEntitlementStatus.active
        ? entitlementState.subscription
        : null;
    final String planLabel = switch (entitlementState.status) {
      PremiumEntitlementStatus.loading => context.l10n.ui('Loading'),
      PremiumEntitlementStatus.error => context.l10n.ui('Unverified'),
      _ => _planLabel(context, subscription),
    };
    return Center(
      child: _GlassPanel(
        borderRadius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _primaryCyan.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                size: 17,
                color: _primaryCyan,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                context.l10n.currentPlan(planLabel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _upgradeText(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionDetailsCard extends StatelessWidget {
  const _SubscriptionDetailsCard({
    required this.entitlementState,
    required this.paymentHistoryFuture,
    required this.onRetry,
  });

  final PremiumEntitlementState entitlementState;
  final Future<List<SubscriptionPaymentHistoryItem>> paymentHistoryFuture;
  final VoidCallback onRetry;

  String _dateLabel(DateTime? date) {
    if (date == null) return 'N/A';
    final DateTime local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _planName(
    BuildContext context,
    CurrentSubscriptionInfo? subscription,
  ) {
    if (subscription == null) return context.l10n.ui('Free');
    switch (subscription.planCode) {
      case '1m':
        return context.l10n.ui('Premium 1 Month');
      case '6m':
        return context.l10n.ui('Premium 6 Months');
      case '12m':
        return context.l10n.ui('Premium 12 Months');
    }
    return subscription.planName.trim().isEmpty
        ? context.l10n.ui('Premium')
        : subscription.planName.trim();
  }

  String _remainingLabel(BuildContext context, DateTime? endDate) {
    if (endDate == null) return context.l10n.ui('No active subscription');
    final int days = endDate.difference(DateTime.now().toUtc()).inDays;
    if (days < 0) return context.l10n.ui('Expired');
    if (days == 0) return context.l10n.ui('Expires today');
    return '$days ${context.l10n.ui('days remaining')}';
  }

  @override
  Widget build(BuildContext context) {
    if (entitlementState.status == PremiumEntitlementStatus.loading) {
      return const _GlassPanel(
        borderRadius: 18,
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (entitlementState.status == PremiumEntitlementStatus.error) {
      return _GlassPanel(
        borderRadius: 18,
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(height: 10),
            Text(
              context.l10n.ui('Unable to verify Premium right now.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _upgradeText(context),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              key: const Key('premium-entitlement-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.ui('Retry')),
            ),
          ],
        ),
      );
    }

    final CurrentSubscriptionInfo? subscription =
        entitlementState.status == PremiumEntitlementStatus.active
        ? entitlementState.subscription
        : null;
    return FutureBuilder<List<SubscriptionPaymentHistoryItem>>(
      future: paymentHistoryFuture,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<SubscriptionPaymentHistoryItem>> snapshot,
          ) {
            final List<SubscriptionPaymentHistoryItem> payments =
                snapshot.data ?? const <SubscriptionPaymentHistoryItem>[];
            final bool isPremium =
                subscription?.endDate != null &&
                subscription!.endDate!.isAfter(DateTime.now().toUtc());

            return _GlassPanel(
              borderRadius: 18,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isPremium
                              ? const Color(0xFF10B981).withValues(alpha: 0.14)
                              : _primaryCyan.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isPremium
                              ? Icons.verified_rounded
                              : Icons.workspace_premium_outlined,
                          color: isPremium
                              ? const Color(0xFF10B981)
                              : _primaryCyan,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              isPremium
                                  ? context.l10n.ui('Premium active')
                                  : context.l10n.ui('Free account'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: _upgradeText(context),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _remainingLabel(context, subscription?.endDate),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _upgradeMuted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _SubscriptionMetric(
                          label: context.l10n.ui('Plan'),
                          value: _planName(context, subscription),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SubscriptionMetric(
                          label: context.l10n.ui('Valid until'),
                          value: _dateLabel(subscription?.endDate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.receipt_long_rounded,
                        color: _upgradeText(context),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.ui('Payment history'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _upgradeText(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (payments.isEmpty)
                    Text(
                      context.l10n.ui('No payment history yet.'),
                      style: TextStyle(
                        color: _upgradeMuted(context),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    ...payments
                        .take(4)
                        .map(
                          (SubscriptionPaymentHistoryItem item) =>
                              _PaymentHistoryRow(
                                item: item,
                                dateLabel: _dateLabel,
                              ),
                        ),
                ],
              ),
            );
          },
    );
  }
}

class _SubscriptionMetric extends StatelessWidget {
  const _SubscriptionMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _upgradeMuted(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: _upgradeText(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistoryRow extends StatelessWidget {
  const _PaymentHistoryRow({required this.item, required this.dateLabel});

  final SubscriptionPaymentHistoryItem item;
  final String Function(DateTime? date) dateLabel;

  @override
  Widget build(BuildContext context) {
    final bool confirmed = item.status.toLowerCase() == 'confirmed';
    final bool isDark = _isDark(context);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.75),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: confirmed
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              confirmed
                  ? Icons.check_circle_rounded
                  : Icons.pending_actions_rounded,
              size: 19,
              color: confirmed
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _upgradeText(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dateLabel(item.confirmedAt ?? item.createdAt)} · ${item.provider.toUpperCase()} ${item.method}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _upgradeMuted(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.amountLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: _upgradeText(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  final _SubscriptionPlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDark(context);
    final Color surface = isDark
        ? _darkSurface.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.62);
    final Color border = isSelected
        ? _primaryCyan
        : (isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.90));
    final Color checkFill = isSelected
        ? _primaryCyan
        : (isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFE5E7EB));

    return Semantics(
      button: true,
      selected: isSelected,
      label: context.l10n.ui(plan.duration),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          scale: isSelected ? 1.02 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: isDark
                          ? <Color>[
                              _darkSurfaceHigh.withValues(alpha: 0.95),
                              _darkSurface.withValues(alpha: 0.95),
                            ]
                          : const <Color>[
                              Color(0xFFCFFAFE),
                              Color(0xFFDDEAFB),
                              Color(0xFFCFFAFE),
                            ],
                    )
                  : null,
              color: isSelected ? null : surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border, width: isSelected ? 1.6 : 1),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.28 : (isSelected ? 0.12 : 0.08),
                  ),
                  blurRadius: isSelected ? 18 : 12,
                  offset: Offset(0, isSelected ? 9 : 6),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isSelected
                                ? const <Color>[
                                    _selectedCardStart,
                                    _selectedCardMiddle,
                                    _selectedCardEnd,
                                  ]
                                : const <Color>[
                                    _unselectedCardStart,
                                    _unselectedCardMiddle,
                                    _unselectedCardEnd,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.l10n.ui(plan.duration),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.justPrice(plan.price),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: checkFill,
                        borderRadius: BorderRadius.circular(11),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : const Color(0xFF9CA3AF),
                                width: 1.5,
                              ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                  ],
                ),
                if (plan.isPopular)
                  Positioned(
                    top: -10,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[Color(0xFFEC4899), Color(0xFFF43F5E)],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Text(
                        context.l10n.ui('POPULAR'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
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

class _BenefitsPreviewCard extends StatelessWidget {
  const _BenefitsPreviewCard({
    required this.privileges,
    required this.onMoreTap,
  });

  final List<_PrivilegeItem> privileges;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final List<_PrivilegeItem> previewItems = privileges.take(2).toList();
    return _GlassPanel(
      borderRadius: 16,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Text(
                context.l10n.ui("What you'll get:"),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _upgradeText(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...previewItems.map((PrivilegeItem item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CompactPrivilegeRow(item: item),
            );
          }),
          const SizedBox(height: 6),
          InkWell(
            onTap: onMoreTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                context.l10n.ui('+ 2 more benefits'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primaryCyan,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef PrivilegeItem = _PrivilegeItem;

class _CompactPrivilegeRow extends StatelessWidget {
  const _CompactPrivilegeRow({required this.item});

  final _PrivilegeItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(item.icon, style: const TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            context.l10n.ui(item.title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _upgradeMuted(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomContinueBar extends StatelessWidget {
  const _BottomContinueBar({
    required this.entitlementState,
    required this.canUsePremium,
    required this.onContinue,
  });

  final PremiumEntitlementState entitlementState;
  final bool canUsePremium;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDark(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? <Color>[
                      _darkBackground.withValues(alpha: 0.74),
                      _darkSurface.withValues(alpha: 0.86),
                    ]
                  : <Color>[
                      _gradientMiddle.withValues(alpha: 0.72),
                      _gradientEnd.withValues(alpha: 0.82),
                    ],
            ),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          child: _GradientButton(
            key: const Key('upgrade-continue'),
            label: canUsePremium
                ? context.l10n.ui(
                    'Premium active until ${_compactDate(entitlementState.subscription?.endDate)}',
                  )
                : entitlementState.status == PremiumEntitlementStatus.error
                ? context.l10n.ui('Verify Premium to continue')
                : entitlementState.status == PremiumEntitlementStatus.loading
                ? context.l10n.ui('Checking Premium...')
                : context.l10n.ui('Continue'),
            height: 56,
            onTap: entitlementState.status == PremiumEntitlementStatus.inactive
                ? onContinue
                : null,
          ),
        ),
      ),
    );
  }
}

String _compactDate(DateTime? date) {
  if (date == null) return '';
  final DateTime local = date.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

class _PrivilegesModal extends StatelessWidget {
  const _PrivilegesModal({required this.privileges, required this.onClose});

  final List<_PrivilegeItem> privileges;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width * 0.9;
    final bool isDark = _isDark(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width.clamp(0, 448).toDouble(),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const <Color>[
                    _darkSurfaceHigh,
                    _darkSurface,
                    Color(0xFF0B2426),
                  ]
                : const <Color>[
                    Color(0xFFCFFAFE),
                    Color(0xFFDDEAFB),
                    Color(0xFFCFFAFE),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? const Color(0xFF31505E)
                : Colors.white.withValues(alpha: 0.6),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ShaderMask(
                    shaderCallback: (Rect bounds) => const LinearGradient(
                      colors: <Color>[
                        Color(0xFFFBBF24),
                        Color(0xFFFDE047),
                        Color(0xFFF59E0B),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      context.l10n.ui('Premium Account Privileges'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  ...List<Widget>.generate(privileges.length, (int index) {
                    return _ModalPrivilegeCard(
                      item: privileges[index],
                      index: index,
                    );
                  }),
                  const SizedBox(height: 20),
                  _GradientButton(
                    label: context.l10n.ui('Continue'),
                    height: 48,
                    onTap: onClose,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Material(
                color: isDark
                    ? _darkSurfaceHigh
                    : Colors.white.withValues(alpha: 0.82),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onClose,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.close_rounded,
                      color: _upgradeText(context),
                      size: 22,
                    ),
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

class _ModalPrivilegeCard extends StatelessWidget {
  const _ModalPrivilegeCard({required this.item, required this.index});

  final _PrivilegeItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDark(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(-20 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? _darkSurfaceHigh.withValues(alpha: 0.94)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? const Color(0xFF31505E)
                : Colors.white.withValues(alpha: 0.6),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(item.icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.ui(item.title),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w800,
                  color: _upgradeText(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    super.key,
    required this.label,
    required this.height,
    required this.onTap,
  });

  final String label;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (BuildContext context, double scale, Widget? child) {
        return child!;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: onTap == null
                    ? const <Color>[Color(0xFF94A3B8), Color(0xFFCBD5E1)]
                    : const <Color>[
                        Color(0xFF22D3EE),
                        Color(0xFF60A5FA),
                        Color(0xFF06B6D4),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _primaryCyan.withValues(alpha: 0.24),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.padding,
    required this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDark(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? _darkSurface.withValues(alpha: 0.74)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.6),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.controller,
    required this.begin,
    required this.end,
    required this.child,
    this.offset = Offset.zero,
    this.scaleBegin = 1,
  });

  final AnimationController controller;
  final double begin;
  final double end;
  final Widget child;
  final Offset offset;
  final double scaleBegin;

  @override
  Widget build(BuildContext context) {
    final Animation<double> curved = CurvedAnimation(
      parent: controller,
      curve: Interval(
        begin,
        end.clamp(begin + 0.01, 1).toDouble(),
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double value = curved.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              offset.dx * (1 - value) * 240,
              offset.dy * (1 - value) * 240,
            ),
            child: Transform.scale(
              scale: scaleBegin + ((1 - scaleBegin) * value),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
