import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  static const List<String> _languages = <String>[
    'English',
    'Chinese',
    'French',
    'Spanish',
  ];

  String _selectedLanguage = 'English';
  String? _highlightedLanguage;
  int _selectionTick = 0;
  static const Color _tapHighlightColor = Color(0xFFEAF7FF);
  static const Duration _tapHighlightHold = Duration(milliseconds: 90);
  static const Duration _tapHighlightFade = Duration(milliseconds: 900);

  void _onSelectLanguage(String language) {
    _selectionTick++;
    final int currentTick = _selectionTick;
    setState(() {
      _selectedLanguage = language;
      _highlightedLanguage = language;
    });

    Future<void>.delayed(_tapHighlightHold, () {
      if (!mounted || _selectionTick != currentTick) {
        return;
      }
      setState(() {
        _highlightedLanguage = null;
      });
    });
  }

  List<Widget> _buildLanguageRows() {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < _languages.length; i++) {
      final String language = _languages[i];
      final bool isSelected = _selectedLanguage == language;

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: GestureDetector(
            onTap: () => _onSelectLanguage(language),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: _tapHighlightFade,
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: _highlightedLanguage == language
                    ? _tapHighlightColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        fontSize: 15,
                        color: const Color(0xFF7A7A7A),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      child: Text(language),
                    ),
                  ),
                  _SelectCircle(isSelected: isSelected),
                ],
              ),
            ),
          ),
        ),
      );

      if (i != _languages.length - 1) {
        rows.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Color(0xFFE7E7E7)),
          ),
        );
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;

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
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 26,
                      color: Color(0xFF1C1C1C),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Language',
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Select language',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDDDDDD)),
                    ),
                    child: Column(children: _buildLanguageRows()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectCircle extends StatelessWidget {
  const _SelectCircle({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: 30,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFD7D7D7),
          width: 1.4,
        ),
      ),
      child: Center(
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          scale: isSelected ? 1 : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isSelected ? 1 : 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFF2EB9F8),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
