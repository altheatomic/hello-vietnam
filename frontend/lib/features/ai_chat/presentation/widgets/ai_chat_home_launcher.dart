import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/language/app_language.dart';
import '../../../profile/application/premium_entitlement_controller.dart';
import '../../data/ai_chat_launcher_position_store.dart';
import 'lac_bird_avatar.dart';
import 'liquid_glass_panel.dart';

class AiChatHomeLauncher extends StatefulWidget {
  const AiChatHomeLauncher({
    super.key,
    this.entitlementController,
    this.positionStore,
    this.onOpenChat,
    this.onUpgrade,
  });

  final PremiumEntitlementController? entitlementController;
  final AiChatLauncherPositionStore? positionStore;
  final VoidCallback? onOpenChat;
  final VoidCallback? onUpgrade;

  @override
  State<AiChatHomeLauncher> createState() => _AiChatHomeLauncherState();
}

class _AiChatHomeLauncherState extends State<AiChatHomeLauncher>
    with SingleTickerProviderStateMixin {
  static const double _launcherSize = 60;
  static const double _greetingWidth = 246;
  static const Duration _greetingReadTime = Duration(seconds: 5);
  static const double _horizontalMargin = 12;
  static const double _topMargin = 12;
  static const double _bottomReserved = 112;

  late final AiChatLauncherPositionStore _positionStore;
  late final PremiumEntitlementController _entitlementController;
  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;
  Timer? _greetingTimer;
  Timer? _breathingTimer;
  Timer? _pressTimer;
  AiChatLauncherPosition _position = AiChatLauncherPosition.fallback;
  bool _showGreeting = true;
  bool _breathingOut = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _positionStore = widget.positionStore ?? AiChatLauncherPositionStore();
    _entitlementController =
        widget.entitlementController ?? PremiumEntitlementController.instance;
    _entitlementController.addListener(_handleEntitlementChanged);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _entranceScale = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    );
    _greetingTimer = Timer(
      _entranceController.duration! + _greetingReadTime,
      _hideGreeting,
    );
    _breathingTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) setState(() => _breathingOut = !_breathingOut);
    });
    unawaited(_positionStore.load().then(_applyPosition));
  }

  void _applyPosition(AiChatLauncherPosition position) {
    if (!mounted) return;
    setState(() => _position = position);
  }

  void _handleEntitlementChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    _breathingTimer?.cancel();
    _pressTimer?.cancel();
    _entranceController.dispose();
    _entitlementController.removeListener(_handleEntitlementChanged);
    super.dispose();
  }

  void _hideGreeting() {
    if (mounted && _showGreeting) {
      setState(() => _showGreeting = false);
    }
  }

  void _handleTap() {
    setState(() {
      _pressed = true;
      _showGreeting = false;
    });
    _pressTimer?.cancel();
    _pressTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _pressed = false);
    });
    final PremiumEntitlementStatus status = _entitlementController.state.status;
    if (status == PremiumEntitlementStatus.loading) return;
    if (status == PremiumEntitlementStatus.active &&
        _entitlementController.canUsePremium) {
      _openChat();
      return;
    }
    if (status == PremiumEntitlementStatus.inactive) {
      _openUpgrade();
      return;
    }
    unawaited(_entitlementController.retry());
  }

  void _openChat() {
    final VoidCallback? callback = widget.onOpenChat;
    if (callback != null) {
      callback();
    } else {
      context.push(AppRoutes.aiChat);
    }
  }

  void _openUpgrade() {
    final VoidCallback? callback = widget.onUpgrade;
    if (callback != null) {
      callback();
    } else {
      context.push(AppRoutes.upgradeAccount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final PremiumEntitlementStatus status = _entitlementController.state.status;
    final bool isPremium =
        status == PremiumEntitlementStatus.active &&
        _entitlementController.canUsePremium;
    final bool isLoading = status == PremiumEntitlementStatus.loading;
    final bool isInactive = status == PremiumEntitlementStatus.inactive;
    final bool hasVerificationError = !isLoading && !isInactive && !isPremium;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double horizontalTravel =
            (constraints.maxWidth - _launcherSize - (_horizontalMargin * 2))
                .clamp(0, double.infinity)
                .toDouble();
        final double verticalTravel =
            (constraints.maxHeight -
                    _launcherSize -
                    _topMargin -
                    _bottomReserved)
                .clamp(0, double.infinity)
                .toDouble();
        final double left =
            _horizontalMargin + (_position.x * horizontalTravel);
        final double top = _topMargin + (_position.y * verticalTravel);
        final bool greetingOnLeft =
            left > constraints.maxWidth / 2 && left >= _greetingWidth + 24;
        final double greetingLeft = greetingOnLeft
            ? (left - _greetingWidth - 10).clamp(
                _horizontalMargin,
                constraints.maxWidth - _greetingWidth - _horizontalMargin,
              )
            : (left + _launcherSize + 10).clamp(
                _horizontalMargin,
                constraints.maxWidth - _greetingWidth - _horizontalMargin,
              );
        final double greetingTop = (top + 4).clamp(
          _topMargin,
          constraints.maxHeight - 90,
        );

        return Stack(
          children: <Widget>[
            Positioned(
              left: greetingLeft,
              top: greetingTop,
              width: _greetingWidth,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                reverseDuration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final Animation<Offset> slide = Tween<Offset>(
                    begin: Offset(greetingOnLeft ? 0.10 : -0.10, 0.05),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slide,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.96,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                  );
                },
                child: _showGreeting
                    ? LiquidGlassPanel(
                        key: const Key('ai-chat-launcher-greeting'),
                        borderRadius: 20,
                        blur: 20,
                        tint: isDark
                            ? const Color(0xFF102C3B).withValues(alpha: 0.90)
                            : const Color(0xFFDDF4FF).withValues(alpha: 0.94),
                        borderColor: isDark
                            ? Colors.white.withValues(alpha: 0.16)
                            : colors.primary.withValues(alpha: 0.24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        child: Text(
                          context.l10n.ui(
                            'Hi! Planning a Vietnam trip? Ask me anything.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: _launcherSize,
              height: _launcherSize,
              child: ScaleTransition(
                scale: _entranceScale,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => _hideGreeting(),
                  onPanUpdate: (DragUpdateDetails details) {
                    final double nextX = horizontalTravel == 0
                        ? 0
                        : _position.x + details.delta.dx / horizontalTravel;
                    final double nextY = verticalTravel == 0
                        ? 0
                        : _position.y + details.delta.dy / verticalTravel;
                    setState(() {
                      _position = AiChatLauncherPosition(
                        x: nextX,
                        y: nextY,
                      ).normalized();
                    });
                  },
                  onPanEnd: (_) => unawaited(_positionStore.save(_position)),
                  child: Tooltip(
                    message: isPremium
                        ? context.l10n.ui('Open AI Travel Assistant')
                        : hasVerificationError
                        ? context.l10n.ui('Retry Premium verification')
                        : context.l10n.ui('Premium AI Travel Assistant'),
                    child: AnimatedScale(
                      scale: _pressed ? 0.90 : (_breathingOut ? 1.04 : 1.0),
                      duration: Duration(milliseconds: _pressed ? 100 : 900),
                      curve: _pressed ? Curves.easeOut : Curves.easeInOut,
                      child: AnimatedRotation(
                        turns: _breathingOut ? 0.006 : -0.006,
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeInOut,
                        child: LiquidGlassPanel(
                          borderRadius: _launcherSize / 2,
                          blur: 22,
                          tint: colors.surface.withValues(alpha: 0.58),
                          borderColor: Colors.white.withValues(alpha: 0.72),
                          child: Material(
                            key: const Key('ai-chat-home-launcher'),
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _handleTap,
                              child: Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  if (isLoading)
                                    SizedBox.square(
                                      key: const Key('ai-chat-home-loading'),
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.primary,
                                      ),
                                    )
                                  else
                                    LacBirdAvatar(
                                      size: 41,
                                      color: colors.primary,
                                      semanticLabel: context.l10n.ui(
                                        'AI Travel Assistant',
                                      ),
                                    ),
                                  if (isInactive)
                                    _LauncherBadge(
                                      key: const Key('ai-chat-home-lock'),
                                      icon: Icons.lock_rounded,
                                    ),
                                  if (hasVerificationError)
                                    _LauncherBadge(
                                      key: const Key('ai-chat-home-retry'),
                                      icon: Icons.refresh_rounded,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LauncherBadge extends StatelessWidget {
  const _LauncherBadge({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Positioned(
      right: 2,
      bottom: 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.94),
          shape: BoxShape.circle,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 12, color: colors.onSurface),
        ),
      ),
    );
  }
}
