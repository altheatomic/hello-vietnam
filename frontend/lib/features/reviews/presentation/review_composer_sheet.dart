import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/reviews/domain/review_models.dart';

typedef ReviewComposerSubmit =
    Future<UpsertReviewResult> Function({
      required int rating,
      required String comment,
    });

class ReviewComposerSheet extends StatefulWidget {
  const ReviewComposerSheet({
    super.key,
    required this.itemTitle,
    required this.onSubmit,
    this.initialReview,
    this.submitLabel = 'Save review',
  });

  final String itemTitle;
  final ReviewComposerSubmit onSubmit;
  final ReviewEntry? initialReview;
  final String submitLabel;

  @override
  State<ReviewComposerSheet> createState() => _ReviewComposerSheetState();
}

class _ReviewComposerSheetState extends State<ReviewComposerSheet> {
  late final TextEditingController _controller;
  late int _selectedRating;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialReview?.comment ?? '');
    _selectedRating = widget.initialReview?.rating ?? 5;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String comment = _controller.text.trim();
    if (_isSubmitting || comment.isEmpty) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final UpsertReviewResult result = await widget.onSubmit(
        rating: _selectedRating,
        comment: comment,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      final String message = error.toString().trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty ? 'Could not publish your review.' : message,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final EdgeInsets viewInsets = MediaQuery.of(context).viewInsets;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.initialReview == null ? 'Write a review' : 'Edit your review',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.itemTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              children: List<Widget>.generate(5, (int index) {
                final int star = index + 1;
                final bool selected = star <= _selectedRating;
                return InkWell(
                  onTap: () => setState(() => _selectedRating = star),
                  borderRadius: BorderRadius.circular(999),
                  child: Icon(
                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.starColor,
                    size: 30,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 5,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: 'Share what stood out for you...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(_isSubmitting ? 'Saving...' : widget.submitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
