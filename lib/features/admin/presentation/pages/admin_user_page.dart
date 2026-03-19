import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import '../../data/admin_user_mock_data.dart';
import '../../domain/admin_user.dart';
import '../widgets/admin_search_filter_bar.dart';
import '../widgets/admin_section_header.dart';
import '../widgets/admin_status_badge.dart';

/// Admin User Management page.
///
/// Rendered inside [AdminShell] via the go_router ShellRoute — the sidebar,
/// topbar, and scrollable container are all provided by the shell.
///
/// State managed here:
///   [_users]         — mutable copy of mock data; ban/unban toggles in-place.
///   [_searchController] — drives the search pill; page rebuilds on every
///                         keystroke via [_onSearchChanged].
///   [_filterStatus]  — currently selected status chip (null = all).
///
/// Filtering is a pure synchronous getter [_filteredUsers]; no async needed
/// for mock data.
class AdminUserPage extends StatefulWidget {
  const AdminUserPage({super.key});

  @override
  State<AdminUserPage> createState() => _AdminUserPageState();
}

class _AdminUserPageState extends State<AdminUserPage> {
  // Mutable copy so ban/unban can update in-place without touching mock source.
  late final List<AdminUser> _users =
      mockAdminUsers.map((u) => u).toList();

  final TextEditingController _searchController = TextEditingController();
  AdminUserStatus? _filterStatus;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) => setState(() {});

  void _onFilterStatusChanged(AdminUserStatus? status) =>
      setState(() => _filterStatus = status);

  /// Applies both search query and status filter to [_users].
  List<AdminUser> get _filteredUsers {
    final query = _searchController.text.toLowerCase().trim();
    return _users.where((u) {
      final matchesSearch = query.isEmpty ||
          u.username.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.id.contains(query);
      final matchesStatus =
          _filterStatus == null || u.status == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  void _toggleBan(AdminUser user) {
    setState(() {
      final idx = _users.indexWhere((u) => u.id == user.id);
      if (idx == -1) return;
      _users[idx] = _users[idx].copyWith(
        status: _users[idx].status == AdminUserStatus.active
            ? AdminUserStatus.banned
            : AdminUserStatus.active,
      );
    });

    final updated =
        _users.firstWhere((u) => u.id == user.id);
    final action =
        updated.status == AdminUserStatus.banned ? 'banned' : 'unbanned';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.username} has been $action.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;
    final total = _users.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Page header ──────────────────────────────────────────
        AdminSectionHeader(
          title: 'User Manager',
          subtitle: 'View, search, and manage registered users',
          trailing: _UserCountBadge(total: total),
        ),

        // ── Search + filter bar ──────────────────────────────────
        AdminSearchFilterBar(
          controller: _searchController,
          filterStatus: _filterStatus,
          onFilterStatusChanged: _onFilterStatusChanged,
          onSearchChanged: _onSearchChanged,
        ),

        const SizedBox(height: 20),

        // ── User table ───────────────────────────────────────────
        filtered.isEmpty
            ? EmptyState(
                icon: Icons.people_outline_rounded,
                message: 'No users match your search.',
              )
            : _UserTable(
                users: filtered,
                onToggleBan: _toggleBan,
              ),
      ],
    );
  }
}

// ── User count badge ─────────────────────────────────────────────────────────

