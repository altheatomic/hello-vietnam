import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme_controller.dart';
import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _defaultAvatarAsset = 'images/avatar/avatar.jpg';
  static const List<_AvatarPreset> _avatarPresets = <_AvatarPreset>[
    _AvatarPreset(
      icon: Icons.person,
      color: Color(0xFFE7F3FF),
      iconColor: Color(0xFF8AA4C1),
    ),
    _AvatarPreset(
      icon: Icons.directions_car_filled_rounded,
      color: Color(0xFFFFE8DA),
      iconColor: Color(0xFF5F6E7A),
    ),
    _AvatarPreset(
      icon: Icons.flight_takeoff_rounded,
      color: Color(0xFFE7F7EF),
      iconColor: Color(0xFF6D9278),
    ),
    _AvatarPreset(
      icon: Icons.landscape_rounded,
      color: Color(0xFFF1E8FF),
      iconColor: Color(0xFF8370A8),
    ),
  ];

  bool _notificationEnabled = false;
  bool _autoDeleteUserDataEnabled = false;
  static const String _autoDeleteUserDataKey = 'auto_delete_user_data_enabled';
  String _username = 'abc';
  String _email = 'abc@gmail.com';
  int _avatarIndex = 0;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAutoDeleteSetting();
    _loadCurrentUserProfile();
  }

  Future<void> _loadAutoDeleteSetting() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool enabled = prefs.getBool(_autoDeleteUserDataKey) ?? false;
    if (!mounted) {
      return;
    }
    setState(() {
      _autoDeleteUserDataEnabled = enabled;
    });
  }

  Future<void> _setAutoDeleteSetting(bool value) async {
    setState(() {
      _autoDeleteUserDataEnabled = value;
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoDeleteUserDataKey, value);
  }

  Future<void> _loadCurrentUserProfile() async {
    final CurrentUserProfileData? profile = await AuthRepository.instance
        .getCurrentUserProfile();

    if (!mounted) return;

    setState(() {
      final String? fullName = profile?.fullName;
      final String? email = profile?.email;
      if (fullName != null && fullName.isNotEmpty) {
        _username = fullName;
      }
      if (email != null && email.isNotEmpty) {
        _email = email;
      }
      _avatarUrl = profile?.avatarUrl;
    });
  }

  Future<void> _onLogout() async {
    await AuthRepository.instance.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  Future<void> _openEditProfile() async {
    final Map<String, dynamic>? result = await context
        .push<Map<String, dynamic>>(
          AppRoutes.editProfile,
          extra: <String, dynamic>{
            'email': _email,
            'username': _username,
            'avatarIndex': _avatarIndex,
            'avatarUrl': _avatarUrl,
          },
        );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _email = (result['email'] as String?)?.trim().isNotEmpty == true
          ? (result['email'] as String).trim()
          : _email;
      _username = (result['username'] as String?)?.trim().isNotEmpty == true
          ? (result['username'] as String).trim()
          : _username;
      _avatarIndex = ((result['avatarIndex'] as int?) ?? _avatarIndex).clamp(
        0,
        _avatarPresets.length - 1,
      );
      _avatarUrl = result['avatarUrl'] as String? ?? _avatarUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.l10n;
    final double topInset = MediaQuery.of(context).padding.top;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _ProfileColors colors = _ProfileColors.forBrightness(
      Theme.of(context).brightness,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: Column(
          children: <Widget>[
            Container(
              color: colors.header,
              padding: EdgeInsets.fromLTRB(10, topInset + 8, 10, 10),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => context.go(AppRoutes.home),
                      icon: Icon(
                        Icons.chevron_left,
                        size: 26,
                        color: colors.primaryText,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        strings.myProfile,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: colors.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: colors.background,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 92),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Material(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: _openEditProfile,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _avatarPresets[_avatarIndex].color,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: _ProfileAvatar(
                                    avatarUrl: _avatarUrl,
                                    fallbackAssetPath: _defaultAvatarAsset,
                                    preset: _avatarPresets[_avatarIndex],
                                    size: 44,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        _username,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: colors.primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _email,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: colors.chevron,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        children: <Widget>[
                          _SettingRow(
                            icon: Icons.workspace_premium_rounded,
                            title: strings.upgradeAccount,
                            onTap: () => context.push(AppRoutes.upgradeAccount),
                          ),
                          _SettingRow(
                            icon: Icons.lock_outline_rounded,
                            title: strings.changePassword,
                            onTap: () => context.push(AppRoutes.changePassword),
                          ),
                          _SettingRow(
                            icon: Icons.favorite_border_rounded,
                            title: strings.wishlist,
                            onTap: () => context.push(AppRoutes.wishlist),
                          ),
                          _SettingRow(
                            icon: Icons.stars_rounded,
                            title: 'Loyalty Rewards',
                            onTap: () => context.push(AppRoutes.loyalty),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        children: <Widget>[
                          _SettingRow(
                            icon: Icons.translate_rounded,
                            title: strings.language,
                            onTap: () => context.push(AppRoutes.language),
                          ),
                          _SettingRow(
                            icon: Icons.monetization_on_outlined,
                            title: strings.currency,
                            onTap: () => context.push(AppRoutes.currency),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        children: <Widget>[
                          AnimatedBuilder(
                            animation: ThemeController.instance,
                            builder: (BuildContext context, Widget? child) {
                              return _SettingSwitchRow(
                                icon: Icons.dark_mode_outlined,
                                title: context.l10n.ui('Dark theme'),
                                value: ThemeController.instance.isDarkMode,
                                onChanged: ThemeController.instance.setDarkMode,
                                useDayNightSwitch: true,
                              );
                            },
                          ),
                          _SettingSwitchRow(
                            icon: Icons.notifications_none_rounded,
                            title: strings.notification,
                            value: _notificationEnabled,
                            onChanged: (bool value) {
                              setState(() {
                                _notificationEnabled = value;
                              });
                            },
                          ),
                          _SettingSwitchRow(
                            icon: Icons.shield_outlined,
                            title: strings.deleteUserData,
                            value: _autoDeleteUserDataEnabled,
                            onChanged: _setAutoDeleteSetting,
                            onTap: () => context.push(AppRoutes.manageUploadedMedia),
                          ),
                          _SettingRow(
                            icon: Icons.logout_rounded,
                            title: strings.logOut,
                            iconColor: const Color(0xFFFF3B30),
                            textColor: isDark
                                ? colors.primaryText
                                : const Color(0xFF1C1C1C),
                            showChevron: false,
                            onTap: _onLogout,
                          ),
                        ],
                      ),
                    ],
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.fallbackAssetPath,
    required this.preset,
    required this.size,
  });

  final String? avatarUrl;
  final String fallbackAssetPath;
  final _AvatarPreset preset;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackAvatar(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Image.asset(
        fallbackAssetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackAvatar(),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Center(
      child: Icon(preset.icon, color: preset.iconColor, size: size * 0.5),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final _ProfileColors colors = _ProfileColors.forBrightness(
      Theme.of(context).brightness,
    );
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor = const Color(0xFFB3B3B3),
    this.textColor = const Color(0xFF1E1E1E),
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final _ProfileColors colors = _ProfileColors.forBrightness(
      Theme.of(context).brightness,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 20,
              color: iconColor == const Color(0xFFB3B3B3)
                  ? colors.mutedIcon
                  : iconColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor == const Color(0xFF1E1E1E)
                      ? colors.primaryText
                      : textColor,
                ),
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right_rounded, color: colors.chevron),
          ],
        ),
      ),
    );
  }
}

class _SettingSwitchRow extends StatelessWidget {
  const _SettingSwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.onTap,
    this.useDayNightSwitch = false,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTap;
  final bool useDayNightSwitch;

  @override
  Widget build(BuildContext context) {
    final _ProfileColors colors = _ProfileColors.forBrightness(
      Theme.of(context).brightness,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: <Widget>[
                    Icon(icon, size: 20, color: colors.mutedIcon),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          useDayNightSwitch
              ? _DayNightThemeSwitch(value: value, onChanged: onChanged)
              : _LiquidGlassSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LiquidGlassSwitch extends StatelessWidget {
  const _LiquidGlassSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  static const double _tapWidth = 72;
  static const double _tapHeight = 44;
  static const double _trackWidth = 72;
  static const double _trackHeight = 34;
  static const double _thumbSize = 28;
  static const double _thumbInset = 3;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: _tapWidth,
          height: _tapHeight,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: value ? 1 : 0),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double progress, Widget? child) {
                final double left =
                    _thumbInset +
                    (_trackWidth - _thumbSize - (_thumbInset * 2)) * progress;
                return Container(
                  width: _trackWidth,
                  height: _trackHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.28 : 0.12,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    Color.lerp(
                                      isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.white.withValues(
                                              alpha: 0.72,
                                            ),
                                      const Color(0xFF64D7FF),
                                      progress,
                                    )!,
                                    Color.lerp(
                                      isDark
                                          ? const Color(
                                              0xFF17303A,
                                            ).withValues(alpha: 0.72)
                                          : const Color(
                                              0xFFEAF8FF,
                                            ).withValues(alpha: 0.84),
                                      const Color(0xFF37D9CB),
                                      progress,
                                    )!,
                                  ],
                                ),
                                border: Border.all(
                                  color: Color.lerp(
                                    isDark
                                        ? Colors.white.withValues(alpha: 0.20)
                                        : const Color(
                                            0xFFB7DCEB,
                                          ).withValues(alpha: 0.78),
                                    Colors.white.withValues(alpha: 0.44),
                                    progress,
                                  )!,
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 3,
                            left: left,
                            child: Container(
                              width: _thumbSize,
                              height: _thumbSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  center: const Alignment(-0.38, -0.48),
                                  colors: <Color>[
                                    Color.lerp(
                                      Colors.white,
                                      const Color(0xFFEFFFFF),
                                      progress,
                                    )!,
                                    Color.lerp(
                                      const Color(0xFFF2F7FA),
                                      const Color(0xFFB9F4FF),
                                      progress,
                                    )!,
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.52),
                                  width: 1,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Color.lerp(
                                      Colors.black.withValues(alpha: 0.22),
                                      const Color(
                                        0xFF4DDFFF,
                                      ).withValues(alpha: 0.42),
                                      progress,
                                    )!,
                                    blurRadius: value ? 14 : 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            left: 8 + (progress * 18),
                            child: Container(
                              width: 32,
                              height: 10,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    Colors.white.withValues(alpha: 0.34),
                                    Colors.white.withValues(alpha: 0.02),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DayNightThemeSwitch extends StatefulWidget {
  const _DayNightThemeSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_DayNightThemeSwitch> createState() => _DayNightThemeSwitchState();
}

class _DayNightThemeSwitchState extends State<_DayNightThemeSwitch>
    with SingleTickerProviderStateMixin {
  static const double _tapWidth = 72;
  static const double _tapHeight = 44;
  static const double _trackWidth = 72;
  static const double _trackHeight = 34;
  static const double _thumbSize = 30;
  static const double _thumbInset = 3;

  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: widget.value ? 1 : 0,
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _DayNightThemeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    if (widget.value) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: widget.value,
      label: 'Dark theme',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(!widget.value),
        child: SizedBox(
          width: _tapWidth,
          height: _tapHeight,
          child: AnimatedBuilder(
            animation: _curve,
            builder: (BuildContext context, Widget? child) {
              final double value = _curve.value.clamp(0.0, 1.0);
              final double left =
                  _thumbInset +
                  (_trackWidth - _thumbSize - (_thumbInset * 2)) * value;
              return Center(
                child: Container(
                  width: _trackWidth,
                  height: _trackHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.28),
                        blurRadius: 2,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DayNightTrackPainter(progress: value),
                          ),
                        ),
                        Positioned(
                          left: left,
                          top: (_trackHeight - _thumbSize) / 2,
                          child: Transform.rotate(
                            angle: value * 0.22,
                            child: CustomPaint(
                              painter: _DayNightThumbPainter(progress: value),
                              child: const SizedBox(
                                width: _thumbSize,
                                height: _thumbSize,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DayNightTrackPainter extends CustomPainter {
  const _DayNightTrackPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Color.lerp(
            const Color(0xFF74C7F5),
            const Color(0xFF161827),
            progress,
          )!,
          Color.lerp(
            const Color(0xFF3F91CB),
            const Color(0xFF3C3F4A),
            progress,
          )!,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, skyPaint);

    _drawDaySky(canvas, size, 1 - progress);
    _drawNightSky(canvas, size, progress);

    final Paint innerBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.6), Radius.circular(size.height)),
      innerBorder,
    );
  }

  void _drawDaySky(Canvas canvas, Size size, double opacity) {
    if (opacity <= 0.01) return;
    final double slide = progress * size.width * 0.18;
    canvas.save();
    canvas.translate(slide, 0);

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25
      ..color = Colors.white.withValues(alpha: 0.14 * opacity);
    for (int i = 0; i < 3; i += 1) {
      canvas.drawCircle(
        Offset(size.width * 0.28, size.height * 0.50),
        34 + i * 18,
        arcPaint,
      );
    }

    final Paint cloudPaint = Paint()
      ..color = const Color(0xFFF2FCFF).withValues(alpha: 0.92 * opacity);
    final Paint cloudShadePaint = Paint()
      ..color = const Color(0xFFD7F0FA).withValues(alpha: 0.72 * opacity);
    final Path cloud = Path()
      ..moveTo(size.width * 0.48, size.height * 0.84)
      ..quadraticBezierTo(
        size.width * 0.56,
        size.height * 0.50,
        size.width * 0.65,
        size.height * 0.72,
      )
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.36,
        size.width * 0.82,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.86,
        size.height * 0.12,
        size.width * 1.06,
        size.height * 0.28,
      )
      ..lineTo(size.width * 1.08, size.height)
      ..lineTo(size.width * 0.48, size.height)
      ..close();
    canvas.drawPath(cloud, cloudShadePaint);
    canvas.drawPath(cloud.shift(const Offset(0, 4)), cloudPaint);
    canvas.restore();
  }

  void _drawNightSky(Canvas canvas, Size size, double opacity) {
    if (opacity <= 0.01) return;
    final double slide = (1 - progress) * size.width * 0.16;
    canvas.save();
    canvas.translate(-slide, 0);

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25
      ..color = Colors.white.withValues(alpha: 0.08 * opacity);
    for (int i = 0; i < 3; i += 1) {
      canvas.drawCircle(
        Offset(size.width * 1.02, size.height * 0.58),
        42 + i * 20,
        arcPaint,
      );
    }

    final Paint starPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.86 * opacity);
    final List<Offset> stars = <Offset>[
      Offset(size.width * 0.20, size.height * 0.31),
      Offset(size.width * 0.31, size.height * 0.60),
      Offset(size.width * 0.46, size.height * 0.42),
      Offset(size.width * 0.58, size.height * 0.70),
    ];
    for (final Offset star in stars) {
      canvas.drawLine(
        star.translate(-2.4, 0),
        star.translate(2.4, 0),
        starPaint,
      );
      canvas.drawLine(
        star.translate(0, -2.4),
        star.translate(0, 2.4),
        starPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DayNightTrackPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _DayNightThumbPainter extends CustomPainter {
  const _DayNightThumbPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2;
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center.translate(1.6, 2.2), radius - 1, shadowPaint);

    final Paint bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        colors: <Color>[
          Color.lerp(
            const Color(0xFFFFE875),
            const Color(0xFFE8EDF8),
            progress,
          )!,
          Color.lerp(
            const Color(0xFFFFD622),
            const Color(0xFFB8C0D0),
            progress,
          )!,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius - 1.2, bodyPaint);

    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.38);
    canvas.drawCircle(center, radius - 1.4, borderPaint);

    if (progress <= 0.04) return;
    final Paint craterPaint = Paint()
      ..color = const Color(0xFF8993A8).withValues(alpha: 0.58 * progress);
    canvas.drawCircle(
      Offset(size.width * 0.34, size.height * 0.62),
      size.width * 0.13 * progress,
      craterPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.66, size.height * 0.55),
      size.width * 0.08 * progress,
      craterPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.28),
      size.width * 0.06 * progress,
      craterPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DayNightThumbPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _AvatarPreset {
  const _AvatarPreset({
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
}

class _ProfileColors {
  const _ProfileColors({
    required this.background,
    required this.header,
    required this.card,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedIcon,
    required this.chevron,
    required this.inactiveSwitchTrack,
  });

  final Color background;
  final Color header;
  final Color card;
  final Color primaryText;
  final Color secondaryText;
  final Color mutedIcon;
  final Color chevron;
  final Color inactiveSwitchTrack;

  factory _ProfileColors.forBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _ProfileColors(
        background: Color(0xFF071A24),
        header: Color(0xFF0B202B),
        card: Color(0xFF102A36),
        primaryText: Color(0xFFE6F7FF),
        secondaryText: Color(0xFF93AEBB),
        mutedIcon: Color(0xFF7E97A5),
        chevron: Color(0xFFCDE8F4),
        inactiveSwitchTrack: Color(0xFF2D4652),
      );
    }

    return const _ProfileColors(
      background: Color(0xFFF3F3F4),
      header: Colors.white,
      card: Colors.white,
      primaryText: Color(0xFF121212),
      secondaryText: Color(0xFF9B9B9B),
      mutedIcon: Color(0xFFB3B3B3),
      chevron: Color(0xFF1D1D1D),
      inactiveSwitchTrack: Color(0xFFE3E3E3),
    );
  }
}
