import 'package:flutter/material.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/data_freshness/data/content_freshness_repository.dart';
import 'package:hellovietnam/features/data_freshness/domain/content_freshness_models.dart';

Future<void> showContentReportSheet(
  BuildContext context, {
  required FreshnessContentType contentType,
  required String contentId,
  required String contentName,
  ContentFreshnessRepository? repository,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: ContentReportSheet(
        contentType: contentType,
        contentId: contentId,
        contentName: contentName,
        repository: repository,
      ),
    ),
  );
}

class ContentReportSheet extends StatefulWidget {
  const ContentReportSheet({
    super.key,
    required this.contentType,
    required this.contentId,
    required this.contentName,
    this.repository,
  });

  final FreshnessContentType contentType;
  final String contentId;
  final String contentName;
  final ContentFreshnessRepository? repository;

  @override
  State<ContentReportSheet> createState() => _ContentReportSheetState();
}

class _ContentReportSheetState extends State<ContentReportSheet> {
  ContentReportReason? _selectedReason;
  final TextEditingController _noteController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (_submitted) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.ui(
                  'Thanks for helping keep this information accurate.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.ui('Close')),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              context.l10n.ui('Report incorrect information'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(widget.contentName, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            RadioGroup<ContentReportReason>(
              groupValue: _selectedReason,
              onChanged: (ContentReportReason? value) {
                if (_submitting) return;
                setState(() {
                  _selectedReason = value;
                  _error = null;
                });
              },
              child: Column(
                children: ContentReportReason.values
                    .map(
                      (ContentReportReason reason) =>
                          RadioListTile<ContentReportReason>(
                            value: reason,
                            enabled: !_submitting,
                            contentPadding: EdgeInsets.zero,
                            title: Text(_reasonLabel(reason)),
                          ),
                    )
                    .toList(growable: false),
              ),
            ),
            TextField(
              controller: _noteController,
              enabled: !_submitting,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.ui('Optional note'),
                hintText: context.l10n.ui('Tell us what is incorrect'),
              ),
            ),
            if (_error != null) ...<Widget>[
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.ui('Submit')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final ContentReportReason? reason = _selectedReason;
    if (reason == null) {
      setState(() => _error = context.l10n.ui('Please choose a reason.'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await (widget.repository ?? ContentFreshnessRepository()).submitReport(
        contentType: widget.contentType,
        contentId: widget.contentId,
        reason: reason,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } on ContentFreshnessException catch (error) {
      if (!mounted) return;
      final String message = switch (error.code) {
        'duplicate_report' => context.l10n.ui(
          'You already reported this information.',
        ),
        'report_rate_limited' => context.l10n.ui('Daily report limit reached.'),
        _ => error.message,
      };
      setState(() {
        _submitting = false;
        _error = message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '$error';
      });
    }
  }

  String _reasonLabel(ContentReportReason reason) {
    return switch (reason) {
      ContentReportReason.closed => context.l10n.ui('This place is closed'),
      ContentReportReason.wrongHours => context.l10n.ui('Wrong opening hours'),
      ContentReportReason.wrongLocation => context.l10n.ui('Wrong location'),
      ContentReportReason.eventEnded => context.l10n.ui('Event has ended'),
      ContentReportReason.other => context.l10n.ui('Other'),
    };
  }
}
