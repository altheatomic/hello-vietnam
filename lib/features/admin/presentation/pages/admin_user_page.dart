import 'dart:js_interop';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import 'package:web/web.dart' as web;
import '../../data/admin_user_mock_data.dart';
import '../../domain/admin_user.dart';
import '../widgets/admin_search_filter_bar.dart';
import '../widgets/admin_section_header.dart';
import '../widgets/admin_status_badge.dart';
import '../widgets/admin_table_sort_header.dart';
import '../widgets/admin_user_form_dialog.dart';

enum _UserSortField { fullName }

class AdminUserPage extends StatefulWidget {
  const AdminUserPage({super.key});

  @override
  State<AdminUserPage> createState() => _AdminUserPageState();
}

class _AdminUserPageState extends State<AdminUserPage> {
  late final List<AdminUser> _users = mockAdminUsers.map((u) => u).toList();

  final TextEditingController _searchController = TextEditingController();
  AdminUserStatus? _filterStatus;
  _UserSortField? _activeSortField;
  SortDirection? _activeSortDirection;
  int _currentPage = 1;

  static const int _pageSize = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) => setState(() => _currentPage = 1);

  void _onFilterStatusChanged(AdminUserStatus? status) => setState(() {
    _filterStatus = status;
    _currentPage = 1;
  });

  void _onSortSelected(_UserSortField field, SortMenuAction action) =>
      setState(() {
        if (action == SortMenuAction.defaultOrder) {
          _activeSortField = null;
          _activeSortDirection = null;
        } else {
          _activeSortField = field;
          _activeSortDirection = action == SortMenuAction.ascending
              ? SortDirection.ascending
              : SortDirection.descending;
        }
        _currentPage = 1;
      });

  /// Base order: id ASC. Active sort applied on top with id as tiebreaker.
  List<AdminUser> get _filteredUsers {
    final query = _searchController.text.toLowerCase().trim();
    final result = _users.where((u) {
      final matchesSearch =
          query.isEmpty ||
          (u.fullName ?? u.username).toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.id.contains(query);
      final matchesStatus = _filterStatus == null || u.status == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList()..sort((a, b) => a.id.compareTo(b.id));

    if (_activeSortField == null || _activeSortDirection == null) return result;

    result.sort((a, b) {
      final va = (a.fullName ?? a.username).toLowerCase();
      final vb = (b.fullName ?? b.username).toLowerCase();
      final cmp = va.compareTo(vb);
      if (cmp != 0) {
        return _activeSortDirection == SortDirection.ascending ? cmp : -cmp;
      }
      return a.id.compareTo(b.id);
    });
    return result;
  }

  /// Slice of [_filteredUsers] for the current page.
  List<AdminUser> get _pagedUsers {
    final all = _filteredUsers;
    final start = (_currentPage - 1) * _pageSize;
    final end = min(start + _pageSize, all.length);
    if (start >= all.length) return [];
    return all.sublist(start, end);
  }

  int get _totalPages => (_filteredUsers.length / _pageSize)
      .ceil()
      .clamp(1, double.maxFinite)
      .toInt();

  /// Downloads the full (unfiltered) user list as a CSV file.
  /// Columns: id_user, Full name, Phone, Email.
  void _exportUsers() {
    final rows = <String>['id_user,Full name,Phone,Email'];
    String esc(String s) =>
        s.contains(',') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;
    for (final u in _users) {
      rows.add(
        [
          esc(u.id),
          esc(u.fullName ?? u.username),
          esc(u.phone),
          esc(u.email),
        ].join(','),
      );
    }
    final csv = rows.join('\r\n');
    final blob = web.Blob(
      [csv.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    web.HTMLAnchorElement()
      ..href = url
      ..download = 'users_export.csv'
      ..click();
    web.URL.revokeObjectURL(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export started — check your Downloads folder.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Opens the Add User dialog; on confirm, inserts the new user at the top.
  Future<void> _openAddUser() async {
    final newUser = await showDialog<AdminUser>(
      context: context,
      builder: (_) => const AdminUserFormDialog(),
    );
    if (newUser == null || !mounted) return;
    setState(() {
      _users.insert(0, newUser);
      _currentPage = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${newUser.username} has been added.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    final updated = _users.firstWhere((u) => u.id == user.id);
    final verb = updated.status == AdminUserStatus.banned
        ? 'banned'
        : 'unbanned';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.username} has been $verb.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;
    final paged = _pagedUsers;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page header ──────────────────────────────────────────
          AdminSectionHeader(
            title: 'User Manager',
            subtitle: 'View, search, and manage registered users',
            trailing: _HeaderActions(
              onExport: _exportUsers,
              onAddUser: _openAddUser,
            ),
          ),

          // ── Search + filter bar ──────────────────────────────────
          AdminSearchFilterBar(
            controller: _searchController,
            filterStatus: _filterStatus,
            onFilterStatusChanged: _onFilterStatusChanged,
            onSearchChanged: _onSearchChanged,
          ),

          const SizedBox(height: 16),

          // ── Table or empty state ─────────────────────────────────
          if (filtered.isEmpty)
            EmptyState(
              icon: Icons.people_outline_rounded,
              message: 'No users match your search.',
            )
          else ...[
            _UserTable(
              users: paged,
              onToggleBan: _toggleBan,
              activeSortField: _activeSortField,
              activeSortDirection: _activeSortDirection,
              onSortSelected: _onSortSelected,
            ),

            const SizedBox(height: 16),

            // ── Footer: count + pagination ───────────────────────
            _TableFooter(
              currentPage: _currentPage,
              totalPages: _totalPages,
              totalUsers: filtered.length,
              pageSize: _pageSize,
              onPageChanged: (p) => setState(() => _currentPage = p),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Header action buttons ─────────────────────────────────────────────────────

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({required this.onExport, required this.onAddUser});

  final VoidCallback onExport;
  final VoidCallback onAddUser;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.file_download_outlined, size: 17),
          label: const Text('Export'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(color: AppColors.divider, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Add User — primary filled
        FilledButton.icon(
          onPressed: onAddUser,
          icon: const Icon(Icons.person_add_outlined, size: 17),
          label: const Text('Add User'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ── User table ────────────────────────────────────────────────────────────────

class _UserTable extends StatelessWidget {
  const _UserTable({
    required this.users,
    required this.onToggleBan,
    required this.activeSortField,
    required this.activeSortDirection,
    required this.onSortSelected,
  });

  final List<AdminUser> users;
  final ValueChanged<AdminUser> onToggleBan;
  final _UserSortField? activeSortField;
  final SortDirection? activeSortDirection;
  final void Function(_UserSortField, SortMenuAction) onSortSelected;

  static const double _colId = 90;
  static const double _colEmail = 210;
  static const double _colPhone = 130;
  static const double _colRole = 76;
  static const double _colStatus = 100;
  static const double _colAction = 90;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: Column(
          children: [
            _TableHeader(
              colId: _colId,
              colEmail: _colEmail,
              colPhone: _colPhone,
              colRole: _colRole,
              colStatus: _colStatus,
              colAction: _colAction,
              activeSortField: activeSortField,
              activeSortDirection: activeSortDirection,
              onSortSelected: onSortSelected,
            ),
            ...List.generate(
              users.length,
              (i) => _UserRow(
                user: users[i],
                isLast: i == users.length - 1,
                onToggleBan: () => onToggleBan(users[i]),
                colId: _colId,
                colEmail: _colEmail,
                colPhone: _colPhone,
                colRole: _colRole,
                colStatus: _colStatus,
                colAction: _colAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Table header ──────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.colId,
    required this.colEmail,
    required this.colPhone,
    required this.colRole,
    required this.colStatus,
    required this.colAction,
    required this.activeSortField,
    required this.activeSortDirection,
    required this.onSortSelected,
  });

  final double colId, colEmail, colPhone, colRole, colStatus, colAction;
  final _UserSortField? activeSortField;
  final SortDirection? activeSortDirection;
  final void Function(_UserSortField, SortMenuAction) onSortSelected;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    return Container(
      height: 46,
      color: AppColors.primaryLight.withValues(alpha: 0.13),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _Cell(
            width: colId,
            child: Text(
              'User ID',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _ExpandedCell(
            child: AdminTableSortHeader<_UserSortField>(
              label: 'Full Name',
              field: _UserSortField.fullName,
              activeSortField: activeSortField,
              activeSortDirection: activeSortDirection,
              onSelected: onSortSelected,
            ),
          ),
          _Cell(
            width: colEmail,
            child: Text('Email', style: style, overflow: TextOverflow.ellipsis),
          ),
          _Cell(
            width: colPhone,
            child: Text('Phone', style: style, overflow: TextOverflow.ellipsis),
          ),
          _Cell(
            width: colRole,
            child: Text('Role', style: style, overflow: TextOverflow.ellipsis),
          ),
          _Cell(
            width: colStatus,
            child: Text(
              'Status',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _Cell(
            width: colAction,
            child: Text(
              'Action',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data row ──────────────────────────────────────────────────────────────────

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
  final double colId, colEmail, colPhone, colRole, colStatus, colAction;

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.defaultAnimation,
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.primaryLight.withValues(alpha: 0.06)
              : AppColors.surface,
          border: widget.isLast
              ? null
              : Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            // User ID
            _Cell(
              width: widget.colId,
              child: Text(
                user.id,
                style: bodyStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Full Name — avatar + name
            Expanded(
              child: Row(
                children: [
                  _UserAvatar(username: user.fullName ?? user.username),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      user.fullName ?? user.username,
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
            _Cell(
              width: widget.colEmail,
              child: Text(
                user.email,
                style: bodyStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Phone
            _Cell(
              width: widget.colPhone,
              child: Text(
                user.phone,
                style: bodyStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Role
            _Cell(
              width: widget.colRole,
              child: Text(
                user.role.label,
                style: bodyStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Status badge — Align breaks the tight SizedBox constraint so the
            // Container inside AdminStatusBadge sizes to its content, not the
            // full column width.
            _Cell(
              width: widget.colStatus,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AdminStatusBadge(status: user.status),
              ),
            ),

            // Ban / Unban — same Align trick: AnimatedContainer sizes to its
            // padding + text, not to the full colAction SizedBox width.
            _Cell(
              width: widget.colAction,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _ActionButton(
                  isBanned: user.status == AdminUserStatus.banned,
                  onTap: widget.onToggleBan,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Layout helpers ────────────────────────────────────────────────────────────

/// Fixed-width table cell — aligns content identically in header and data rows.
class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

/// Flexible table cell for the username column.
class _ExpandedCell extends StatelessWidget {
  const _ExpandedCell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(child: child);
}

// ── User avatar ───────────────────────────────────────────────────────────────

/// 36 px circle avatar with a colour deterministically picked from a vivid
/// 8-colour palette, cycling by username length.
///
/// Colours span the full hue range so different users are easy to distinguish
/// at a glance. All are chosen to contrast well with white text.
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.username});

  final String username;

  static const List<Color> _palette = [
    AppColors.primary, // sky blue
    Color(0xFF22C55E), // green
    AppColors.primaryDark, // dark blue
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // violet
    Color(0xFFF97316), // orange
    AppColors.accent, // light blue
    Color(0xFF06B6D4), // cyan
  ];

  @override
  Widget build(BuildContext context) {
    final Color bg = _palette[username.length % _palette.length];
    final String initial = username.isNotEmpty
        ? username[0].toUpperCase()
        : '?';

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

/// Outlined pill: Ban (red) or Unban (primary blue).
/// Border at full opacity so the outline is clearly visible — matches target.
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
    final Color base = widget.isBanned
        ? AppColors.primary
        : const Color(0xFFEF4444);
    final String label = widget.isBanned ? 'Unban' : 'Ban';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.defaultAnimation,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? base.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            // Full-opacity border for a clearly visible outlined treatment
            border: Border.all(color: base.withValues(alpha: 0.85), width: 1.2),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: base,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Table footer ──────────────────────────────────────────────────────────────

/// Pagination footer row:
///   [Showing X to Y of Z users]  ·····  [<]  [1]  [2]  [>]
class _TableFooter extends StatelessWidget {
  const _TableFooter({
    required this.currentPage,
    required this.totalPages,
    required this.totalUsers,
    required this.pageSize,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int totalUsers;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final start = (currentPage - 1) * pageSize + 1;
    final end = min(currentPage * pageSize, totalUsers);

    return Row(
      children: [
        // Count label
        Text(
          'Showing $start to $end of $totalUsers users',
          style: Theme.of(context).textTheme.bodyMedium,
        ),

        const Spacer(),

        // Previous
        _PageNavButton(
          icon: Icons.chevron_left_rounded,
          enabled: currentPage > 1,
          onTap: () => onPageChanged(currentPage - 1),
        ),

        const SizedBox(width: 4),

        // Page number buttons
        ...List.generate(totalPages, (i) {
          final page = i + 1;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _PageNumberButton(
              page: page,
              isActive: page == currentPage,
              onTap: () => onPageChanged(page),
            ),
          );
        }),

        // Next
        _PageNavButton(
          icon: Icons.chevron_right_rounded,
          enabled: currentPage < totalPages,
          onTap: () => onPageChanged(currentPage + 1),
        ),
      ],
    );
  }
}

class _PageNavButton extends StatefulWidget {
  const _PageNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_PageNavButton> createState() => _PageNavButtonState();
}

class _PageNavButtonState extends State<_PageNavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: AppConstants.defaultAnimation,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _hovered && widget.enabled
                ? AppColors.primaryLight.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: widget.enabled
                ? AppColors.textPrimary
                : AppColors.textSecondary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _PageNumberButton extends StatefulWidget {
  const _PageNumberButton({
    required this.page,
    required this.isActive,
    required this.onTap,
  });

  final int page;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_PageNumberButton> createState() => _PageNumberButtonState();
}

class _PageNumberButtonState extends State<_PageNumberButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.defaultAnimation,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            // Active: solid primary — same treatment as selected filter chip
            color: widget.isActive
                ? AppColors.primary
                : _hovered
                ? AppColors.primaryLight.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${widget.page}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: widget.isActive
                    ? AppColors.textOnPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
