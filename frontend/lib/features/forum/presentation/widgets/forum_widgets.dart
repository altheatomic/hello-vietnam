import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/glass_card.dart';
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';

class ForumColors {
  ForumColors._();

  static const Color cyanPrimary = Color(0xFF06B6D4);
  static const Color bluePrimary = Color(0xFF3B82F6);
  static const Color blueLight = Color(0xFFEFF6FF);
  static const Color cyanLight = Color(0xFFECFEFF);
  static const Color tealLight = Color(0xFFF0FDFA);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color darkBackground = Color(0xFF020B10);
  static const Color darkSurface = Color(0xFF07161D);
  static const Color darkSurfaceHigh = Color(0xFF0E2530);
  static const Color darkText = Color(0xFFF5FBFF);
  static const Color darkMuted = Color(0xFFA9BCC7);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[cyanPrimary, bluePrimary],
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color foreground(BuildContext context) =>
      isDark(context) ? darkText : textPrimary;

  static Color muted(BuildContext context) =>
      isDark(context) ? darkMuted : textMuted;

  static Color action(BuildContext context) => isDark(context)
      ? darkMuted.withValues(alpha: 0.78)
      : AppColors.textSecondary;

  static Color glassBorder(BuildContext context, {double lightAlpha = 0.64}) =>
      isDark(context)
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.white.withValues(alpha: lightAlpha);
}

String formatCompactNumber(int value) {
  if (value >= 1000000) {
    final double compact = value / 1000000;
    return '${compact.toStringAsFixed(compact.truncateToDouble() == compact ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final double compact = value / 1000;
    return '${compact.toStringAsFixed(compact.truncateToDouble() == compact ? 0 : 1)}K';
  }
  return '$value';
}

class ForumBackground extends StatelessWidget {
  const ForumBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isDark = ForumColors.isDark(context);

    return Stack(
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const <Color>[
                      ForumColors.darkBackground,
                      Color(0xFF03131A),
                      Color(0xFF020B10),
                    ]
                  : const <Color>[
                      ForumColors.blueLight,
                      ForumColors.cyanLight,
                      ForumColors.tealLight,
                    ],
            ),
          ),
        ),
        if (!isDark) ...<Widget>[
          _BlurCircle(
            top: 120,
            left: -20,
            size: 220,
            color: const Color(0x3360A5FA),
          ),
          _BlurCircle(
            top: size.height * 0.28,
            right: -40,
            size: 260,
            color: const Color(0x332DD4BF),
          ),
          _BlurCircle(
            bottom: 80,
            left: size.width * 0.22,
            size: 300,
            color: const Color(0x1A22D3EE),
          ),
        ] else ...<Widget>[
          _BlurCircle(
            top: 96,
            right: -88,
            size: 240,
            color: ForumColors.cyanPrimary.withValues(alpha: 0.08),
          ),
          _BlurCircle(
            bottom: 72,
            left: -80,
            size: 260,
            color: ForumColors.bluePrimary.withValues(alpha: 0.07),
          ),
        ],
        child,
      ],
    );
  }
}

