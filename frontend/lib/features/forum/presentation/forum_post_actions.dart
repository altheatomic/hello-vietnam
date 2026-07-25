import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';

class ForumPostActions {
  ForumPostActions._();

  static Future<bool> open(
    BuildContext context, {
    required ForumStore store,
    required ForumPost post,
  }) async {
    final ForumPostMoreAction? action = await ForumPostMoreMenu.show(
      context,
      author: post.author,
      isFollowing: post.author.isFollowing,
      isOwner: store.isCurrentUser(post.author.id),
    );
    if (!context.mounted || action == null) return false;

    switch (action) {
      case ForumPostMoreAction.edit:
        await context.push(AppRoutes.forumEditPath(post.id), extra: post);
        return false;
      case ForumPostMoreAction.delete:
        final bool confirmed = await _confirmDelete(context);
        if (!confirmed || !context.mounted) return false;
        try {
          await store.deletePost(post.id);
          if (context.mounted) {
            _showMessage(context, 'Post deleted.');
          }
          return true;
        } catch (error) {
          if (context.mounted) {
            _showMessage(context, error.toString());
          }
          return false;
        }
      case ForumPostMoreAction.follow:
        store.toggleFollowAuthor(post.author.id);
        return false;
      case ForumPostMoreAction.block:
        store.toggleBlockAuthor(post.author.id);
        _showMessage(
          context,
          '${post.author.name} was blocked from your feed.',
        );
        return false;
      case ForumPostMoreAction.report:
        await context.push(AppRoutes.forumReportPath(post.id));
        return false;
    }
  }

  static Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Delete post?'),
              content: const Text(
                'This post and all of its comments will be permanently deleted.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
