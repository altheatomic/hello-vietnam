import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_HomeNavItem>[
      _HomeNavItem(
        title: 'Explore',
        subtitle: 'Khám phá địa điểm & gợi ý',
        icon: Icons.explore_outlined,
        route: AppRoutes.explore,
      ),
      _HomeNavItem(
        title: 'Forum',
        subtitle: 'Cộng đồng hỏi đáp',
        icon: Icons.forum_outlined,
        route: AppRoutes.forum,
      ),
      _HomeNavItem(
        title: 'Popular Phrases',
        subtitle: 'Câu phổ biến (du lịch/giao tiếp)',
        icon: Icons.translate_outlined,
        route: AppRoutes.phrases,
      ),
      _HomeNavItem(
        title: 'AI Search',
        subtitle: 'Tìm kiếm bằng AI',
        icon: Icons.auto_awesome_outlined,
        route: AppRoutes.aiSearch,
      ),
      _HomeNavItem(
        title: 'Wish List',
        subtitle: 'Danh sách muốn đi / muốn làm',
        icon: Icons.favorite_border,
        route: AppRoutes.wishlist,
      ),
      _HomeNavItem(
        title: 'Recommend',
        subtitle: 'Gợi ý theo sở thích',
        icon: Icons.recommend_outlined,
        route: AppRoutes.recommend,
      ),
      _HomeNavItem(
        title: 'Popular Apps',
        subtitle: 'App hữu ích cho du lịch VN',
        icon: Icons.apps_outlined,
        route: AppRoutes.popularApps,
      ),
      _HomeNavItem(
        title: 'Send Feedback',
        subtitle: 'Góp ý / báo lỗi',
        icon: Icons.feedback_outlined,
        route: AppRoutes.feedback,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hello Vietnam'),
        actions: [
          IconButton(
            tooltip: 'Wish List',
            onPressed: () => context.push(AppRoutes.wishlist),
            icon: const Icon(Icons.favorite_border),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            child: ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(item.route),
            ),
          );
        },
      ),
    );
  }
}

class _HomeNavItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  const _HomeNavItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}