class _UserCountBadge extends StatelessWidget {
  const _UserCountBadge({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$total users',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── User table ───────────────────────────────────────────────────────────────

/// White card container with a themed header row and one [_UserRow] per user.
///
/// Card shadow reuses the same treatment as RecommendationCard:
///   BoxShadow(black 8 %, blurRadius 16, offset (0, 4)).
class _UserTable extends StatelessWidget {
  const _UserTable({required this.users, required this.onToggleBan});

  final List<AdminUser> users;
  final ValueChanged<AdminUser> onToggleBan;

  // Fixed column widths (px). The username column is Expanded.
  static const double _colId     = 90;
  static const double _colEmail  = 196;
  static const double _colPhone  = 136;
  static const double _colRole   = 72;
  static const double _colStatus = 110;
  static const double _colAction = 88;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: [
          // RecommendationCard shadow — keeps card treatment consistent
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: Column(
          children: [
            // Header
            _TableHeader(
              colId: _colId,
              colEmail: _colEmail,
              colPhone: _colPhone,
              colRole: _colRole,
              colStatus: _colStatus,
              colAction: _colAction,
            ),
            // Rows
            ...List.generate(users.length, (i) {
              return _UserRow(
                user: users[i],
                isLast: i == users.length - 1,
                onToggleBan: () => onToggleBan(users[i]),
                colId: _colId,
                colEmail: _colEmail,
                colPhone: _colPhone,
                colRole: _colRole,
                colStatus: _colStatus,
                colAction: _colAction,
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Table header row ─────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.colId,
    required this.colEmail,
    required this.colPhone,
    required this.colRole,
    required this.colStatus,
    required this.colAction,
  });

  final double colId;
  final double colEmail;
  final double colPhone;
  final double colRole;
  final double colStatus;
  final double colAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      // primaryLight 15 % tint — same alpha as FeatureGrid tile bg
      color: AppColors.primaryLight.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _HeaderCell(label: 'User ID',      width: colId),
          const _HeaderCellExpanded(label: 'User Name'),
          _HeaderCell(label: 'Email',        width: colEmail),
          _HeaderCell(label: 'Phone',        width: colPhone),
          _HeaderCell(label: 'Role',         width: colRole),
          _HeaderCell(label: 'Status',       width: colStatus),
          _HeaderCell(label: 'Action',       width: colAction),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _HeaderCellExpanded extends StatelessWidget {
  const _HeaderCellExpanded({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Data row ─────────────────────────────────────────────────────────────────

class _UserRow extends StatefulWidget {
  const _UserRow({
    required this.user,
    required this.isLast,
    required this.onToggleBan,
    required this.colId,
    required this.colEmail,
    required this.colPhone,
    required this.colRole,
    required this.colStatus,
    required this.colAction,
  });

  final AdminUser user;
  final bool isLast;
  final VoidCallback onToggleBan;
  final double colId;
  final double colEmail;
  final double colPhone;
  final double colRole;
  final double colStatus;
  final double colAction;

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.defaultAnimation,
        decoration: BoxDecoration(
          // Subtle hover tint — same primaryLight alpha used in nav hover
          color: _hovered
              ? AppColors.primaryLight.withValues(alpha: 0.06)
              : AppColors.surface,
          border: widget.isLast
              ? null
              : Border(
                  bottom: BorderSide(color: AppColors.divider),
                ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 62,
        child: Row(
          children: [
            // User ID
            SizedBox(
              width: widget.colId,
              child: Text(
                user.id,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // User Name (avatar + name)
            Expanded(
              child: Row(
                children: [
                  _UserAvatar(username: user.username),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      user.username,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Email
            SizedBox(
              width: widget.colEmail,
              child: Text(
                user.email,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Phone
            SizedBox(
              width: widget.colPhone,
              child: Text(
                user.phone,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Role
            SizedBox(
              width: widget.colRole,
              child: Text(
                user.role.label,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Status badge
            SizedBox(
              width: widget.colStatus,
              child: AdminStatusBadge(status: user.status),
            ),

            // Ban / Unban action
            SizedBox(
              width: widget.colAction,
              child: _ActionButton(
                isBanned: user.status == AdminUserStatus.banned,
                onTap: widget.onToggleBan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── User avatar ───────────────────────────────────────────────────────────────

/// Circular avatar showing the first letter of [username].
///
/// Uses a deterministic tint from the app's primary palette so different
/// users are visually distinguishable without needing real images.
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.username});

  final String username;

  // Four tints from the primary palette — cycled by username length
  static const List<Color> _tints = [
    AppColors.primary,
    AppColors.primaryDark,
    AppColors.accent,
    AppColors.primaryLight,
  ];

  @override
  Widget build(BuildContext context) {
    final Color bg = _tints[username.length % _tints.length];
    final String initial =
        username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

/// Small outlined pill button for Ban / Unban actions.
///
/// Ban:   red border + red label — signals a destructive action.
/// Unban: primary blue border + primary label — signals a restoring action.
///
/// Radius uses AppConstants.buttonRadius (12 px) to stay consistent with
/// all other button-like elements in the admin shell.
class _ActionButton extends StatefulWidget {
  const _ActionButton({required this.isBanned, required this.onTap});

  final bool isBanned;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color base =
        widget.isBanned ? AppColors.primary : const Color(0xFFEF4444);
    final String label = widget.isBanned ? 'Unban' : 'Ban';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.defaultAnimation,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? base.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            border: Border.all(color: base.withValues(alpha: 0.6)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: base,
            ),
          ),
        ),
      ),
    );
  }
}
