import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  static const List<_LanguageOption> _languages = <_LanguageOption>[
    _LanguageOption(
      code: 'vi',
      nativeName: 'Tiếng Việt',
      englishName: 'Vietnamese',
      flagCode: 'vn',
    ),
    _LanguageOption(
      code: 'en',
      nativeName: 'English',
      englishName: 'English',
      flagCode: 'gb',
    ),
    _LanguageOption(
      code: 'zh',
      nativeName: '中文',
      englishName: 'Chinese',
      flagCode: 'cn',
    ),
    _LanguageOption(
      code: 'es',
      nativeName: 'Español',
      englishName: 'Spanish',
      flagCode: 'es',
    ),
    _LanguageOption(
      code: 'fr',
      nativeName: 'Français',
      englishName: 'French',
      flagCode: 'fr',
    ),
    _LanguageOption(
      code: 'de',
      nativeName: 'Deutsch',
      englishName: 'German',
      flagCode: 'de',
    ),
    _LanguageOption(
      code: 'ja',
      nativeName: '日本語',
      englishName: 'Japanese',
      flagCode: 'jp',
    ),
    _LanguageOption(
      code: 'ko',
      nativeName: '한국어',
      englishName: 'Korean',
      flagCode: 'kr',
    ),
    _LanguageOption(
      code: 'ru',
      nativeName: 'Русский',
      englishName: 'Russian',
      flagCode: 'ru',
    ),
    _LanguageOption(
      code: 'ar',
      nativeName: 'العربية',
      englishName: 'Arabic',
      flagCode: 'sa',
    ),
    _LanguageOption(
      code: 'pt',
      nativeName: 'Português',
      englishName: 'Portuguese',
      flagCode: 'pt',
    ),
    _LanguageOption(
      code: 'it',
      nativeName: 'Italiano',
      englishName: 'Italian',
      flagCode: 'it',
    ),
    _LanguageOption(
      code: 'nl',
      nativeName: 'Nederlands',
      englishName: 'Dutch',
      flagCode: 'nl',
    ),
    _LanguageOption(
      code: 'pl',
      nativeName: 'Polski',
      englishName: 'Polish',
      flagCode: 'pl',
    ),
    _LanguageOption(
      code: 'tr',
      nativeName: 'Türkçe',
      englishName: 'Turkish',
      flagCode: 'tr',
    ),
    _LanguageOption(
      code: 'th',
      nativeName: 'ไทย',
      englishName: 'Thai',
      flagCode: 'th',
    ),
    _LanguageOption(
      code: 'id',
      nativeName: 'Bahasa Indonesia',
      englishName: 'Indonesian',
      flagCode: 'id',
    ),
    _LanguageOption(
      code: 'hi',
      nativeName: 'हिन्दी',
      englishName: 'Hindi',
      flagCode: 'in',
    ),
  ];

  String _selectedCode = 'en';

  void _onSelectLanguage(String code) {
    setState(() {
      _selectedCode = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 76,
                child: Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Color(0xFF81D4FA),
                        ),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Language',
                            style: TextStyle(
                              fontSize: 29,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF101828),
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Select your preferred language',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF4A5565),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 28),
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final _LanguageOption item = _languages[index];
                    final bool selected = item.code == _selectedCode;
                    return _LanguageTile(
                      item: item,
                      selected: selected,
                      onTap: () => _onSelectLanguage(item.code),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _LanguageOption item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 66,
          padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE1F5FE) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF81D4FA) : const Color(0xFFE5E7EB),
              width: 1.1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: _RoundFlag(flagCode: item.flagCode, radius: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.nativeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.englishName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.1,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6A7282),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: selected
                    ? Container(
                        key: const ValueKey<String>('selected'),
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFF81D4FA),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      )
                    : const SizedBox(key: ValueKey<String>('unselected')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.flagCode,
  });

  final String code;
  final String nativeName;
  final String englishName;
  final String flagCode;
}

class _RoundFlag extends StatelessWidget {
  const _RoundFlag({required this.flagCode, this.radius = 9});

  final String? flagCode;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD6DEE9)),
      ),
      alignment: Alignment.center,
      child: flagCode == null
          ? Icon(
              Icons.public_rounded,
              size: radius + 2,
              color: const Color(0xFF6AA9CC),
            )
          : ClipOval(
              child: Image.network(
                'https://flagcdn.com/w40/${flagCode!.toLowerCase()}.png',
                width: radius * 2 - 2,
                height: radius * 2 - 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFEAF0F8),
                  alignment: Alignment.center,
                  child: Text(
                    flagCode!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6F7D90),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
