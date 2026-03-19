import 'package:flutter/material.dart';
import '../../domain/admin_user.dart';

/// Pill badge that displays [AdminUserStatus] with a tinted-fill treatment.
///
/// Design contract (mirrors the plan):
///   - Pill shape: BorderRadius.circular(20) — same as the Admin badge in
///     AdminSidebar's brand zone.
///   - Fill: 12 % tint of the semantic color, so the badge is clearly readable
///     against both the white table card and the #F5FAFF page background.
///   - Text: 12 px / w500 in the semantic color — labelMedium weight, slightly
///     above AppColors.textSecondary hierarchy to signal importance.
///
/// Reusable for any future admin page that surfaces user status
/// (e.g., report rows that reference a reported user).
class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({super.key, required this.status});

  final AdminUserStatus status;

  // Semantic green/red — not in AppColors because they are status-specific
  // and should not bleed into the app's primary colour system.
  static const Color _activeColor = Color(0xFF22C55E);
  static const Color _bannedColor = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final Color base = switch (status) {
      AdminUserStatus.active => _activeColor,
      AdminUserStatus.banned => _bannedColor,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: base,
        ),
      ),
    );
  }
}
