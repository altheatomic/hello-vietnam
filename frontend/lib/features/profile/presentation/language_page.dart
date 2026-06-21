import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/core/language/app_language.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  static const List<AppLanguage> _languages = <AppLanguage>[
    AppLanguage.english,
    AppLanguage.vietnamese,
  ];

  Future<void> _onSelectLanguage(AppLanguage language) async {
    await context.languageController.setLanguage(language);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.l10n;
    final AppLanguage selectedLanguage = context.languageController.language;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            strings.language,
                            style: const TextStyle(
                              fontSize: 29,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF101828),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            strings.selectPreferredLanguage,
                            style: const TextStyle(
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
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final AppLanguage item = _languages[index];
                    final bool selected = item == selectedLanguage;
                    return _LanguageTile(
                      item: item,
                      selected: selected,
                      onTap: () => _onSelectLanguage(item),
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

  final AppLanguage item;
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
              color: selected
                  ? const Color(0xFF81D4FA)
                  : const Color(0xFFE5E7EB),
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
                      item == AppLanguage.english
                          ? context.l10n.appInterfaceLanguage
                          : item.englishName,
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
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) => Container(
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
