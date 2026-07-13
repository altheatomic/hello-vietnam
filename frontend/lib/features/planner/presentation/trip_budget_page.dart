import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';

class TripBudgetPage extends StatefulWidget {
  const TripBudgetPage({super.key});

  @override
  State<TripBudgetPage> createState() => _TripBudgetPageState();
}

class _TripBudgetPageState extends State<TripBudgetPage> {
  static const List<String> _priceRanges = <String>[
    'Affordable',
    'Standard',
    'Premium',
  ];

  final TextEditingController _budgetController = TextEditingController();
  String? _selectedRange;
  bool _isFormatting = false;

  bool get _hasTypedBudget => _budgetController.text.trim().isNotEmpty;
  bool get _canGenerate => _hasTypedBudget || _selectedRange != null;

  @override
  void initState() {
    super.initState();
    _budgetController.addListener(_handleBudgetChanged);
  }

  @override
  void dispose() {
    _budgetController
      ..removeListener(_handleBudgetChanged)
      ..dispose();
    super.dispose();
  }

  void _handleBudgetChanged() {
    if (_isFormatting) return;

    final String digits = _budgetController.text.replaceAll(RegExp(r'\D'), '');
    final String formatted = _formatVndDigits(digits);

    _isFormatting = true;
    _budgetController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isFormatting = false;

    if (formatted.isNotEmpty && _selectedRange != null) {
      setState(() {
        _selectedRange = null;
      });
      return;
    }

    setState(() {});
  }

  void _selectRange(String range) {
    setState(() {
      _selectedRange = range;
      _budgetController.clear();
    });
  }

  void _showGeneratePlaceholder() {
    context.push(AppRoutes.tripPlannerResult);
  }

  String _formatVndDigits(String digits) {
    if (digits.isEmpty) return '';

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final int positionFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$buffer VND';
  }

  @override
  Widget build(BuildContext context) {
    return PlannerStepScaffold(
      currentStep: 5,
      badgeIcon: Icons.account_balance_wallet_outlined,
      title: context.l10n.ui('Choose your budget'),
      subtitle: context.l10n.ui('Pick one option below to continue'),
      onBack: () => context.pop(),
      nextEnabled: _canGenerate,
      nextLabel: context.l10n.ui('Generate'),
      onNext: _showGeneratePlaceholder,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.ui('Option 1: Enter daily budget'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF162235),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.ui(
              'Use an exact amount per day if you already know your spending limit.',
            ),
            style: const TextStyle(
              fontSize: 14.5,
              fontStyle: FontStyle.italic,
              color: Color(0xFF6F7B8A),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _BudgetInputField(
            controller: _budgetController,
            selected: _hasTypedBudget,
          ),
          if (_hasTypedBudget) ...<Widget>[
            const SizedBox(height: 10),
            _SelectedBudgetHint(
              label: context.l10n.ui(
                'Using exact daily budget. Price range will be ignored.',
              ),
            ),
          ],
          const SizedBox(height: 24),
          const _OptionDivider(),
          const SizedBox(height: 24),
          Text(
            context.l10n.ui('Option 2: Choose price range'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF162235),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.ui(
              'Use a quick preset instead of typing an exact amount.',
            ),
            style: const TextStyle(
              fontSize: 14.5,
              fontStyle: FontStyle.italic,
              color: Color(0xFF6F7B8A),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          ..._priceRanges.map((String range) {
            final bool selected = _selectedRange == range;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _BudgetRangeCard(
                label: context.l10n.ui(range),
                selected: selected,
                onTap: () => _selectRange(range),
              ),
            );
          }),
          if (_selectedRange != null)
            _SelectedBudgetHint(
              label: context.l10n.ui(
                'Using price range. Typed daily budget will be ignored.',
              ),
            ),
        ],
      ),
    );
  }
}

class _BudgetInputField extends StatelessWidget {
  const _BudgetInputField({required this.controller, required this.selected});

  final TextEditingController controller;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? const Color(0xFF22B7F1) : const Color(0xFFC4F4FF),
          width: selected ? 2 : 1.6,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: selected ? const Color(0x2222B7F1) : const Color(0x260F2C4F),
            blurRadius: selected ? 24 : 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9, ]')),
        ],
        style: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          color: Color(0xFF162235),
        ),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.payments_outlined,
            color: Color(0xFF9AA3B2),
            size: 22,
          ),
          hintText: context.l10n.ui('e.g. 800,000 VND per day'),
          hintStyle: const TextStyle(
            fontSize: 15.5,
            color: Color(0xFF9AA3B2),
            fontWeight: FontWeight.w500,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: controller.clear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF9AA3B2),
                    size: 20,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

class _OptionDivider extends StatelessWidget {
  const _OptionDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Divider(color: Color(0xFFD8EAF3), thickness: 1.2),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            context.l10n.ui('OR'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8A95A5),
              letterSpacing: 1.1,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: Color(0xFFD8EAF3), thickness: 1.2),
        ),
      ],
    );
  }
}

class _SelectedBudgetHint extends StatelessWidget {
  const _SelectedBudgetHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBEFFF)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: Color(0xFF22B7F1),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4F6072),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetRangeCard extends StatelessWidget {
  const _BudgetRangeCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: selected ? 0.98 : 0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFF22B7F1)
                  : const Color(0xFFC4F4FF),
              width: selected ? 2 : 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: selected
                    ? const Color(0x2222B7F1)
                    : const Color(0x260F2C4F),
                blurRadius: selected ? 24 : 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF22B7F1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
