import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key});

  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  static const List<_CurrencyOption> _options = <_CurrencyOption>[
    _CurrencyOption(label: 'US Dollar', symbol: r'$'),
    _CurrencyOption(label: 'CNY', symbol: '\u00A5'),
    _CurrencyOption(label: 'Euro', symbol: '\u20AC'),
    _CurrencyOption(label: 'British Pound', symbol: '\u00A3'),
  ];

  String _selectedCurrency = 'US Dollar';
  String? _highlightedCurrency;
  int _selectionTick = 0;
  static const Color _tapHighlightColor = Color(0xFFEAF7FF);
  static const Duration _tapHighlightHold = Duration(milliseconds: 80);
  static const Duration _tapHighlightFade = Duration(milliseconds: 800);

  void _onSelectCurrency(String currency) {
    _selectionTick++;
    final int currentTick = _selectionTick;
    setState(() {
      _selectedCurrency = currency;
      _highlightedCurrency = currency;
    });

    Future<void>.delayed(_tapHighlightHold, () {
      if (!mounted || _selectionTick != currentTick) {
        return;
      }
      setState(() {
        _highlightedCurrency = null;
      });
    });
  }

  List<Widget> _buildCurrencyRows() {
    final List<Widget> rows = <Widget>[];

    for (int i = 0; i < _options.length; i++) {
      final _CurrencyOption option = _options[i];
      final bool isSelected = _selectedCurrency == option.label;

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: GestureDetector(
            onTap: () => _onSelectCurrency(option.label),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: _tapHighlightFade,
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: _highlightedCurrency == option.label
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
                            isSelected ? FontWeight.w500 : FontWeight.w400,
                      ),
                      child: Text('${option.label}  ${option.symbol}'),
                    ),
                  ),
                  _SelectCircle(isSelected: isSelected),
                ],
              ),
            ),
          ),
        ),
      );

      if (i != _options.length - 1) {
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
                      'Currency',
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
                    'Select currency',
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
                    child: Column(children: _buildCurrencyRows()),
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

class _CurrencyOption {
  const _CurrencyOption({
    required this.label,
    required this.symbol,
  });

  final String label;
  final String symbol;
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
