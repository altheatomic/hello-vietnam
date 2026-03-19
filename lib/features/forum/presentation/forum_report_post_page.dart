import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/glass_card.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';

class ForumReportPostPage extends StatefulWidget {
  const ForumReportPostPage({super.key, required this.postId});

  final String postId;

  @override
  State<ForumReportPostPage> createState() => _ForumReportPostPageState();
}

class _ForumReportPostPageState extends State<ForumReportPostPage> {
  final ForumStore _store = ForumStore.instance;
  final TextEditingController _detailsController = TextEditingController();
  _ReportReasonOption? _selectedReason;

  static const List<_ReportReasonOption> _reasonOptions = <_ReportReasonOption>[
    _ReportReasonOption(
      id: 'spam',
      title: 'Spam',
      subtitle: 'Repetitive or misleading content',
      icon: Icons.chat_bubble_outline_rounded,
    ),
    _ReportReasonOption(
      id: 'harassment',
      title: 'Harassment or hate speech',
      subtitle: 'Abusive or threatening content',
      icon: Icons.warning_amber_rounded,
    ),
    _ReportReasonOption(
      id: 'inappropriate',
      title: 'Inappropriate content',
      subtitle: 'Sensitive or adult content',
      icon: Icons.remove_red_eye_outlined,
    ),
    _ReportReasonOption(
      id: 'false-information',
      title: 'False information',
      subtitle: 'Misleading or fake news',
      icon: Icons.assignment_late_outlined,
    ),
    _ReportReasonOption(
      id: 'violence',
      title: 'Violence or dangerous content',
      subtitle: 'Content promoting harm',
      icon: Icons.block_outlined,
    ),
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submitReport(ForumPost post) {
    final _ReportReasonOption? reason = _selectedReason;
    if (reason == null) {
      return;
    }

    _store.submitReport(
      postId: post.id,
      reason: reason.title,
      details: _detailsController.text.trim(),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Report submitted. We will review it anonymously.'),
        ),
      );

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ForumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ListenableBuilder(
          listenable: _store,
          builder: (BuildContext context, Widget? child) {
            final ForumPost? post = _store.postById(widget.postId);
            if (post == null) {
              return Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Post not found'),
                ),
              );
            }

            final bool canSubmit = _selectedReason != null;

            return Column(
              children: <Widget>[
                ForumTopBar(
                  title: 'Report Post',
                  onBack: () => context.pop(),
                  onBookmark: () => context.push(AppRoutes.forumSaved),
                  onNotification: () =>
                      context.push(AppRoutes.forumNotifications),
                  onAvatarTap: () => context.push(AppRoutes.forumMe),
                  avatarUrl: _store.currentUserAuthor.avatarUrl,
                  showAvatar: false,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.pagePadding,
                      22,
                      AppConstants.pagePadding,
                      28,
                    ),
                    children: <Widget>[
                      _ReportedPostPreview(post: post),
                      const SizedBox(height: 22),
                      GlassCard(
                        borderRadius: 30,
                        blur: 16,
                        opacity: 0.58,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Why are you reporting this post?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: ForumColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._reasonOptions.map(
                              (_ReportReasonOption option) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ReportReasonTile(
                                  option: option,
                                  isSelected: _selectedReason?.id == option.id,
                                  onTap: () {
                                    setState(() {
                                      _selectedReason = option;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      GlassCard(
                        borderRadius: 30,
                        blur: 16,
                        opacity: 0.58,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Additional information (Optional)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: ForumColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              child: TextField(
                                controller: _detailsController,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  hintText:
                                      'Provide any additional details that might help us understand the issue...',
                                  hintStyle: TextStyle(
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: canSubmit
                              ? ForumColors.primaryGradient
                              : null,
                          color: canSubmit
                              ? null
                              : Colors.white.withValues(alpha: 0.54),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: canSubmit
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: ForumColors.cyanPrimary.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canSubmit ? () => _submitReport(post) : null,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                'Submit Report',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: canSubmit
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Your report is anonymous. We'll review it and take appropriate action.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportedPostPreview extends StatelessWidget {
  const _ReportedPostPreview({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 28,
      blur: 16,
      opacity: 0.58,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                post.author.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ForumColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                post.timeAgo,
                style: const TextStyle(
                  fontSize: 12,
                  color: ForumColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: ForumColors.textPrimary,
            ),
          ),
          if (post.imageUrls.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 1.72,
                child: _ReportPreviewImage(
                  imageUrl: post.imageUrls.first,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportReasonTile extends StatelessWidget {
  const _ReportReasonTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _ReportReasonOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? ForumColors.cyanPrimary.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.7),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.64),
                shape: BoxShape.circle,
              ),
              child: Icon(
                option.icon,
                size: 20,
                color: ForumColors.textPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    option.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ForumColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? ForumColors.cyanPrimary
                      : AppColors.textSecondary.withValues(alpha: 0.35),
                  width: 1.6,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: ForumColors.cyanPrimary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportReasonOption {
  const _ReportReasonOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _ReportPreviewImage extends StatelessWidget {
  const _ReportPreviewImage({required this.imageUrl, this.fit = BoxFit.cover});

  final String imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, fit: fit);
    }

    return Image.asset(imageUrl, fit: fit);
  }
}
