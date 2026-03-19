import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const List<_AvatarPreset> _avatarPresets = <_AvatarPreset>[
    _AvatarPreset(icon: Icons.person, color: Color(0xFFE7F3FF), iconColor: Color(0xFF8AA4C1)),
    _AvatarPreset(icon: Icons.directions_car_filled_rounded, color: Color(0xFFFFE8DA), iconColor: Color(0xFF5F6E7A)),
    _AvatarPreset(icon: Icons.flight_takeoff_rounded, color: Color(0xFFE7F7EF), iconColor: Color(0xFF6D9278)),
    _AvatarPreset(icon: Icons.landscape_rounded, color: Color(0xFFF1E8FF), iconColor: Color(0xFF8370A8)),
  ];

  bool _notificationEnabled = false;
  bool _autoDeleteUserDataEnabled = false;
  static const String _autoDeleteUserDataKey = 'auto_delete_user_data_enabled';
  String _username = 'AnhLaThangToi';
  String _email = 'thangtoi@gmail.com';
  int _avatarIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAutoDeleteSetting();
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

  Future<void> _onLogout() async {
    await AuthRepository.instance.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  Future<void> _openEditProfile() async {
    final Map<String, dynamic>? result = await context.push<Map<String, dynamic>>(
      AppRoutes.editProfile,
      extra: <String, dynamic>{
        'email': _email,
        'username': _username,
        'avatarIndex': _avatarIndex,
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;

    return WillPopScope(
      onWillPop: () async {
        context.go(AppRoutes.home);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F3F4),
        body: Column(
          children: <Widget>[
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(10, topInset + 8, 10, 10),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => context.go(AppRoutes.home),
                      icon: const Icon(
                        Icons.chevron_left,
                        size: 26,
                        color: Color(0xFF1C1C1C),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'My Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF121212),
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
                color: const Color(0xFFF3F3F4),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 92),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Material(
                        color: Colors.white,
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
                                  child: Icon(
                                    _avatarPresets[_avatarIndex].icon,
                                    color: _avatarPresets[_avatarIndex].iconColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        _username,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _email,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF9B9B9B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF1D1D1D),
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
                            title: 'Upgrade Account',
                            onTap: () => context.push(AppRoutes.upgradeAccount),
                          ),
                          _SettingRow(
                            icon: Icons.lock_outline_rounded,
                            title: 'Change Password',
                            onTap: () => context.push(AppRoutes.changePassword),
                          ),
                          _SettingRow(
                            icon: Icons.monetization_on_outlined,
                            title: 'Currency',
                            onTap: () => context.push(AppRoutes.currency),
                          ),
                          _SettingRow(
                            icon: Icons.favorite_border_rounded,
                            title: 'Wishlist',
                            onTap: () => context.push(AppRoutes.wishlist),
                          ),
                          _SettingRow(
                            icon: Icons.translate_rounded,
                            title: 'Language',
                            onTap: () => context.push(AppRoutes.language),
                          ),
                          _SettingSwitchRow(
                            icon: Icons.notifications_none_rounded,
                            title: 'Notification',
                            value: _notificationEnabled,
                            onChanged: (bool value) {
                              setState(() {
                                _notificationEnabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        children: <Widget>[
                          _SettingSwitchRow(
                            icon: Icons.shield_outlined,
                            title: 'Delete user data',
                            value: _autoDeleteUserDataEnabled,
                            onChanged: _setAutoDeleteSetting,
                          ),
                          _SettingRow(
                            icon: Icons.logout_rounded,
                            title: 'Log out',
                            iconColor: const Color(0xFFFF3B30),
                            textColor: const Color(0xFF1C1C1C),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF1D1D1D),
              ),
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
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: const Color(0xFFB3B3B3)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E1E1E),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.86,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF58B7E8),
              activeTrackColor: const Color(0xFFBEE7FA),
              inactiveThumbColor: const Color(0xFFFFFFFF),
              inactiveTrackColor: const Color(0xFFE3E3E3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
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
