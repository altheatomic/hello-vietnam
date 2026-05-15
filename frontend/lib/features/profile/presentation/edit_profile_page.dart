import 'package:flutter/material.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.initialEmail,
    required this.initialUsername,
    required this.initialAvatarIndex,
  });

  final String initialEmail;
  final String initialUsername;
  final int initialAvatarIndex;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const String _defaultAvatarAsset = 'images/avatar/avatar.jpg';
  static const List<_AvatarPreset> _avatarPresets = <_AvatarPreset>[
    _AvatarPreset(icon: Icons.person, color: Color(0xFFE7F3FF), iconColor: Color(0xFF8AA4C1)),
    _AvatarPreset(icon: Icons.directions_car_filled_rounded, color: Color(0xFFFFE8DA), iconColor: Color(0xFF5F6E7A)),
    _AvatarPreset(icon: Icons.flight_takeoff_rounded, color: Color(0xFFE7F7EF), iconColor: Color(0xFF6D9278)),
    _AvatarPreset(icon: Icons.landscape_rounded, color: Color(0xFFF1E8FF), iconColor: Color(0xFF8370A8)),
  ];

  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  late final TextEditingController _usernameController = TextEditingController(
    text: widget.initialUsername,
  );
  late int _avatarIndex = widget.initialAvatarIndex.clamp(
    0,
    _avatarPresets.length - 1,
  );

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _openAvatarPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Choose Avatar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List<Widget>.generate(_avatarPresets.length, (int index) {
                  final bool selected = index == _avatarIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _avatarIndex = index;
                      });
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: _avatarPresets[index].color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? const Color(0xFF69BCE8) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: index == 0
                            ? Image.asset(
                                _defaultAvatarAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  _avatarPresets[index].icon,
                                  size: 28,
                                  color: _avatarPresets[index].iconColor,
                                ),
                              )
                            : Icon(
                                _avatarPresets[index].icon,
                                size: 28,
                                color: _avatarPresets[index].iconColor,
                              ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onSave() {
    Navigator.of(context).pop(<String, dynamic>{
      'email': _emailController.text.trim(),
      'username': _usernameController.text.trim(),
      'avatarIndex': _avatarIndex,
    });
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    final _AvatarPreset avatar = _avatarPresets[_avatarIndex];

    return Scaffold(
      backgroundColor: Colors.white,
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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 26,
                      color: Color(0xFF1C1C1C),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Edit Profile',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Stack(
                      children: <Widget>[
                        GestureDetector(
                          onTap: _openAvatarPicker,
                          child: Container(
                            width: 128,
                            height: 128,
                            decoration: BoxDecoration(
                              color: avatar.color,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: _avatarIndex == 0
                                  ? Image.asset(
                                      _defaultAvatarAsset,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        avatar.icon,
                                        size: 58,
                                        color: avatar.iconColor,
                                      ),
                                    )
                                  : Icon(
                                      avatar.icon,
                                      size: 58,
                                      color: avatar.iconColor,
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFDDDDDD)),
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Color(0xFF5F5F5F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Email',
                    style: TextStyle(
                      color: Color(0xFF2AAEEB),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Username',
                    style: TextStyle(
                      color: Color(0xFF2AAEEB),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _usernameController,
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81D4FA),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF5B5B5B)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF5B5B5B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2AAEEB), width: 1.4),
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
