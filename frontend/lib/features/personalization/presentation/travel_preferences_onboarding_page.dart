import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/glass_card.dart';
import 'package:hellovietnam/features/personalization/data/travel_preferences_repository.dart';
import 'package:hellovietnam/features/personalization/domain/travel_preferences.dart';

class TravelPreferencesOnboardingPage extends StatefulWidget {
  const TravelPreferencesOnboardingPage({
    super.key,
    this.returnRoute = AppRoutes.home,
  });

  final String returnRoute;

  @override
  State<TravelPreferencesOnboardingPage> createState() =>
      _TravelPreferencesOnboardingPageState();
}

class _TravelPreferencesOnboardingPageState
    extends State<TravelPreferencesOnboardingPage> {
  late final PageController _pageController;
  int _currentStep = 0;
  bool _isSaving = false;

  final Set<TravelStyle> _selectedStyles = <TravelStyle>{};
  final Set<TravelCompanion> _selectedCompanions = <TravelCompanion>{};
  BudgetLevel? _selectedBudget;
  TravelPace? _selectedPace;
  final Set<InterestTopic> _selectedTopics = <InterestTopic>{};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    final UserTravelPreferences? existing =
        TravelPreferencesRepository.instance.currentPreferences;
    if (existing != null) {
      _selectedStyles.addAll(existing.travelStyles);
      _selectedCompanions.addAll(existing.companions);
      _selectedBudget = existing.budgetLevel;
      _selectedPace = existing.pace;
      _selectedTopics.addAll(existing.topics);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isEditing =>
      TravelPreferencesRepository.instance.hasCompletedCurrentUser;

  List<_StepConfig> get _steps => <_StepConfig>[
    _StepConfig(
      title: context.l10n.ui('What kind of trips feel most like you?'),
      subtitle: context.l10n.ui(
        'Choose a few directions so we can shape your first suggestions.',
      ),
      body: _TwoColumnChoiceGrid(
        children: TravelStyle.values
            .map(
              (TravelStyle style) => _LiquidChoiceChip(
                label: context.l10n.ui(style.label),
                subtitle: context.l10n.ui(style.subtitle),
                selected: _selectedStyles.contains(style),
                expandToCell: true,
                onTap: () {
                  setState(() {
                    if (_selectedStyles.contains(style)) {
                      _selectedStyles.remove(style);
                    } else {
                      _selectedStyles.add(style);
                    }
                  });
                },
              ),
            )
            .toList(growable: false),
      ),
      canContinue: _selectedStyles.length >= 2,
      helperText: context.l10n.ui('Pick at least 2 travel styles.'),
    ),
    _StepConfig(
      title: context.l10n.ui('Who do you usually travel with?'),
      subtitle: context.l10n.ui(
        'This helps us avoid suggestions that feel awkward or impractical.',
      ),
      body: _TwoColumnChoiceGrid(
        children: TravelCompanion.values
            .map(
              (TravelCompanion companion) => _LiquidChoiceChip(
                label: context.l10n.ui(companion.label),
                subtitle: context.l10n.ui(companion.subtitle),
                selected: _selectedCompanions.contains(companion),
                expandToCell: true,
                onTap: () {
                  setState(() {
                    if (_selectedCompanions.contains(companion)) {
                      _selectedCompanions.remove(companion);
                    } else {
                      _selectedCompanions.add(companion);
                    }
                  });
                },
              ),
            )
            .toList(growable: false),
      ),
      canContinue: _selectedCompanions.isNotEmpty,
      helperText: context.l10n.ui('Pick at least 1 companion style.'),
    ),
    _StepConfig(
      title: context.l10n.ui('What budget feels comfortable?'),
      subtitle: context.l10n.ui(
        'We will tune recommendations so the app feels realistic from day one.',
      ),
      body: Column(
        children: BudgetLevel.values
            .map(
              (BudgetLevel level) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LiquidRadioCard(
                  label: context.l10n.ui(level.label),
                  subtitle: context.l10n.ui(level.subtitle),
                  selected: _selectedBudget == level,
                  onTap: () => setState(() => _selectedBudget = level),
                ),
              ),
            )
            .toList(growable: false),
      ),
      canContinue: _selectedBudget != null,
      helperText: context.l10n.ui('Choose 1 budget level.'),
    ),
    _StepConfig(
      title: context.l10n.ui('How packed do you want your days to be?'),
      subtitle: context.l10n.ui(
        'This controls whether we suggest slow days, balanced plans, or busier lists.',
      ),
      body: Column(
        children: TravelPace.values
            .map(
              (TravelPace pace) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LiquidRadioCard(
                  label: context.l10n.ui(pace.label),
                  subtitle: context.l10n.ui(pace.subtitle),
                  selected: _selectedPace == pace,
                  onTap: () => setState(() => _selectedPace = pace),
                ),
              ),
            )
            .toList(growable: false),
      ),
      canContinue: _selectedPace != null,
      helperText: context.l10n.ui('Choose your preferred pace.'),
    ),
    _StepConfig(
      title: context.l10n.ui('Pick the things you want to see more often'),
      subtitle: context.l10n.ui(
        'This final step powers your Home and Explore suggestions right away.',
      ),
      body: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: InterestTopic.values
            .map(
              (InterestTopic topic) => _LiquidChoiceChip(
                label: context.l10n.ui(topic.label),
                selected: _selectedTopics.contains(topic),
                compact: true,
                onTap: () {
                  setState(() {
                    if (_selectedTopics.contains(topic)) {
                      _selectedTopics.remove(topic);
                    } else {
                      _selectedTopics.add(topic);
                    }
                  });
                },
              ),
            )
            .toList(growable: false),
      ),
      canContinue: _selectedTopics.length >= 3,
      helperText: context.l10n.ui('Pick at least 3 topics.'),
    ),
  ];

  Future<void> _goNext() async {
    if (_currentStep == _steps.length - 1) {
      await _save();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goBack() async {
    if (_currentStep == 0) {
      if (_isEditing) {
        context.go(widget.returnRoute);
      }
      return;
    }
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _save() async {
    if (_selectedBudget == null || _selectedPace == null) {
      return;
    }

    setState(() => _isSaving = true);
    final TravelPreferencesRepository repository =
        TravelPreferencesRepository.instance;
    final UserTravelPreferences preferences = UserTravelPreferences(
      travelStyles: _selectedStyles.toList(growable: false),
      companions: _selectedCompanions.toList(growable: false),
      budgetLevel: _selectedBudget!,
      pace: _selectedPace!,
      topics: _selectedTopics.toList(growable: false),
      completedAt: DateTime.now(),
    );

    await repository.saveCurrentUserPreferences(preferences, notify: false);

    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);
    context.go(widget.returnRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      repository.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final int safeStepIndex = _currentStep.clamp(0, _steps.length - 1);
    final _StepConfig currentStep = _steps[safeStepIndex];

    return PopScope(
      canPop: _isEditing,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2FAFF),
        body: Stack(
          children: <Widget>[
            const Positioned.fill(child: _LiquidBackground()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: Column(
                  children: <Widget>[
                    _TopBar(
                      step: safeStepIndex + 1,
                      totalSteps: _steps.length,
                      isEditing: _isEditing,
                      onBack: _goBack,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _steps.length,
                        itemBuilder: (BuildContext context, int index) {
                          final _StepConfig step = _steps[index];
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.only(
                              bottom: media.padding.bottom + 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        step.title,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF16314D),
                                          height: 1.08,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        step.subtitle,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.45,
                                          color: Color(0xFF5F7085),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 22),
                                GlassCard(
                                  borderRadius: 30,
                                  blur: 18,
                                  opacity: 0.38,
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    18,
                                    18,
                                    18,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.64),
                                  ),
                                  child: step.body,
                                ),
                                const SizedBox(height: 18),
                                if (index == _steps.length - 1)
                                  _SelectionSummary(
                                    selectedStyles: _selectedStyles.toList(),
                                    selectedTopics: _selectedTopics.toList(),
                                  ),
                              ],
                            ),
                          );
                        },
                        onPageChanged: (int index) {
                          if (mounted) {
                            setState(() => _currentStep = index);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ProgressDots(
                      currentStep: safeStepIndex,
                      totalSteps: _steps.length,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _GlassActionButton(
                            label: safeStepIndex == 0
                                ? (_isEditing
                                      ? context.l10n.ui('Cancel')
                                      : context.l10n.ui('Back later'))
                                : context.l10n.ui('Back'),
                            onTap: _goBack,
                            isPrimary: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _GlassActionButton(
                            label: safeStepIndex == _steps.length - 1
                                ? (_isSaving
                                      ? context.l10n.ui('Saving...')
                                      : context.l10n.ui('Finish'))
                                : context.l10n.ui('Continue'),
                            onTap: currentStep.canContinue && !_isSaving
                                ? _goNext
                                : null,
                            isPrimary: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      currentStep.helperText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: currentStep.canContinue
                            ? const Color(0xFF7B8CA0)
                            : const Color(0xFF6EAEE5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.step,
    required this.totalSteps,
    required this.isEditing,
    required this.onBack,
  });

  final int step;
  final int totalSteps;
  final bool isEditing;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              shape: BoxShape.circle,
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1E183B60),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              isEditing || step > 1 ? Icons.arrow_back_rounded : Icons.close,
              color: const Color(0xFF60748A),
            ),
          ),
        ),
        const Spacer(),
        Text(
          context.l10n.ui('Your Travel Taste'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$step/$totalSteps',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF60748A),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.selectedStyles,
    required this.selectedTopics,
  });

  final List<TravelStyle> selectedStyles;
  final List<InterestTopic> selectedTopics;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 26,
      blur: 14,
      opacity: 0.28,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.ui('You are telling us to prioritize'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B3957),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                <String>[
                      ...selectedStyles.map(
                        (TravelStyle style) => context.l10n.ui(style.label),
                      ),
                      ...selectedTopics
                          .take(4)
                          .map(
                            (InterestTopic topic) =>
                                context.l10n.ui(topic.label),
                          ),
                    ]
                    .map(
                      (String label) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF60748A),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _TwoColumnChoiceGrid extends StatelessWidget {
  const _TwoColumnChoiceGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool singleColumn = constraints.maxWidth < 360;
        final double spacing = 12;
        final double itemWidth = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((Widget child) => SizedBox(width: itemWidth, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(totalSteps, (int index) {
        final bool isActive = index == currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2DB9F8) : const Color(0xFFB9DAF3),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  const _GlassActionButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.52,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: <Color>[Color(0xFF16C6EE), Color(0xFF5D95F7)],
                  )
                : null,
            color: isPrimary ? null : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x240B2843),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isPrimary ? Colors.white : const Color(0xFF5C7085),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidChoiceChip extends StatefulWidget {
  const _LiquidChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.compact = false,
    this.expandToCell = false,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final bool expandToCell;

  @override
  State<_LiquidChoiceChip> createState() => _LiquidChoiceChipState();
}

class _LiquidChoiceChipState extends State<_LiquidChoiceChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
    _controller
      ..stop()
      ..forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final double width = widget.expandToCell
        ? double.infinity
        : (widget.compact ? 154 : 166);

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: widget.selected ? 0.985 : 1,
        curve: Curves.easeOut,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                final double value = Curves.easeOut.transform(
                  _controller.value,
                );
                return Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (1 - value) * 0.28,
                      child: Transform.scale(
                        scale: 0.8 + (value * 0.55),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const RadialGradient(
                              colors: <Color>[
                                Color(0x6624D8FF),
                                Color(0x0024D8FF),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: width,
              padding: EdgeInsets.fromLTRB(
                16,
                widget.compact ? 14 : 16,
                16,
                widget.compact ? 14 : 16,
              ),
              decoration: BoxDecoration(
                color: widget.selected
                    ? Colors.white.withValues(alpha: 0.78)
                    : Colors.white.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: widget.selected
                      ? const Color(0xFF77DEFF)
                      : Colors.white.withValues(alpha: 0.74),
                  width: widget.selected ? 1.6 : 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: widget.selected
                        ? const Color(0x3317BFEF)
                        : const Color(0x180B2843),
                    blurRadius: widget.selected ? 22 : 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: widget.compact ? 14 : 15,
                      fontWeight: FontWeight.w800,
                      color: widget.selected
                          ? const Color(0xFF1299D6)
                          : const Color(0xFF1F344C),
                    ),
                  ),
                  if (widget.subtitle != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Color(0xFF6B7D92),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.selected)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF23C7F0),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x3324D8FF),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiquidRadioCard extends StatelessWidget {
  const _LiquidRadioCard({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.click);
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.82)
              : Colors.white.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? const Color(0xFF72D9FF)
                : Colors.white.withValues(alpha: 0.66),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: selected
                  ? const Color(0x3024D8FF)
                  : const Color(0x150B2843),
              blurRadius: selected ? 20 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1EC5EF)
                      : const Color(0xFF9DB2C7),
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: selected ? 10 : 0,
                  height: selected ? 10 : 0,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1EC5EF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17304A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Color(0xFF6D7E92),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidBackground extends StatelessWidget {
  const _LiquidBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFF3FAFF),
            Color(0xFFE1F8FF),
            Color(0xFFF8FFFE),
          ],
        ),
      ),
      child: Stack(
        children: const <Widget>[
          Positioned(
            top: -80,
            right: -36,
            child: _Orb(size: 220, color: Color(0x4A6DD8FF)),
          ),
          Positioned(
            top: 260,
            left: -64,
            child: _Orb(size: 180, color: Color(0x3A34D8FF)),
          ),
          Positioned(
            bottom: 100,
            right: -44,
            child: _Orb(size: 200, color: Color(0x4065E7D8)),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color,
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.02),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepConfig {
  const _StepConfig({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.canContinue,
    required this.helperText,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final bool canContinue;
  final String helperText;
}
