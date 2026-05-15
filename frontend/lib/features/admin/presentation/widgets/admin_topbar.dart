import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';

/// Fixed-height top bar for the admin shell.
///
/// Layout (left → right):
///   [Page title]  ····  [Search pill]  ·  [Notification]  [Language]  [User]
///
/// The search pill replicates the visual rules from SearchBarWidget (radius 45,
/// white fill, primary-blue icon, textSecondary hint) without importing the
/// mobile widget, whose Row+filter-button layout doesn't fit a top bar.
///
/// The notification button mirrors home_page.dart's circular notification
/// container (primaryLight tint, outlined icon), adapted for a white background.
class AdminTopBar extends StatelessWidget {
  const AdminTopBar({super.key, required this.title});

  final String title;

  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Page title — titleLarge from app TextTheme
          const Spacer(),

          // Notification — mirrors home_page.dart notification button
          const _NotificationButton(),

          const SizedBox(width: 12),

          // User avatar + name
          const _UserProfile(),
        ],
      ),
    );
  }
}

// ── Notification button ──────────────────────────────────────────────────────

/// Circular container with primaryLight tint and outlined notification icon.
/// Mirrors home_page.dart:52–68, adapted for a white topbar background:
///   - home uses white-20% fill (visible on primaryLight header)
///   - admin uses primaryLight-20% fill (visible on white surface)
class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.20),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.notifications_outlined,
        size: 22,
        color: AppColors.primary,
      ),
    );
  }
}

// ── User profile chip ────────────────────────────────────────────────────────

class _UserProfile extends StatelessWidget {
  const _UserProfile();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar — matches home notification button's 40×40 circle sizing
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primaryLight,
          child: const Icon(
            Icons.person_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text('Administrator', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}
