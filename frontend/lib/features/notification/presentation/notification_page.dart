import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/app_loading_screen.dart';
import 'package:hellovietnam/features/notification/domain/app_notification.dart';
import 'package:hellovietnam/features/notification/presentation/notification_action_handler.dart';
import 'package:hellovietnam/features/notification/presentation/notification_controller.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late final NotificationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NotificationController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final Set<NotificationFilter> draftFilters = Set<NotificationFilter>.from(
      _controller.activeFilters,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (BuildContext context) {
        final MediaQueryData media = MediaQuery.of(context);

        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setModalState,
              ) {
                return SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 18,
                      right: 18,
                      bottom: media.padding.bottom + 14,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                        bottom: Radius.circular(28),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.74),
                            ),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x331A3552),
                                blurRadius: 28,
                                offset: Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              SizedBox(
                                height: 34,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            draftFilters.clear();
                                          });
                                        },
                                        child: const Text(
                                          'Clear All',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF7D8594),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Center(
                                      child: Text(
                                        'Filters',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2B3340),
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: GestureDetector(
                                        onTap: () =>
                                            Navigator.of(context).pop(),
                                        child: const SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 22,
                                            color: Color(0xFF80889A),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 26),
                              const Text(
                                'Notification type',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A5566),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: NotificationFilter.values
                                    .map((filter) {
                                      final bool isAll =
                                          filter == NotificationFilter.all;
                                      final bool selected = isAll
                                          ? draftFilters.isEmpty
                                          : draftFilters.contains(filter);
                                      return _FilterChip(
                                        label: filter.label,
                                        selected: selected,
                                        onTap: () {
                                          setModalState(() {
                                            if (isAll) {
                                              draftFilters.clear();
                                              return;
                                            }
                                            if (draftFilters.contains(filter)) {
                                              draftFilters.remove(filter);
                                            } else {
                                              draftFilters.add(filter);
                                            }
                                          });
                                        },
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 26),
                              SizedBox(
                                width: double.infinity,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: <Color>[
                                        Color(0xFF17C7EE),
                                        Color(0xFF4A96F8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: const <BoxShadow>[
                                      BoxShadow(
                                        color: Color(0x33269FEA),
                                        blurRadius: 18,
                                        offset: Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _controller.applyFilters(draftFilters);
                                      Navigator.of(context).pop();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: Text(
                                      'Apply Filters (${draftFilters.length})',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
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
                );
              },
        );
      },
    );
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    await _controller.markAsRead(notification.id);
    if (!mounted) {
      return;
    }
    await NotificationActionHandler.open(context, notification);
  }

  Future<void> _clearAllNotifications() async {
    await _controller.clearAll();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.ui('All notifications were cleared')),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _NotificationBackground()),
          SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: _controller,
              builder: (BuildContext context, Widget? child) {
                final List<AppNotification> notifications =
                    _controller.visibleNotifications;

                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: _NotificationHeader(
                        activeFilterCount: _controller.activeFilterCount,
                        onBack: () => Navigator.of(context).maybePop(),
                        onFilter: _openFilters,
                      ),
                    ),
                    if (_controller.isLoading)
                      const Expanded(
                        child: AppLoadingScreen(
                          message: 'Loading notifications',
                          compact: true,
                        ),
                      )
                    else if (_controller.errorMessage != null)
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _controller.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (notifications.isEmpty)
                      const Expanded(child: _NotificationEmptyState())
                    else
                      Expanded(
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            10,
                            16,
                            topInset + 28,
                          ),
                          itemCount: notifications.length + 1,
                          separatorBuilder: (BuildContext context, int index) =>
                              const SizedBox(height: 14),
                          itemBuilder: (BuildContext context, int index) {
                            if (index == notifications.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Center(
                                  child: _ClearAllButton(
                                    onTap: _clearAllNotifications,
                                  ),
                                ),
                              );
                            }

                            final AppNotification notification =
                                notifications[index];
                            return _AnimatedNotificationTile(
                              index: index,
                              child: _NotificationTile(
                                notification: notification,
                                onTap: () =>
                                    _handleNotificationTap(notification),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBackground extends StatelessWidget {
  const _NotificationBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFF1F7FF),
            Color(0xFFE3FBFF),
            Color(0xFFF8FFFE),
          ],
        ),
      ),
      child: Stack(
        children: const <Widget>[
          Positioned(
            top: -64,
            left: -42,
            child: _Orb(size: 160, color: Color(0x3D8DD8FF)),
          ),
          Positioned(
            top: 220,
            right: -58,
            child: _Orb(size: 190, color: Color(0x3A73F1E4)),
          ),
          Positioned(
            bottom: 72,
            left: -50,
            child: _Orb(size: 176, color: Color(0x3340D8FF)),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                color,
                color.withValues(alpha: 0.34),
                color.withValues(alpha: 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader({
    required this.activeFilterCount,
    required this.onBack,
    required this.onFilter,
  });

  final int activeFilterCount;
  final VoidCallback onBack;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: _CircleGlassButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),
          ),
          const Center(
            child: Text(
              'Notification',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2FAAF4),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                _CircleGlassButton(
                  icon: Icons.filter_alt_outlined,
                  onTap: onFilter,
                ),
                if (activeFilterCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$activeFilterCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
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

class _CircleGlassButton extends StatelessWidget {
  const _CircleGlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x220A2942),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF667085)),
      ),
    );
  }
}

class _AnimatedNotificationTile extends StatelessWidget {
  const _AnimatedNotificationTile({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 70)),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color typeColor = notification.type.accentColor;
    final Color typeBackground = notification.type.backgroundColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.white.withValues(alpha: 0.82)
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
          boxShadow: notification.isRead
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x120F2C4F),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ]
              : const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x2410283F),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: typeBackground,
                shape: BoxShape.circle,
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                notification.icon.iconData,
                size: 24,
                color: typeColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: notification.isRead
                                ? const Color(0xFF5E6675)
                                : const Color(0xFF28313F),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        notification.timestampLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA0A7B4),
                        ),
                      ),
                      if (!notification.isRead) ...<Widget>[
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10C3F0),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: notification.isRead
                          ? const Color(0xFF9EA6B3)
                          : const Color(0xFF5F6B7A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearAllButton extends StatelessWidget {
  const _ClearAllButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x210F2C4F),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Text(
          'Clear All',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7A8191),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF14C6EE) : const Color(0xFFF3F5F8),
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x3317BFEF),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF6C7686),
          ),
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.92, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double value, Widget? child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(scale: value, child: child),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          const Color(0xFFC7EFFD).withValues(alpha: 0.78),
                          const Color(0xFFBFDFFF).withValues(alpha: 0.54),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 58,
                        color: Color(0xFFB8C2D4),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -2,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x2A0F2C4F),
                            blurRadius: 18,
                            offset: Offset(0, 9),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'zZ',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3269F3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'No Notifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "We'll let you know when there will be\nsomething to update you.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: Color(0xFF8B93A1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
