import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/features/popular_apps/data/popular_apps_mock_data.dart';
import 'package:hellovietnam/features/popular_apps/domain/popular_apps_item.dart';
import 'package:hellovietnam/features/popular_apps/presentation/widgets/popular_apps_cart.dart';
import 'package:hellovietnam/features/popular_apps/presentation/widgets/popular_apps_category_tabs.dart';

class PopularAppsPage extends StatefulWidget {
  const PopularAppsPage({super.key});

  @override
  State<PopularAppsPage> createState() => _PopularAppsPageState();
}

class _PopularAppsPageState extends State<PopularAppsPage> {
  String selectedCategory = 'All';

  List<PopularAppsItem> get filteredItems {
    if (selectedCategory == 'All') return popularAppsItems;
    return popularAppsItems
        .where((PopularAppsItem item) => item.category == selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    final List<PopularAppsItem> items = filteredItems;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _DecorativeBackground()),
          CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: _Header(
                  topInset: topInset,
                  selectedCategory: selectedCategory,
                  onBack: () => context.pop(),
                  onCategorySelected: (String value) {
                    setState(() => selectedCategory = value);
                  },
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: _EmptyState(),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(26, 18, 26, 28),
                  sliver: SliverList.separated(
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == items.length) {
                        return const _InfoCard();
                      }

                      final PopularAppsItem item = items[index];
                      return PopularAppsCard(
                        item: item,
                        onTap: () => context.push('/popular-apps/${item.id}'),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.topInset,
    required this.selectedCategory,
    required this.onBack,
    required this.onCategorySelected,
  });

  final double topInset;
  final String selectedCategory;
  final VoidCallback onBack;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: topInset + 16, bottom: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF22D3EE),
            Color(0xFF60A5FA),
            Color(0xFF3B82F6),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: _RoundIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: onBack,
                  ),
                ),
                const Text(
                  'Popular Apps',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    shadows: <Shadow>[
                      Shadow(
                        color: Color(0x33000000),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Must-have apps for travelers in Vietnam 🇻🇳',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          PopularAppsCategoryTabs(
            categories: popularAppsCategories,
            selectedCategory: selectedCategory,
            onSelected: onCategorySelected,
          ),
        ],
      ),
    );
  }
}

class _DecorativeBackground extends StatelessWidget {
  const _DecorativeBackground();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const <Color>[
                  Color(0xFF020B10),
                  Color(0xFF0B1A22),
                  Color(0xFF0B2426),
                ]
              : const <Color>[
                  Color(0xFFEFF6FF),
                  Color(0xFFECFEFF),
                  Color(0xFFF0FDFA),
                ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          _BlurCircle(
            top: 80,
            right: -36,
            size: 128,
            color: const Color(0xFF22D3EE).withValues(alpha: 0.32),
          ),
          _BlurCircle(
            bottom: -30,
            left: -68,
            size: 192,
            color: const Color(0xFF60A5FA).withValues(alpha: 0.24),
          ),
          _BlurCircle(
            top: 420,
            right: -46,
            size: 112,
            color: const Color(0xFF14B8A6).withValues(alpha: 0.20),
          ),
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.size,
    required this.color,
  });

  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                const Color(0xFF22D3EE).withValues(alpha: 0.20),
                const Color(0xFF3B82F6).withValues(alpha: 0.14),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          ),
          child: Row(
            children: <Widget>[
              const Text('💡', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tip: install your key transport, payment, and communication apps before starting your trip.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(28),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('📱', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 12),
              Text(
                'No apps found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try selecting a different category',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.76),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 19, color: const Color(0xFF334155)),
      ),
    );
  }
}
