import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/report/data/report_repository.dart';
import 'package:image_picker/image_picker.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const List<_IssueType> _issueTypes = <_IssueType>[
    _IssueType(
      label: 'Home',
      featureArea: 'home',
      category: AppReportCategory.bugReport,
      icon: Icons.home_outlined,
      color: Color(0xFF0EA5E9),
    ),
    _IssueType(
      label: 'Explore',
      featureArea: 'explore',
      category: AppReportCategory.bugReport,
      icon: Icons.explore_outlined,
      color: Color(0xFF22C55E),
    ),
    _IssueType(
      label: 'City and place details',
      featureArea: 'details',
      category: AppReportCategory.contentReport,
      icon: Icons.place_outlined,
      color: Color(0xFF3B82F6),
    ),
    _IssueType(
      label: 'Trip Planner',
      featureArea: 'trip_planner',
      category: AppReportCategory.bugReport,
      icon: Icons.luggage_outlined,
      color: Color(0xFFF97316),
    ),
    _IssueType(
      label: 'Saved Trips',
      featureArea: 'saved_trips',
      category: AppReportCategory.bugReport,
      icon: Icons.bookmark_border_rounded,
      color: Color(0xFF14B8A6),
    ),
    _IssueType(
      label: 'Forum',
      featureArea: 'forum',
      category: AppReportCategory.bugReport,
      icon: Icons.forum_outlined,
      color: Color(0xFF8B5CF6),
    ),
    _IssueType(
      label: 'Messages',
      featureArea: 'messages',
      category: AppReportCategory.bugReport,
      icon: Icons.chat_bubble_outline_rounded,
      color: Color(0xFF06B6D4),
    ),
    _IssueType(
      label: 'Translate',
      featureArea: 'translate',
      category: AppReportCategory.bugReport,
      icon: Icons.translate_outlined,
      color: Color(0xFF6366F1),
    ),
    _IssueType(
      label: 'Recommend',
      featureArea: 'recommend',
      category: AppReportCategory.bugReport,
      icon: Icons.recommend_outlined,
      color: Color(0xFFEC4899),
    ),
    _IssueType(
      label: 'Popular Apps',
      featureArea: 'popular_apps',
      category: AppReportCategory.bugReport,
      icon: Icons.apps_outlined,
      color: Color(0xFF10B981),
    ),
    _IssueType(
      label: 'AI Search',
      featureArea: 'ai_search',
      category: AppReportCategory.bugReport,
      icon: Icons.auto_awesome_outlined,
      color: Color(0xFFA855F7),
    ),
    _IssueType(
      label: 'Wishlist',
      featureArea: 'wishlist',
      category: AppReportCategory.bugReport,
      icon: Icons.favorite_border_rounded,
      color: Color(0xFFFF5E7A),
    ),
    _IssueType(
      label: 'Voucher',
      featureArea: 'voucher',
      category: AppReportCategory.paymentIssue,
      icon: Icons.confirmation_number_outlined,
      color: Color(0xFFEAB308),
    ),
    _IssueType(
      label: 'Notifications',
      featureArea: 'notifications',
      category: AppReportCategory.bugReport,
      icon: Icons.notifications_none_rounded,
      color: Color(0xFFEF4444),
    ),
    _IssueType(
      label: 'Profile and account',
      featureArea: 'profile_account',
      category: AppReportCategory.accountIssue,
      icon: Icons.person_outline_rounded,
      color: Color(0xFF64748B),
    ),
    _IssueType(
      label: 'Other',
      featureArea: 'other',
      category: AppReportCategory.suggestion,
      icon: Icons.help_outline_rounded,
      color: Color(0xFF111827),
    ),
  ];

  final ReportRepository _repository = ReportRepository();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();
  final List<XFile> _images = <XFile>[];

  _IssueType? _selectedIssue;
  bool _showIssueValidationError = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> files = await _picker.pickMultiImage(imageQuality: 82);
      if (!mounted || files.isEmpty) return;
      setState(() {
        _images
          ..clear()
          ..addAll(files.take(4));
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack(error.toString());
    }
  }

  Future<void> _submitReport() async {
    final _IssueType? issue = _selectedIssue;
    if (issue == null) {
      setState(() => _showIssueValidationError = true);
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await _repository.submitReport(
        ReportSubmission(
          category: issue.category,
          targetType: AppReportTargetType.feature,
          featureArea: issue.featureArea,
          content: _descriptionController.text,
          images: <Map<String, dynamic>>[
            for (final XFile image in _images)
              <String, dynamic>{
                'name': image.name,
                'path': image.path,
                'mimeType': image.mimeType,
              },
          ],
        ),
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SuccessDialog(
          onClose: () {
            if (mounted) context.go(AppRoutes.home);
          },
        ),
      );
    } catch (error) {
      if (mounted) _showSnack(error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: const Color(0xFF1D293D),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.ui('Report an Issue'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D293D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.ui('Help us improve the app'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF90A1B9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  24 + mq.padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _RequiredLabel(
                      title: context.l10n.ui('Feature with issue'),
                      showError: _showIssueValidationError,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints c) {
                        final double chipWidth = (c.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            for (final _IssueType issue in _issueTypes)
                              SizedBox(
                                width: issue.label == 'Other'
                                    ? chipWidth
                                    : chipWidth,
                                child: _IssueChip(
                                  issue: issue,
                                  selected: _selectedIssue == issue,
                                  showError:
                                      _showIssueValidationError &&
                                      _selectedIssue == null,
                                  onTap: () => setState(() {
                                    _selectedIssue = issue;
                                    _showIssueValidationError = false;
                                  }),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 26),
                    _SectionLabel(context.l10n.ui('Description')),
                    const SizedBox(height: 10),
                    _DescriptionBox(controller: _descriptionController),
                    const SizedBox(height: 18),
                    _SectionLabel(context.l10n.ui('Image or video')),
                    const SizedBox(height: 10),
                    _UploadBox(
                      images: _images,
                      onPick: _pickImages,
                      onRemove: (int index) => setState(() {
                        _images.removeAt(index);
                      }),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => context.pop(),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
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
                                colors: <Color>[
                                  Color(0xFFEF4444),
                                  Color(0xFFDC2626),
                                ],
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitReport,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                minimumSize: const Size.fromHeight(50),
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
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel({required this.title, required this.showError});

  final String title;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        RichText(
          text: TextSpan(
            text: title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF314158),
            ),
            children: const <TextSpan>[
              TextSpan(
                text: '*',
                style: TextStyle(color: Color(0xFFFB2C36)),
              ),
            ],
          ),
        ),
        if (showError) ...<Widget>[
          const SizedBox(width: 8),
          Text(
            context.l10n.ui('Please select one'),
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF314158),
      ),
    );
  }
}

class _IssueChip extends StatelessWidget {
  const _IssueChip({
    required this.issue,
    required this.selected,
    required this.showError,
    required this.onTap,
  });

  final _IssueType issue;
  final bool selected;
  final bool showError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? issue.color.withValues(alpha: 0.05)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: showError
                ? const Color(0xFFEF4444)
                : selected
                ? issue.color
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(issue.icon, size: 20, color: issue.color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.ui(issue.label),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? issue.color : const Color(0xFF45556C),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionBox extends StatefulWidget {
  const _DescriptionBox({required this.controller});

  final TextEditingController controller;

  @override
  State<_DescriptionBox> createState() => _DescriptionBoxState();
}

class _DescriptionBoxState extends State<_DescriptionBox> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        children: <Widget>[
          TextField(
            controller: widget.controller,
            maxLength: 500,
            maxLines: 7,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: context.l10n.ui(
                'Please describe the issue you encountered so we can fix it as quickly as possible...',
              ),
              hintStyle: const TextStyle(
                color: Color(0xFF90A1B9),
                fontSize: 16,
                height: 1.5,
              ),
              border: InputBorder.none,
              counterText: '',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${widget.controller.text.length}/500',
              style: const TextStyle(fontSize: 12, color: Color(0xFF90A1B9)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  const _UploadBox({
    required this.images,
    required this.onPick,
    required this.onRemove,
  });

  final List<XFile> images;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPick,
        child: Container(
          height: 118,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.add_photo_alternate_outlined,
                color: Color(0xFF3B82F6),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.ui('Upload image or video'),
                style: const TextStyle(color: Color(0xFF90A1B9)),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          if (index == images.length) {
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onPick,
              child: Container(
                width: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.add, color: Color(0xFF3B82F6)),
              ),
            );
          }

          return Stack(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: _PickedImagePreview(file: images[index]),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PickedImagePreview extends StatelessWidget {
  const _PickedImagePreview({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        final Uint8List? bytes = snapshot.data;
        if (bytes == null) {
          return const ColoredBox(color: Color(0xFFEAF4F8));
        }
        return Image.memory(bytes, fit: BoxFit.cover);
      },
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.ui('Report Submitted!')),
      content: Text(
        context.l10n.ui(
          'Thank you for your report. Our team will review it as soon as possible.',
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onClose();
          },
          child: Text(context.l10n.ui('Done')),
        ),
      ],
    );
  }
}

class _IssueType {
  const _IssueType({
    required this.label,
    required this.featureArea,
    required this.category,
    required this.icon,
    required this.color,
  });

  final String label;
  final String featureArea;
  final AppReportCategory category;
  final IconData icon;
  final Color color;
}
