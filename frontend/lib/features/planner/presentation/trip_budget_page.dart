import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/core/widgets/journey_loading/vietnam_journey_loading_screen.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_request.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';
import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';

class TripBudgetPage extends StatefulWidget {
  const TripBudgetPage({super.key, this.wizard, this.generateTrip});

  final TripWizardData? wizard;
  final Future<TripPlanResponse> Function(TripPlanRequest request)?
  generateTrip;

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
  bool _isLoading = false;
  bool _transitionFinished = false;
  TripPlanResponse? _pendingResponse;
  int _generation = 0;

  bool get _hasTypedBudget => _budgetController.text.trim().isNotEmpty;
  bool get _canGenerate =>
      !_isLoading && (_hasTypedBudget || _selectedRange != null);

  @override
  void initState() {
    super.initState();
    _budgetController.addListener(_handleBudgetChanged);
  }

  @override
  void didUpdateWidget(covariant TripBudgetPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameWizardData(oldWidget.wizard, widget.wizard) && _isLoading) {
      _generation++;
      _isLoading = false;
      _transitionFinished = false;
      _pendingResponse = null;
    }
  }

  @override
  void dispose() {
    _generation++;
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

  Future<void> _generate() async {
    if (_isLoading) return;

    final wizard = widget.wizard;
    final idProvince = wizard?.idProvince;
    final nDays = wizard?.nDays;
    final tripType = wizard?.tripType;
    final isBusinessTrip = tripType == 'business';

    if (nDays == null) {
      _showError('Missing trip details. Please start from the beginning.');
      return;
    }
    if (isBusinessTrip) {
      if (wizard?.targetLat == null || wizard?.targetLng == null) {
        _showError(
          'Missing business location. Please go back and enter an address.',
        );
        return;
      }
    } else {
      if (idProvince == null) {
        _showError('Missing trip details. Please start from the beginning.');
        return;
      }
    }

    final request = TripPlanRequest(
      idProvince: isBusinessTrip ? null : idProvince,
      nDays: nDays,
      startDate: wizard?.startDate,
      targetLat: isBusinessTrip ? wizard?.targetLat : null,
      targetLng: isBusinessTrip ? wizard?.targetLng : null,
    );
    final int generation = ++_generation;
    setState(() {
      _isLoading = true;
      _transitionFinished = false;
      _pendingResponse = null;
    });

    try {
      final response =
          await (widget.generateTrip?.call(request) ??
              TripRepository().planTrip(request));
      if (!mounted || generation != _generation) return;
      setState(() => _pendingResponse = response);
    } on NoTripCandidatesException {
      if (!mounted) return;
      _failGeneration(
        generation,
        'Not enough places found for your selection. Try selecting more '
        'interests (step 4) or fewer days (step 3).',
      );
    } on SupabaseFunctionException catch (e) {
      if (!mounted) return;
      if (e.errorCode == 'no_candidates') {
        _failGeneration(
          generation,
          'Not enough places found for your selection. Try selecting more '
          'interests (step 4) or fewer days (step 3).',
        );
      } else {
        _failGeneration(
          generation,
          'Could not generate your trip. Please try again.',
        );
      }
    } catch (e) {
      _failGeneration(
        generation,
        'Could not generate your trip. Please try again.',
      );
    }
  }

  void _failGeneration(int generation, String message) {
    if (!mounted || generation != _generation) return;
    setState(() {
      _isLoading = false;
      _transitionFinished = false;
      _pendingResponse = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation || _isLoading) return;
      _showError(message);
    });
  }

  void _finishGenerationTransition() {
    final response = _pendingResponse;
    if (!mounted || !_isLoading || response == null || _transitionFinished) {
      return;
    }

    _transitionFinished = true;
    setState(() {
      _isLoading = false;
      _pendingResponse = null;
    });

    final String? idPlan = response.idPlan?.trim();
    if (idPlan != null && idPlan.isNotEmpty) {
      context.push(AppRoutes.tripPlannerResultPath(idPlan: idPlan));
    } else {
      context.push(AppRoutes.tripPlannerResultPath(), extra: response);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
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
    if (_isLoading) {
      return VietnamJourneyLoadingScreen(
        message: context.l10n.ui('Generating your personalised itinerary…'),
        isComplete: _pendingResponse != null,
        onExitComplete: _finishGenerationTransition,
      );
    }

    return PlannerStepScaffold(
      currentStep: 5,
      badgeIcon: Icons.account_balance_wallet_outlined,
      title: 'Choose your budget',
      subtitle: 'Pick one option below to continue',
      onBack: () => context.pop(),
      nextEnabled: _canGenerate,
      nextLabel: 'Generate',
      onNext: _generate,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.ui('Option 1: Enter daily budget'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.ui(
                'Use an exact amount per day if you already know your spending limit.',
              ),
              style: TextStyle(
                fontSize: 14.5,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                label: 'Using exact daily budget. Price range will be ignored.',
              ),
            ],
            const SizedBox(height: 24),
            const _OptionDivider(),
            const SizedBox(height: 24),
            Text(
              context.l10n.ui('Option 2: Choose price range'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.ui(
                'Use a quick preset instead of typing an exact amount.',
              ),
              style: TextStyle(
                fontSize: 14.5,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                label: 'Using price range. Typed daily budget will be ignored.',
              ),
          ],
        ),
      ),
    );
  }
}

bool _sameWizardData(TripWizardData? first, TripWizardData? second) {
  if (identical(first, second)) return true;
  if (first == null || second == null) return false;
  return first.idProvince == second.idProvince &&
      first.provinceName == second.provinceName &&
      first.startDate == second.startDate &&
      first.nDays == second.nDays &&
      first.tripType == second.tripType &&
      first.targetLat == second.targetLat &&
      first.targetLng == second.targetLng &&
      first.businessAddress == second.businessAddress;
}

class _BudgetInputField extends StatelessWidget {
  const _BudgetInputField({required this.controller, required this.selected});

  final TextEditingController controller;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? const Color(0xFF22B7F1) : const Color(0xFFC4F4FF),
          width: selected ? 2 : 1.6,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: selected ? const Color(0x2222B7F1) : const Color(0x260F2C4F),
            blurRadius: selected ? 24 : 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9, ]')),
        ],
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : const Color(0xFFF2FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? theme.colorScheme.outline : const Color(0xFFCBEFFF),
        ),
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
              context.l10n.ui(label),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
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
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: selected ? 0.98 : 0.95),
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
              style: TextStyle(
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
