import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';

class ForumNotificationsPage extends StatelessWidget {
  const ForumNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ForumStore store = ForumStore.instance;

    void handleBack() {
      if (Navigator.of(context).canPop()) {
        context.pop();
        return;
      }

      context.go(AppRoutes.forum);
    }

    return ForumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppConstants.pagePadding,
                  MediaQuery.of(context).padding.top + 12,
                  AppConstants.pagePadding,
                  6,
                ),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: handleBack,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: ForumColors.textPrimary,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => context.push(AppRoutes.forumSaved),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.bookmark_border_rounded,
                          size: 24,
                          color: ForumColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            size: 24,
                            color: ForumColors.textPrimary,
                          ),
                        ),
                        Positioned(
                          right: 3,
                          top: 2,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFB4141),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.forumMe),
                      child: ForumAvatar(
                        imageUrl: store.currentUserAuthor.avatarUrl,
                        size: 46,
                        borderColor: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    6,
                    20,
                    AppConstants.pagePadding,
                  ),
                  child: ForumNotificationSheet(
                    notifications: store.notifications,
                    onTapItem: (ForumNotificationItem item) {
                      if (item.postId != null) {
                        context.push(AppRoutes.forumPostPath(item.postId!));
                        return;
                      }

                      if (store.isCurrentUser(item.actor.id)) {
                        context.push(AppRoutes.forumMe);
                        return;
                      }

                      context.push(AppRoutes.forumProfilePath(item.actor.id));
                    },
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
