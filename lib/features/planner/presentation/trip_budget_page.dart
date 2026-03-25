import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
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

  bool get _canGenerate =>
      _budgetController.text.trim().isNotEmpty || _selectedRange != null;

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
      title: 'What is your daily budget?',
      subtitle: 'Enter the amount you would like to spend',
      onBack: () => context.pop(),
      nextEnabled: _canGenerate,
      nextLabel: 'Generate',
      onNext: _showGeneratePlaceholder,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _BudgetInputField(controller: _budgetController),
            const SizedBox(height: 28),
            const Text(
              'Which price range you would prefer?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF162235),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'We will choose the destinations satisfy your price range',
              style: TextStyle(
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
                  label: range,
                  selected: selected,
                  onTap: () => _selectRange(range),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _BudgetInputField extends StatelessWidget {
  const _BudgetInputField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC4F4FF), width: 1.6),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x260F2C4F),
            blurRadius: 28,
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
        decoration: const InputDecoration(
          hintText: 'e.g. 10,000,000 VND',
          hintStyle: TextStyle(
            fontSize: 15.5,
            color: Color(0xFF9AA3B2),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        ),
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
