import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/language/app_language.dart';
import '../../../profile/application/premium_entitlement_controller.dart';
import '../../data/ai_chat_launcher_position_store.dart';

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

class _AiChatHomeLauncherState extends State<AiChatHomeLauncher> {
  static const double _launcherSize = 58;
  static const double _horizontalMargin = 12;
  static const double _topMargin = 12;
  static const double _bottomReserved = 112;

  late final AiChatLauncherPositionStore _positionStore;
  late final PremiumEntitlementController _entitlementController;
  AiChatLauncherPosition _position = AiChatLauncherPosition.fallback;

  @override
  void initState() {
    super.initState();
    _positionStore = widget.positionStore ?? AiChatLauncherPositionStore();
    _entitlementController =
        widget.entitlementController ?? PremiumEntitlementController.instance;
    _entitlementController.addListener(_handleEntitlementChanged);
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
    _entitlementController.removeListener(_handleEntitlementChanged);
    super.dispose();
  }

  void _handleTap() {
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

        return Stack(
          children: <Widget>[
            Positioned(
              left: left,
              top: top,
              width: _launcherSize,
              height: _launcherSize,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
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
                  child: Material(
                    key: const Key('ai-chat-home-launcher'),
                    color: colors.primary,
                    elevation: 5,
                    shadowColor: colors.shadow.withValues(alpha: 0.24),
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
                                color: colors.onPrimary,
                              ),
                            )
                          else
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 28,
                              color: colors.onPrimary,
                            ),
                          if (isInactive)
                            Positioned(
                              key: const Key('ai-chat-home-lock'),
                              right: 3,
                              bottom: 3,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: Icon(
                                    Icons.lock_rounded,
                                    size: 12,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          if (hasVerificationError)
                            Positioned(
                              key: const Key('ai-chat-home-retry'),
                              right: 3,
                              bottom: 3,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: Icon(
                                    Icons.refresh_rounded,
                                    size: 12,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
