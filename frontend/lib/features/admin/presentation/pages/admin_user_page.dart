import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';

import '../../data/admin_user_repository.dart';
import '../../domain/admin_user.dart';
import '../widgets/admin_search_filter_bar.dart';
import '../widgets/admin_section_header.dart';
import '../widgets/admin_status_badge.dart';
import '../widgets/admin_table_sort_header.dart';
import '../widgets/admin_user_form_dialog.dart';

enum _UserSortField { fullName }

class AdminUserPage extends StatefulWidget {
  const AdminUserPage({super.key, this.repository});

  final AdminUserRepository? repository;

  @override
  State<AdminUserPage> createState() => _AdminUserPageState();
}

class _AdminUserPageState extends State<AdminUserPage> {
  late final AdminUserRepository _repository =
      widget.repository ?? AdminUserRepository();
  final List<AdminUser> _users = <AdminUser>[];

  final TextEditingController _searchController = TextEditingController();
  AdminUserStatus? _filterStatus;
  _UserSortField? _activeSortField;
  SortDirection? _activeSortDirection;
  int _currentPage = 1;
  bool _isLoading = true;
  bool _isMutating = false;
  String? _loadError;

  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

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

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final List<AdminUser> users = await _repository.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users
          ..clear()
          ..addAll(users);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Khong the tai danh sach user. $error';
      });
    }
  }

  List<AdminUser> get _filteredUsers {
    final String query = _searchController.text.toLowerCase().trim();
    final List<AdminUser> result = _users.where((AdminUser user) {
      final bool matchesSearch =
          query.isEmpty ||
          (user.fullName ?? user.username).toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.id.contains(query);
      final bool matchesStatus =
          _filterStatus == null || user.status == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList()..sort((AdminUser a, AdminUser b) => a.id.compareTo(b.id));

    if (_activeSortField == null || _activeSortDirection == null) {
      return result;
    }

    result.sort((AdminUser a, AdminUser b) {
      final String va = (a.fullName ?? a.username).toLowerCase();
      final String vb = (b.fullName ?? b.username).toLowerCase();
      final int cmp = va.compareTo(vb);
      if (cmp != 0) {
        return _activeSortDirection == SortDirection.ascending ? cmp : -cmp;
      }
      return a.id.compareTo(b.id);
    });
    return result;
  }

  List<AdminUser> get _pagedUsers {
    final List<AdminUser> all = _filteredUsers;
    final int start = (_currentPage - 1) * _pageSize;
    final int end = min(start + _pageSize, all.length);
    if (start >= all.length) return <AdminUser>[];
    return all.sublist(start, end);
  }

  int get _totalPages => (_filteredUsers.length / _pageSize)
      .ceil()
      .clamp(1, double.maxFinite)
      .toInt();

  Future<void> _exportUsers() async {
    final List<String> rows = <String>['id_user,Full name,Phone,Email'];
    String esc(String value) => value.contains(',') || value.contains('"')
        ? '"${value.replaceAll('"', '""')}"'
        : value;

    for (final AdminUser user in _users) {
      rows.add(
        <String>[
          esc(user.id),
          esc(user.fullName ?? user.username),
          esc(user.phone),
          esc(user.email),
        ].join(','),
      );
    }

    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User CSV copied to clipboard.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openAddUser() async {
    final AdminUser? newUser = await showDialog<AdminUser>(
      context: context,
      builder: (_) => const AdminUserFormDialog(),
    );
    if (newUser == null || !mounted) return;

    setState(() => _isMutating = true);
    try {
      final AdminUser createdUser = await _repository.createUser(
        fullName: newUser.fullName ?? newUser.username,
        username: newUser.username,
        email: newUser.email,
        phone: newUser.phone,
        role: newUser.role,
      );
      if (!mounted) return;
      setState(() {
        _users.insert(0, createdUser);
        _currentPage = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${createdUser.username} has been added.'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Add user failed: $error'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _toggleBan(AdminUser user) async {
    setState(() => _isMutating = true);
    try {
      final AdminUserStatus nextStatus = await _repository.toggleStatus(user);
      if (!mounted) return;

      setState(() {
        final int index = _users.indexWhere((AdminUser item) => item.id == user.id);
        if (index == -1) return;
        _users[index] = _users[index].copyWith(status: nextStatus);
      });

      final String verb =
          nextStatus == AdminUserStatus.banned ? 'banned' : 'unbanned';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.username} has been $verb.'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update status failed: $error'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<AdminUser> filtered = _filteredUsers;
    final List<AdminUser> paged = _pagedUsers;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdminSectionHeader(
            title: 'User Manager',
            subtitle: 'View, search, and manage registered users',
            trailing: _HeaderActions(
              onExport: _exportUsers,
              onAddUser: _isMutating ? null : _openAddUser,
            ),
          ),
          AdminSearchFilterBar(
            controller: _searchController,
            filterStatus: _filterStatus,
            onFilterStatusChanged: _onFilterStatusChanged,
            onSearchChanged: _onSearchChanged,
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            EmptyState(icon: Icons.cloud_off_rounded, message: _loadError!)
          else if (filtered.isEmpty)
            const EmptyState(
              icon: Icons.people_outline_rounded,
              message: 'No users match your search.',
            )
          else ...<Widget>[
            _UserTable(
              users: paged,
              onToggleBan: _isMutating ? null : _toggleBan,
              activeSortField: _activeSortField,
              activeSortDirection: _activeSortDirection,
              onSortSelected: _onSortSelected,
            ),
            const SizedBox(height: 16),
            _TableFooter(
              currentPage: _currentPage,
              totalPages: _totalPages,
              totalUsers: filtered.length,
              pageSize: _pageSize,
              onPageChanged: (int page) => setState(() => _currentPage = page),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({required this.onExport, required this.onAddUser});

  final VoidCallback onExport;
  final VoidCallback? onAddUser;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
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

class _UserTable extends StatelessWidget {
  const _UserTable({
    required this.users,
    required this.onToggleBan,
    required this.activeSortField,
    required this.activeSortDirection,
    required this.onSortSelected,
  });

  final List<AdminUser> users;
  final ValueChanged<AdminUser>? onToggleBan;
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
        boxShadow: <BoxShadow>[
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
          children: <Widget>[
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
            ...List<Widget>.generate(
              users.length,
              (int index) => _UserRow(
                user: users[index],
                isLast: index == users.length - 1,
                onToggleBan: onToggleBan == null
                    ? null
                    : () => onToggleBan!(users[index]),
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

  final double colId;
  final double colEmail;
  final double colPhone;
  final double colRole;
  final double colStatus;
  final double colAction;
  final _UserSortField? activeSortField;
  final SortDirection? activeSortDirection;
  final void Function(_UserSortField, SortMenuAction) onSortSelected;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.labelMedium;
    return Container(
      height: 46,
      color: AppColors.primaryLight.withValues(alpha: 0.13),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: <Widget>[
          _Cell(
            width: colId,
            child: Text('User ID', style: style, overflow: TextOverflow.ellipsis),
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
            child: Text('Status', style: style, overflow: TextOverflow.ellipsis),
          ),
          _Cell(
            width: colAction,
            child: Text('Action', style: style, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

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
  final VoidCallback? onToggleBan;
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
    final AdminUser user = widget.user;
    final TextStyle? bodyStyle = Theme.of(context).textTheme.bodyMedium;

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
          children: <Widget>[
            _Cell(
              width: widget.colId,
              child: Text(user.id, style: bodyStyle, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              child: Row(
                children: <Widget>[
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
            _Cell(
              width: widget.colEmail,
              child: Text(
                user.email,
                style: bodyStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _Cell(
              width: widget.colPhone,
              child: Text(
                user.phone,
                style: bodyStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _Cell(
              width: widget.colRole,
              child: Text(
                user.role.label,
                style: bodyStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _Cell(
              width: widget.colStatus,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AdminStatusBadge(status: user.status),
              ),
            ),
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

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

class _ExpandedCell extends StatelessWidget {
  const _ExpandedCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(child: child);
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.username});

  final String username;

  static const List<Color> _palette = <Color>[
    AppColors.primary,
    Color(0xFF22C55E),
    AppColors.primaryDark,
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFF97316),
    AppColors.accent,
    Color(0xFF06B6D4),
  ];

  @override
  Widget build(BuildContext context) {
    final Color background = _palette[username.length % _palette.length];
    final String initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
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

class _ActionButton extends StatefulWidget {
  const _ActionButton({required this.isBanned, required this.onTap});

  final bool isBanned;
  final VoidCallback? onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.isBanned
        ? AppColors.primary
        : const Color(0xFFEF4444);
    final String label = widget.isBanned ? 'Unban' : 'Ban';

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.defaultAnimation,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered && widget.onTap != null
                ? baseColor.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            border: Border.all(
              color: baseColor.withValues(
                alpha: widget.onTap == null ? 0.35 : 0.85,
              ),
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: widget.onTap == null
                  ? baseColor.withValues(alpha: 0.45)
                  : baseColor,
            ),
          ),
        ),
      ),
    );
  }
}

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
    final int start = (currentPage - 1) * pageSize + 1;
    final int end = min(currentPage * pageSize, totalUsers);

    return Row(
      children: <Widget>[
        Text(
          'Showing $start to $end of $totalUsers users',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        _PageNavButton(
          icon: Icons.chevron_left_rounded,
          enabled: currentPage > 1,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        const SizedBox(width: 4),
        ...List<Widget>.generate(totalPages, (int index) {
          final int page = index + 1;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _PageNumberButton(
              page: page,
              isActive: page == currentPage,
              onTap: () => onPageChanged(page),
            ),
          );
        }),
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
