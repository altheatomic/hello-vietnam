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

  List<Widget> _buildCurrencyRows() {
    final List<Widget> rows = <Widget>[];

    for (int i = 0; i < _options.length; i++) {
      final _CurrencyOption option = _options[i];
      final bool isSelected = _selectedCurrency == option.label;

      rows.add(
        InkWell(
          onTap: () {
            setState(() {
              _selectedCurrency = option.label;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${option.label}  ${option.symbol}',
                    style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFF7A7A7A),
                      fontWeight:
                          isSelected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                _SelectCircle(isSelected: isSelected),
              ],
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
                      fontSize: 34,
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
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2AAEEB) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? const Color(0xFF2AAEEB) : const Color(0xFFD2D2D2),
          width: 1.2,
        ),
      ),
    );
  }
}
