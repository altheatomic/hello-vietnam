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

          // Search pill (SearchBarWidget visual rules, desktop width)
          const _SearchField(),

          const SizedBox(width: 16),

          // Notification — mirrors home_page.dart notification button
          const _NotificationButton(),

          const SizedBox(width: 12),

          // Language selector
          const _LanguageSelector(),

          const SizedBox(width: 12),

          // User avatar + name
          const _UserProfile(),
        ],
      ),
    );
  }
}

// ── Search pill ──────────────────────────────────────────────────────────────

/// Adapts SearchBarWidget's pill treatment for a fixed-width desktop context.
/// Visual rules preserved: radius 45, white fill, shadow, primary search icon,
/// textSecondary hint at 50% opacity, fontSize 14.
class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(45),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
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

// ── Language selector ────────────────────────────────────────────────────────

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🇺🇸', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          const Text(
            'Eng (US)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ],
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
