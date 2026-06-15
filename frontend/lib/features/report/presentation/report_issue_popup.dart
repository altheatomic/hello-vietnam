import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/report/data/report_repository.dart';

Future<void> showReportIssueFlow(BuildContext context) async {
  final bool? submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ReportIssueBottomSheet(),
  );

  if (submitted == true && context.mounted) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReportSuccessDialog(),
    );
  }
}

class _ReportIssueBottomSheet extends StatefulWidget {
  const _ReportIssueBottomSheet();

  @override
  State<_ReportIssueBottomSheet> createState() =>
      _ReportIssueBottomSheetState();
}

class _ReportIssueBottomSheetState extends State<_ReportIssueBottomSheet> {
  static const List<_IssueType> _issueTypes = <_IssueType>[
    _IssueType(
      label: 'Incorrect data',
      icon: Icons.error_outline_rounded,
      accentColor: Color(0xFFEF4444),
    ),
    _IssueType(
      label: 'Missing information',
      icon: Icons.assignment_late_outlined,
      accentColor: Color(0xFFF97316),
    ),
    _IssueType(
      label: 'Inappropriate image/video',
      icon: Icons.perm_media_outlined,
      accentColor: Color(0xFFA855F7),
    ),
    _IssueType(
      label: 'Map/address issue',
      icon: Icons.location_on_outlined,
      accentColor: Color(0xFF3B82F6),
    ),
    _IssueType(
      label: 'Other',
      icon: Icons.help_outline_rounded,
      accentColor: Color(0xFF111827),
    ),
  ];

  final TextEditingController _descriptionController = TextEditingController();
  final ReportRepository _repository = ReportRepository();
  _IssueType? _selectedIssue;
  bool _showIssueValidationError = false;
  int _issueValidationTick = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bool issueMissing = _selectedIssue == null;

    if (issueMissing) {
      _flashIssueSelectionValidation();
    }
    if (issueMissing) return;

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await _repository.submitReport(
        ReportSubmission(
          category: _categoryForIssue(_selectedIssue!),
          targetType: AppReportTargetType.feature,
          featureArea: 'detail_report',
          content: _descriptionController.text,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  AppReportCategory _categoryForIssue(_IssueType issue) {
    switch (issue.label) {
      case 'Incorrect data':
      case 'Missing information':
      case 'Inappropriate image/video':
        return AppReportCategory.contentReport;
      case 'Map/address issue':
        return AppReportCategory.bugReport;
      default:
        return AppReportCategory.suggestion;
    }
  }

  void _flashIssueSelectionValidation() {
    _issueValidationTick++;
    final int currentTick = _issueValidationTick;
    setState(() {
      _showIssueValidationError = true;
    });

    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted || currentTick != _issueValidationTick) return;
      setState(() {
        _showIssueValidationError = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final double bottomInset = media.viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bug_report_rounded,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.l10n.ui('Report an Issue'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1D293D),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.l10n.ui('Help us improve the app'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF90A1B9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(false),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _RequiredLabel(
                          title: context.l10n.ui('Issue type'),
                          showError: _showIssueValidationError,
                          errorText: context.l10n.ui('Please select one'),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints c) {
                            final double chipWidth = (c.maxWidth - 8) / 2;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _issueTypes.map((item) {
                                final bool selected = _selectedIssue == item;
                                return SizedBox(
                                  width: chipWidth,
                                  child: _IssueChip(
                                    item: item,
                                    selected: selected,
                                    highlightAsError:
                                        _showIssueValidationError &&
                                        _selectedIssue == null,
                                    onTap: () {
                                      setState(() {
                                        _selectedIssue = item;
                                        _showIssueValidationError = false;
                                        _issueValidationTick++;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        _SectionLabel(title: context.l10n.ui('Description')),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Column(
                            children: <Widget>[
                              TextField(
                                controller: _descriptionController,
                                maxLength: 500,
                                maxLines: 6,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: context.l10n.ui(
                                    'Please describe the issue you encountered so we can fix it as quickly as possible...',
                                  ),
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF90A1B9),
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                  border: InputBorder.none,
                                  counterText: '',
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${_descriptionController.text.length}/500',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF90A1B9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: Color(0xFF90A1B9),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                context.l10n.ui(
                                  'e.g. "When I tap the Save button on screen X, the app crashes"',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF90A1B9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            context.l10n.ui('Cancel'),
                            style: const TextStyle(
                              color: Color(0xFF45556C),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xFFEF4444),
                                Color(0xFFDC2626),
                              ],
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              _isSubmitting
                                  ? context.l10n.ui('Submitting...')
                                  : context.l10n.ui('Submit Report'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel({
    required this.title,
    this.showError = false,
    this.errorText,
  });

  final String title;
  final bool showError;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        RichText(
          text: TextSpan(
            text: title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF314158),
            ),
            children: const <TextSpan>[
              TextSpan(
                text: '*',
                style: TextStyle(
                  color: Color(0xFFFB2C36),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (showError && errorText != null) ...<Widget>[
          const SizedBox(width: 8),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF314158),
      ),
    );
  }
}

class _IssueChip extends StatelessWidget {
  const _IssueChip({
    required this.item,
    required this.selected,
    required this.onTap,
    this.highlightAsError = false,
  });

  final _IssueType item;
  final bool selected;
  final VoidCallback onTap;
  final bool highlightAsError;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      splashColor: item.accentColor.withValues(alpha: 0.10),
      highlightColor: item.accentColor.withValues(alpha: 0.06),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: selected ? 1 : 0.985,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: highlightAsError
                ? const Color(0xFFFFF5F5)
                : selected
                ? item.accentColor.withValues(alpha: 0.03)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlightAsError
                  ? const Color(0xFFEF4444)
                  : selected
                  ? item.accentColor
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: (selected && !highlightAsError)
                ? <BoxShadow>[
                    BoxShadow(
                      color: item.accentColor.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Row(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? item.accentColor.withValues(alpha: 0.10)
                      : Colors.transparent,
                ),
                child: Icon(item.icon, size: 16, color: item.accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected
                        ? item.accentColor
                        : const Color(0xFF45556C),
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                  child: Text(
                    context.l10n.ui(item.label),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportSuccessDialog extends StatefulWidget {
  const _ReportSuccessDialog();

  @override
  State<_ReportSuccessDialog> createState() => _ReportSuccessDialogState();
}

class _ReportSuccessDialogState extends State<_ReportSuccessDialog> {
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _closeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 352,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 60,
              offset: Offset(0, 20),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF81D4FA), Color(0xFF29B6F6)],
                ),
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                size: 42,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.ui('Report Submitted!'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D293D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.ui('Thank you for your feedback.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF62748E),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.ui(
                'Our team will review it and get back to you as soon as possible.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF62748E),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF81D4FA), Color(0xFF29B6F6)],
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x8081D4FA),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  context.l10n.ui('Done'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueType {
  const _IssueType({
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
}
