import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/language/app_language.dart';
import '../../../profile/data/subscription_repository.dart';
import '../../data/ai_chat_launcher_position_store.dart';

typedef AiChatLauncherPremiumLoader = Future<bool> Function();

class AiChatHomeLauncher extends StatefulWidget {
  const AiChatHomeLauncher({
    super.key,
    this.premiumLoader,
    this.positionStore,
    this.onOpenChat,
    this.onUpgrade,
  });

  final AiChatLauncherPremiumLoader? premiumLoader;
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
  AiChatLauncherPosition _position = AiChatLauncherPosition.fallback;
  bool _isCheckingPremium = true;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _positionStore = widget.positionStore ?? AiChatLauncherPositionStore();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final AiChatLauncherPosition position = await _positionStore.load();
    bool isPremium = false;
    try {
      final AiChatLauncherPremiumLoader loader =
          widget.premiumLoader ?? _loadPremiumStatus;
      isPremium = await loader();
    } catch (_) {
      isPremium = false;
    }
    if (!mounted) return;
    setState(() {
      _position = position;
      _isPremium = isPremium;
      _isCheckingPremium = false;
    });
  }

  Future<bool> _loadPremiumStatus() async {
    return await SubscriptionRepository().loadCurrentSubscription() != null;
  }

  void _handleTap() {
    if (_isCheckingPremium) return;
    if (_isPremium) {
      final VoidCallback? callback = widget.onOpenChat;
      if (callback != null) {
        callback();
      } else {
        context.push(AppRoutes.aiChat);
      }
      return;
    }

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
                  message: _isPremium
                      ? context.l10n.ui('Open AI Travel Assistant')
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
                          if (_isCheckingPremium)
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
                          if (!_isCheckingPremium && !_isPremium)
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
