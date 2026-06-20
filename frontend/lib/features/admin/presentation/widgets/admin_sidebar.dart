import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:hellovietnam/core/config/app_constants.dart';

/// Fixed-width left navigation rail for the admin shell.
///
/// Visual zones:
///   1. Brand area   — primaryLight header with accentGold title, mirroring
///                     the Home / AppScaffold header treatment.
///   2. Nav items    — top-level Dashboard + Management group.
///   3. Sign-out     — pinned to the bottom.
class AdminSidebar extends StatefulWidget {
  const AdminSidebar({super.key, required this.currentPath});

  final String currentPath;

  static const double width = 240;

  static const _topItems = [
    _NavDestination(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      route: '/admin/dashboard',
    ),
  ];

  static const _managementItems = [
    _NavDestination(
      label: 'User',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      route: '/admin/users',
    ),
    /*_NavDestination(
      label: 'Canned Replies',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      route: '/admin/canned-replies',
    ),*/
    _NavDestination(
      label: 'Report',
      icon: Icons.flag_outlined,
      selectedIcon: Icons.flag_rounded,
      route: '/admin/reports',
    ),
    _NavDestination(
      label: 'Food',
      icon: Icons.restaurant_outlined,
      selectedIcon: Icons.restaurant_rounded,
      route: '/admin/food',
    ),
    _NavDestination(
      label: 'Popular Apps',
      icon: Icons.apps_outlined,
      selectedIcon: Icons.apps_rounded,
      route: '/admin/popular-apps',
    ),
    _NavDestination(
      label: 'CF Retrain',
      icon: Icons.model_training_outlined,
      selectedIcon: Icons.model_training_rounded,
      route: '/admin/cf-retrain',
    ),
  ];

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  String? _pendingRoute;

  @override
  void didUpdateWidget(covariant AdminSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pendingRoute = _pendingRoute;
    if (pendingRoute == null) {
      return;
    }
    if (_matches(widget.currentPath, pendingRoute)) {
      _pendingRoute = null;
      return;
    }
    if (widget.currentPath != oldWidget.currentPath) {
      _pendingRoute = null;
    }
  }

  bool _matches(String currentPath, String route) =>
      currentPath == route || currentPath.startsWith('$route/');

  bool _isActive(String route) {
    final activePath = _pendingRoute ?? widget.currentPath;
    return _matches(activePath, route);
  }

  void _navigate(String route) {
    if (_matches(widget.currentPath, route)) {
      return;
    }
    setState(() => _pendingRoute = route);
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AdminSidebar.width,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.adminSidebar,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Zone 1: Brand ─────────────────────────────────────
          const _BrandZone(),

          const SizedBox(height: 8),

          // ── Zone 2: Nav items ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: AdminSidebar._topItems
                  .map(
                    (d) => _NavItem(
                      key: ValueKey<String>(d.route),
                      destination: d,
                      isActive: _isActive(d.route),
                      onTap: () => _navigate(d.route),
                    ),
                  )
                  .toList(),
            ),
          ),

          _SectionLabel(label: 'MANAGEMENT'),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: AdminSidebar._managementItems
                  .map(
                    (d) => _NavItem(
                      key: ValueKey<String>(d.route),
                      destination: d,
                      isActive: _isActive(d.route),
                      onTap: () => _navigate(d.route),
                    ),
                  )
                  .toList(),
            ),
          ),

          const Spacer(),

          // ── Zone 3: Sign out ───────────────────────────────────
          _SignOutButton(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Brand zone ──────────────────────────────────────────────────────────────

class _BrandZone extends StatelessWidget {
  const _BrandZone();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Hello Vietnam',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.starColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Section group label ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          letterSpacing: 0.8,
          color: Colors.white70,
        ),
      ),
    );
  }
}

// ── Nav item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  const _NavItem({
    super.key,
    required this.destination,
    required this.isActive,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;

    final Color bgColor;
    if (isActive) {
      // Active tile: matches FeatureGrid tile tint (primaryLight 25%)
      bgColor = AppColors.primary.withValues(alpha: 0.25);
    } else if (_hovered) {
      bgColor = AppColors.primaryLight.withValues(alpha: 0.10);
    } else {
      bgColor = Colors.transparent;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Center(
                  child: Icon(
                    widget.destination.icon,
                    size: 20,
                    color: isActive ? AppColors.surface : Color(0xFFE3F2FD),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.destination.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.surface : Color(0xFFE3F2FD),
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

// ── Sign-out button ──────────────────────────────────────────────────────────

class _SignOutButton extends StatefulWidget {
  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () async {
          await AuthRepository.instance.signOut();
          if (context.mounted) context.go('/login');
        },
        child: AnimatedContainer(
          duration: AppConstants.defaultAnimation,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.red.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 20,
                color: _hovered ? Colors.redAccent : Color(0xFFE3F2FD),
              ),
              const SizedBox(width: 10),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _hovered ? Colors.redAccent : Color(0xFFE3F2FD),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────────────────

class _NavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
}
