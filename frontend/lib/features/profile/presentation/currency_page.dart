import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/features/profile/data/currency_service.dart';

class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key, this.controller});

  final CurrencyController? controller;

  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  CurrencyController get _controller =>
      widget.controller ?? CurrencyRepository.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleCurrencyStateChanged);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.removeListener(_handleCurrencyStateChanged);
    super.dispose();
  }

  void _handleCurrencyStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _selectCurrency(String code) async {
    try {
      await _controller.selectCurrency(code);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save currency: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color textColor = theme.colorScheme.onSurface;
    final Color mutedColor = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                        tooltip: 'Back',
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
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Select your preferred currency',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: FontWeight.w400,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _CurrencyRateStatus(controller: _controller),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 28),
                  itemCount: _controller.options.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final CurrencyOptionViewModel item =
                        _controller.options[index];
                    return _CurrencyTile(
                      item: item,
                      selected: item.selected,
                      isSaving: _controller.isSavingSelection && item.selected,
                      onTap: () => _selectCurrency(item.entry.code),
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

class _CurrencyRateStatus extends StatelessWidget {
  const _CurrencyRateStatus({required this.controller});

  final CurrencyController controller;

  @override
  Widget build(BuildContext context) {
    final List<CurrencyOptionViewModel> options = controller.options;
    final CurrencyOptionViewModel? selected = options
        .cast<CurrencyOptionViewModel?>()
        .firstWhere(
          (CurrencyOptionViewModel? option) => option?.selected ?? false,
          orElse: () => options.isEmpty ? null : options.first,
        );
    final String message = controller.isRefreshing
        ? 'Updating exchange rates...'
        : selected?.rate == null
        ? 'Exchange rates are currently unavailable'
        : selected!.rateLabel;

    return Row(
      children: <Widget>[
        if (controller.isRefreshing)
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(
            controller.isUsingCache
                ? Icons.cloud_off_outlined
                : Icons.currency_exchange_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Refresh exchange rates',
          onPressed: controller.isRefreshing
              ? null
              : () => unawaited(controller.refresh()),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        ),
      ],
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({
    required this.item,
    required this.selected,
    required this.isSaving,
    required this.onTap,
  });

  final CurrencyOptionViewModel item;
  final bool selected;
  final bool isSaving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('currency-option-${item.entry.code}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 66,
          padding: const EdgeInsets.all(13),
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
                child: _RoundFlag(flagCode: item.entry.flagCode, radius: 18),
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
                        child: isSaving
                            ? const Padding(
                                padding: EdgeInsets.all(4),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
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