class ForumTopBar extends StatelessWidget {
  const ForumTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onBookmark,
    required this.onAvatarTap,
    required this.avatarUrl,
    this.showBookmark = true,
    this.showAvatar = true,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onBookmark;
  final VoidCallback onAvatarTap;
  final String avatarUrl;
  final bool showBookmark;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    final bool isDark = ForumColors.isDark(context);
    final Color iconColor = ForumColors.foreground(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            topInset + 10,
            AppConstants.pagePadding,
            12,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? ForumColors.darkBackground.withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.42),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.55),
              ),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                icon: Icon(Icons.arrow_back, color: iconColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
              ),
              if (showBookmark) ...<Widget>[
                _HeaderIconButton(
                  icon: Icons.bookmark_border_rounded,
                  onTap: onBookmark,
                ),
                const SizedBox(width: 12),
              ],
              if (showAvatar) ...<Widget>[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onAvatarTap,
                  child: ForumAvatar(
                    imageUrl: avatarUrl,
                    size: 34,
                    borderColor: Colors.white.withValues(
                      alpha: isDark ? 0.18 : 0.72,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ForumProfileTopBar extends StatelessWidget {
  const ForumProfileTopBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onBookmark,
    required this.onAvatarTap,
    required this.avatarUrl,
    required this.showCurrentAvatar,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onBookmark;
  final VoidCallback onAvatarTap;
  final String avatarUrl;
  final bool showCurrentAvatar;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    final bool isDark = ForumColors.isDark(context);
    final Color foreground = ForumColors.foreground(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            topInset + 8,
            AppConstants.pagePadding,
            12,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? ForumColors.darkBackground.withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.42),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.55),
              ),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: IconButton(
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: Icon(Icons.arrow_back, color: foreground, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: ForumColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: <Widget>[
                    _HeaderIconButton(
                      icon: Icons.bookmark_border_rounded,
                      onTap: onBookmark,
                    ),
                    if (showCurrentAvatar) ...<Widget>[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onAvatarTap,
                        child: ForumAvatar(
                          imageUrl: avatarUrl,
                          size: 44,
                          borderColor: Colors.white.withValues(
                            alpha: isDark ? 0.18 : 0.72,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForumPostComposerPrompt extends StatelessWidget {
  const ForumPostComposerPrompt({
    super.key,
    required this.avatarUrl,
    required this.onTap,
  });

  final String avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = ForumColors.isDark(context);

    return GlassCard(
      borderRadius: 30,
      blur: 14,
      opacity: 0.58,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      border: Border.all(color: ForumColors.glassBorder(context)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: <Widget>[
            ForumAvatar(
              imageUrl: avatarUrl,
              size: 42,
              borderColor: Colors.white.withValues(alpha: isDark ? 0.18 : 0.75),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.62),
                  ),
                ),
                child: Text(
                  'Share your Vietnam moment...',
                  style: TextStyle(
                    fontSize: 14,
                    color: ForumColors.muted(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.add_photo_alternate_outlined,
              color: isDark ? AppColors.primaryLight : ForumColors.bluePrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class ForumPostCard extends StatelessWidget {
  const ForumPostCard({
    super.key,
    required this.post,
    required this.onOpen,
    required this.onAuthorTap,
    required this.onLike,
    required this.onComment,
    required this.onBookmark,
    required this.onShare,
    required this.onFollow,
    required this.onMore,
    this.onSharedItemTap,
    this.onSharedTripPlanTap,
    this.showMoreButton = true,
    this.showInlineFollow = true,
  });

  final ForumPost post;
  final VoidCallback onOpen;
  final VoidCallback onAuthorTap;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onFollow;
  final VoidCallback onMore;
  final VoidCallback? onSharedItemTap;
  final VoidCallback? onSharedTripPlanTap;
  final bool showMoreButton;
  final bool showInlineFollow;

  @override
  Widget build(BuildContext context) {
    final Color textColor = ForumColors.foreground(context);
    final Color mutedColor = ForumColors.muted(context);
    final Color actionColor = ForumColors.action(context);

    return GlassCard(
      borderRadius: 26,
      blur: 14,
      opacity: 0.58,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      border: Border.all(color: ForumColors.glassBorder(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    InkWell(
                      onTap: onAuthorTap,
                      borderRadius: BorderRadius.circular(999),
                      child: ForumAvatar(
                        imageUrl: post.author.avatarUrl,
                        size: 46,
                        borderColor: Colors.white.withValues(
                          alpha: ForumColors.isDark(context) ? 0.18 : 0.75,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: onAuthorTap,
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    post.author.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                if (post.author.isVerified) ...<Widget>[
                                  const SizedBox(width: 6),
                                  const _VerifiedBadge(),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              post.timeAgo,
                              style: TextStyle(fontSize: 12, color: mutedColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showInlineFollow && post.showFollowButton) ...<Widget>[
                      ForumFollowButton(
                        isFollowing: post.author.isFollowing,
                        onTap: onFollow,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (showMoreButton)
                      IconButton(
                        onPressed: onMore,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: mutedColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  post.content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: textColor,
                  ),
                ),
                if (post.sharedTripPlan != null) ...<Widget>[
                  const SizedBox(height: 12),
                  ForumSharedTripPlanCard(
                    item: post.sharedTripPlan!,
                    onTap: onSharedTripPlanTap,
                  ),
                ] else if (post.sharedItem != null) ...<Widget>[
                  const SizedBox(height: 12),
                  ForumSharedItemCard(
                    item: post.sharedItem!,
                    onTap: onSharedItemTap,
                  ),
                ],
                if (post.imageUrls.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  ForumPostGallery(imageUrls: post.imageUrls),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _ActionIcon(
                icon: post.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: post.isLiked ? const Color(0xFFEF4444) : actionColor,
                onTap: onLike,
              ),
              const SizedBox(width: 6),
              Text(
                '${post.likes}',
                style: TextStyle(fontSize: 14, color: actionColor),
              ),
              const Spacer(),
              _ActionIcon(icon: Icons.mode_comment_outlined, onTap: onComment),
              const SizedBox(width: 6),
              Text(
                '${post.comments}',
                style: TextStyle(fontSize: 14, color: actionColor),
              ),
              const Spacer(),
              _ActionIcon(
                icon: post.isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: post.isBookmarked
                    ? ForumColors.bluePrimary
                    : actionColor,
                onTap: onBookmark,
              ),
              const Spacer(),
              _ActionIcon(icon: Icons.share_outlined, onTap: onShare),
            ],
          ),
        ],
      ),
    );
  }
}

class ForumSharedItemCard extends StatelessWidget {
  const ForumSharedItemCard({super.key, required this.item, this.onTap});

  final SharedExploreItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String secondaryText = _secondaryText(item);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: _ForumImage(
                    imageUrl: item.imagePath,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.category.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ForumColors.bluePrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ForumColors.textPrimary,
                      ),
                    ),
                    if (secondaryText.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ForumColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: ForumColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _secondaryText(SharedExploreItem item) {
    final String provinceName = (item.provinceName ?? '').trim();
    if (provinceName.isNotEmpty) {
      return provinceName;
    }
    return (item.subtitle ?? '').trim();
  }
}

/// Generic (no cover image / no highlights) preview card for a shared trip
/// plan post. Intentionally minimal — see SharedTripPlanItem docstring.
class ForumSharedTripPlanCard extends StatelessWidget {
  const ForumSharedTripPlanCard({super.key, required this.item, this.onTap});

  final SharedTripPlanItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String province = item.provinceName.isNotEmpty
        ? item.provinceName
        : 'Vietnam';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 68,
                  height: 68,
                  color: ForumColors.bluePrimary.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.map_outlined,
                    color: ForumColors.bluePrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Trip plan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ForumColors.bluePrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trip to $province',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ForumColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.nDays} days · ${item.placeCount} places',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ForumColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: ForumColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ForumPostMoreAction { edit, delete, follow, block, report }

class ForumPostMoreMenu {
  ForumPostMoreMenu._();

  static Future<ForumPostMoreAction?> show(
    BuildContext context, {
    required ForumAuthor author,
    required bool isFollowing,
    required bool isOwner,
  }) {
    return showGeneralDialog<ForumPostMoreAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.08),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 132, right: 20, left: 72),
                  child: Material(
                    color: Colors.transparent,
                    child: GlassCard(
                      borderRadius: 34,
                      blur: 18,
                      opacity: 0.84,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: isOwner
                            ? <Widget>[
                                _ForumPostMoreMenuTile(
                                  icon: Icons.edit_outlined,
                                  label: 'Edit post',
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pop(ForumPostMoreAction.edit),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 24,
                                  endIndent: 24,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                _ForumPostMoreMenuTile(
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Delete post',
                                  foregroundColor: Colors.red.shade600,
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pop(ForumPostMoreAction.delete),
                                ),
                              ]
                            : <Widget>[
                                _ForumPostMoreMenuTile(
                                  icon: isFollowing
                                      ? Icons.person_remove_alt_1_outlined
                                      : Icons.person_add_alt_1_rounded,
                                  label:
                                      '${isFollowing ? 'Unfollow' : 'Follow'} ${author.handle}',
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pop(ForumPostMoreAction.follow),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 24,
                                  endIndent: 24,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                _ForumPostMoreMenuTile(
                                  icon: Icons.block_outlined,
                                  label: 'Block ${author.handle}',
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pop(ForumPostMoreAction.block),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 24,
                                  endIndent: 24,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                _ForumPostMoreMenuTile(
                                  icon: Icons.outlined_flag_rounded,
                                  label: 'Report this post',
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pop(ForumPostMoreAction.report),
                                ),
                              ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
    );
  }
}

class _ForumPostMoreMenuTile extends StatelessWidget {
  const _ForumPostMoreMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final Color foreground = foregroundColor ?? ForumColors.foreground(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 28, color: foreground),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForumCommentCard extends StatelessWidget {
  const ForumCommentCard({
    super.key,
    required this.comment,
    required this.onAuthorTap,
    required this.onLike,
    required this.onReply,
  });

  final ForumComment comment;
  final VoidCallback onAuthorTap;
  final VoidCallback onLike;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final Color textColor = ForumColors.foreground(context);
    final Color mutedColor = ForumColors.muted(context);
    final Color actionColor = ForumColors.action(context);

    return GlassCard(
      borderRadius: 24,
      blur: 14,
      opacity: 0.5,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      border: Border.all(color: ForumColors.glassBorder(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              InkWell(
                onTap: onAuthorTap,
                borderRadius: BorderRadius.circular(999),
                child: ForumAvatar(
                  imageUrl: comment.author.avatarUrl,
                  size: 42,
                  borderColor: Colors.white.withValues(
                    alpha: ForumColors.isDark(context) ? 0.18 : 0.72,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onAuthorTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: <Widget>[
                      Text(
                        comment.author.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      if (comment.author.isVerified) const _VerifiedBadge(),
                      Text(
                        comment.timeAgo,
                        style: TextStyle(fontSize: 13, color: mutedColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            comment.content,
            style: TextStyle(fontSize: 14, height: 1.45, color: textColor),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _ActionIcon(
                icon: comment.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: comment.isLiked ? const Color(0xFFEF4444) : actionColor,
                onTap: onLike,
              ),
              const SizedBox(width: 4),
              Text(
                '${comment.likes}',
                style: TextStyle(fontSize: 14, color: actionColor),
              ),
              const SizedBox(width: 18),
              _ActionIcon(icon: Icons.reply_outlined, onTap: onReply),
            ],
          ),
        ],
      ),
    );
  }
}

class ForumProfileHeaderCard extends StatelessWidget {
  const ForumProfileHeaderCard({
    super.key,
    required this.profile,
    required this.postsCount,
    required this.onToggleFollow,
  });

  final ForumUserProfile profile;
  final int postsCount;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final bool isDark = ForumColors.isDark(context);
    final Color textColor = ForumColors.foreground(context);
    final Color mutedColor = ForumColors.muted(context);

    return GlassCard(
      borderRadius: 30,
      blur: 16,
      opacity: 0.52,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      border: Border.all(
        color: ForumColors.glassBorder(context, lightAlpha: 0.68),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ForumAvatar(
                imageUrl: profile.author.avatarUrl,
                size: 92,
                borderColor: Colors.white.withValues(
                  alpha: isDark ? 0.18 : 0.8,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            profile.author.name,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (profile.author.isVerified) ...<Widget>[
                          const SizedBox(width: 10),
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: _VerifiedBadge(),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.author.handle,
                      style: TextStyle(fontSize: 17, color: mutedColor),
                    ),
                  ],
                ),
              ),
              if (!profile.isCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ForumFollowButton(
                    isFollowing: profile.author.isFollowing,
                    onTap: onToggleFollow,
                    large: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.64),
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              _ProfileMetric(
                value: '$postsCount',
                label: context.l10n.ui('Posts'),
              ),
              const SizedBox(width: 26),
              _ProfileMetric(
                value: formatCompactNumber(profile.followersCount),
                label: context.l10n.ui('Followers'),
              ),
              const SizedBox(width: 26),
              _ProfileMetric(
                value: '${profile.followingCount}',
                label: context.l10n.ui('Following'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ForumFollowButton extends StatelessWidget {
  const ForumFollowButton({
    super.key,
    required this.isFollowing,
    required this.onTap,
    this.large = false,
  });

  final bool isFollowing;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final bool isDark = ForumColors.isDark(context);
    final EdgeInsets padding = large
        ? const EdgeInsets.symmetric(horizontal: 18, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 8);

    final TextStyle textStyle = TextStyle(
      color: isFollowing ? ForumColors.foreground(context) : Colors.white,
      fontSize: large ? 17 : 13,
      fontWeight: FontWeight.w600,
    );

    if (isFollowing) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.62),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: padding,
                  child: Text(context.l10n.ui('Following'), style: textStyle),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: ForumColors.primaryGradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ForumColors.cyanPrimary.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.add, size: large ? 20 : 15, color: Colors.white),
                const SizedBox(width: 4),
                Text(context.l10n.ui('Follow'), style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForumReplyDialog extends StatefulWidget {
  const ForumReplyDialog({
    super.key,
    required this.post,
    required this.replyingToHandle,
    required this.currentUser,
    required this.onSubmit,
  });

  final ForumPost post;
  final String replyingToHandle;
  final ForumAuthor currentUser;
  final ValueChanged<String> onSubmit;

  static Future<void> show(
    BuildContext context, {
    required ForumPost post,
    required String replyingToHandle,
    required ForumAuthor currentUser,
    required ValueChanged<String> onSubmit,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (BuildContext context) {
        return ForumReplyDialog(
          post: post,
          replyingToHandle: replyingToHandle,
          currentUser: currentUser,
          onSubmit: onSubmit,
        );
      },
    );
  }

  @override
  State<ForumReplyDialog> createState() => _ForumReplyDialogState();
}

class _ForumReplyDialogState extends State<ForumReplyDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _controller.text.trim().isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: GlassCard(
        borderRadius: 32,
        blur: 18,
        opacity: 0.78,
        padding: EdgeInsets.zero,
        border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      size: 28,
                      color: ForumColors.foreground(context),
                    ),
                  ),
                  const Spacer(),
                  ForumReplyPrimaryButton(
                    enabled: canSubmit,
                    onTap: () {
                      if (!canSubmit) {
                        return;
                      }
                      widget.onSubmit(_controller.text.trim());
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.64)),
              const SizedBox(height: 18),
              _ReplyPostPreview(post: widget.post),
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.64)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ForumAvatar(
                    imageUrl: widget.currentUser.avatarUrl,
                    size: 44,
                    borderColor: Colors.white.withValues(alpha: 0.76),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 17,
                              color: ForumColors.muted(context),
                            ),
                            children: <TextSpan>[
                              const TextSpan(text: 'Replying to '),
                              TextSpan(
                                text: widget.replyingToHandle,
                                style: const TextStyle(
                                  color: ForumColors.cyanPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          constraints: const BoxConstraints(minHeight: 200),
                          decoration: BoxDecoration(
                            color: ForumColors.isDark(context)
                                ? ForumColors.darkSurfaceHigh
                                : Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: ForumColors.cyanPrimary.withValues(
                                alpha: 0.5,
                              ),
                              width: 1.6,
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            maxLines: 8,
                            minLines: 6,
                            enableInteractiveSelection: false,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: context.l10n.ui('Type your answer'),
                              hintStyle: TextStyle(
                                fontSize: 18,
                                color: ForumColors.muted(
                                  context,
                                ).withValues(alpha: 0.8),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(20),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: ForumColors.foreground(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForumReplyPrimaryButton extends StatelessWidget {
  const ForumReplyPrimaryButton({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = enabled
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.56);
    final Color foreground = enabled
        ? AppColors.textSecondary
        : AppColors.textSecondary.withValues(alpha: 0.55);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text(
              'Reply',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyPostPreview extends StatelessWidget {
  const _ReplyPostPreview({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ForumAvatar(
          imageUrl: post.author.avatarUrl,
          size: 44,
          borderColor: Colors.white.withValues(alpha: 0.76),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      post.author.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: ForumColors.textPrimary,
                      ),
                    ),
                  ),
                  if (post.author.isVerified) ...<Widget>[
                    const SizedBox(width: 8),
                    const _VerifiedBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                post.content,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: ForumColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ForumPostGallery extends StatefulWidget {
  const ForumPostGallery({super.key, required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<ForumPostGallery> createState() => _ForumPostGalleryState();
}

class _ForumPostGalleryState extends State<ForumPostGallery> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: <Widget>[
            PageView.builder(
              controller: _controller,
              itemCount: widget.imageUrls.length,
              onPageChanged: (int index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (BuildContext context, int index) {
                return _ForumImage(
                  imageUrl: widget.imageUrls[index],
                  fit: BoxFit.cover,
                );
              },
            ),
            if (widget.imageUrls.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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

class ForumAvatar extends StatelessWidget {
  const ForumAvatar({
    super.key,
    required this.imageUrl,
    required this.size,
    this.borderColor,
  });

  final String imageUrl;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.5),
        ),
      ),
      child: ClipOval(
        child: _ForumImage(imageUrl: imageUrl, fit: BoxFit.cover),
      ),
    );
  }
}

class ForumTabBar extends StatelessWidget {
  const ForumTabBar({super.key, required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    final bool isDark = ForumColors.isDark(context);

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
      decoration: BoxDecoration(
        color: isDark
            ? ForumColors.darkBackground.withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.24),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.only(right: 34),
        indicatorColor: ForumColors.bluePrimary,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        labelColor: ForumColors.foreground(context),
        unselectedLabelColor: ForumColors.muted(context),
        tabs: <Tab>[
          Tab(text: context.l10n.ui('For you')),
          Tab(text: context.l10n.ui('Following')),
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
  });

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(color: color, blurRadius: 110, spreadRadius: 14),
            ],
          ),
          child: SizedBox(width: size, height: size),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = ForumColors.foreground(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 24, color: color),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: ForumColors.cyanPrimary,
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = color ?? ForumColors.action(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 24, color: iconColor),
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color textColor = ForumColors.foreground(context);
    final Color mutedColor = ForumColors.muted(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 16, color: mutedColor)),
      ],
    );
  }
}

class _ForumImage extends StatelessWidget {
  const _ForumImage({required this.imageUrl, this.fit = BoxFit.cover});

  final String imageUrl;
  final BoxFit fit;

  bool get _isAsset => imageUrl.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    if (imageUrl == 'deleted-media://placeholder') {
      return Container(
        color: const Color(0xFFF1F1F1),
        alignment: Alignment.center,
        child: const Text('Image deleted', textAlign: TextAlign.center),
      );
    }
    if (_isAsset) {
      return Image.asset(imageUrl, fit: fit);
    }

    return Image.network(
      imageUrl,
      fit: fit,
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return Container(
              color: Colors.white.withValues(alpha: 0.6),
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textSecondary,
              ),
            );
          },
      loadingBuilder:
          (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }

            return Container(
              color: Colors.white.withValues(alpha: 0.6),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
    );
  }
}
