import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key});

  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  static const List<_CurrencyOption> _currencies = <_CurrencyOption>[
    _CurrencyOption(
      code: 'USD',
      title: 'USD - \$',
      subtitle: 'US Dollar',
      flagCode: 'gb',
    ),
    _CurrencyOption(
      code: 'VND',
      title: 'VND - ₫',
      subtitle: 'Vietnamese Dong',
      flagCode: 'vn',
    ),
    _CurrencyOption(
      code: 'EUR',
      title: 'EUR - €',
      subtitle: 'Euro',
      flagCode: 'eu',
    ),
    _CurrencyOption(
      code: 'GBP',
      title: 'GBP - £',
      subtitle: 'British Pound',
      flagCode: 'gb',
    ),
    _CurrencyOption(
      code: 'JPY',
      title: 'JPY - ¥',
      subtitle: 'Japanese Yen',
      flagCode: 'jp',
    ),
    _CurrencyOption(
      code: 'CNY',
      title: 'CNY - ¥',
      subtitle: 'Chinese Yuan',
      flagCode: 'cn',
    ),
    _CurrencyOption(
      code: 'KRW',
      title: 'KRW - ₩',
      subtitle: 'South Korean Won',
      flagCode: 'kr',
    ),
    _CurrencyOption(
      code: 'AUD',
      title: 'AUD - A\$',
      subtitle: 'Australian Dollar',
      flagCode: 'au',
    ),
    _CurrencyOption(
      code: 'CAD',
      title: 'CAD - C\$',
      subtitle: 'Canadian Dollar',
      flagCode: 'ca',
    ),
    _CurrencyOption(
      code: 'CHF',
      title: 'CHF - Fr',
      subtitle: 'Swiss Franc',
      flagCode: 'ch',
    ),
    _CurrencyOption(
      code: 'SGD',
      title: 'SGD - S\$',
      subtitle: 'Singapore Dollar',
      flagCode: 'sg',
    ),
    _CurrencyOption(
      code: 'HKD',
      title: 'HKD - HK\$',
      subtitle: 'Hong Kong Dollar',
      flagCode: 'hk',
    ),
    _CurrencyOption(
      code: 'INR',
      title: 'INR - ₹',
      subtitle: 'Indian Rupee',
      flagCode: 'in',
    ),
    _CurrencyOption(
      code: 'THB',
      title: 'THB - ฿',
      subtitle: 'Thai Baht',
      flagCode: 'th',
    ),
    _CurrencyOption(
      code: 'MYR',
      title: 'MYR - RM',
      subtitle: 'Malaysian Ringgit',
      flagCode: 'my',
    ),
    _CurrencyOption(
      code: 'IDR',
      title: 'IDR - Rp',
      subtitle: 'Indonesian Rupiah',
      flagCode: 'id',
    ),
    _CurrencyOption(
      code: 'PHP',
      title: 'PHP - ₱',
      subtitle: 'Philippine Peso',
      flagCode: 'ph',
    ),
    _CurrencyOption(
      code: 'RUB',
      title: 'RUB - ₽',
      subtitle: 'Russian Ruble',
      flagCode: 'ru',
    ),
    _CurrencyOption(
      code: 'BRL',
      title: 'BRL - R\$',
      subtitle: 'Brazilian Real',
      flagCode: 'br',
    ),
    _CurrencyOption(
      code: 'MXN',
      title: 'MXN - Mex\$',
      subtitle: 'Mexican Peso',
      flagCode: 'mx',
    ),
  ];

  String _selectedCode = 'USD';

  void _onSelectCurrency(String code) {
    setState(() {
      _selectedCode = code;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                            'Currency',
                            style: TextStyle(
                              fontSize: 29,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Select your preferred currency',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: FontWeight.w400,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                  itemCount: _currencies.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final _CurrencyOption item = _currencies[index];
                    final bool selected = item.code == _selectedCode;
                    return _CurrencyTile(
                      item: item,
                      selected: selected,
                      onTap: () => _onSelectCurrency(item.code),
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

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _CurrencyOption item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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
            color: selected
                ? (isDark
                      ? colors.primary.withValues(alpha: 0.14)
                      : const Color(0xFFE1F5FE))
                : colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF81D4FA) : colors.outlineVariant,
              width: 1.1,
            ),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 36,
                height: 36,
                child: _RoundFlag(flagCode: item.flagCode, radius: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.1,
                        fontWeight: FontWeight.w400,
                        color: colors.onSurfaceVariant,
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

class _CurrencyOption {
  const _CurrencyOption({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.flagCode,
  });

  final String code;
  final String title;
  final String subtitle;
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
