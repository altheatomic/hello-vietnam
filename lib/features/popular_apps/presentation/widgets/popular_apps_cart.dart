import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/popular_apps/domain/popular_apps_item.dart';

class PopularAppsCard extends StatelessWidget {
  const PopularAppsCard({super.key, required this.item, required this.onTap});

  final PopularAppsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: _logoBackground(item.id),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                item.logo,
                style: TextStyle(
                  color: _logoForeground(item.id),
                  fontWeight: FontWeight.w800,
                  fontSize: item.logo.length > 1 ? 34 : 42,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 104,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: item.badgeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _prettyCategory(item.category),
                            style: TextStyle(
                              color: item.badgeTextColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _prettyCategory(String category) {
    switch (category) {
      case 'TRANSPORT':
        return 'Transport';
      case 'CHAT':
        return 'Chat';
      case 'PAYMENT':
        return 'Payment';
      default:
        return category;
    }
  }

  static Color _logoBackground(String id) {
    switch (id) {
      case 'grab':
        return const Color(0xFF07B53B);
      case 'zalo':
        return Colors.white;
      case 'momo':
        return const Color(0xFFA50064);
      case 'be':
        return const Color(0xFFFFCC00);
      default:
        return AppColors.primaryLight;
    }
  }

  static Color _logoForeground(String id) {
    switch (id) {
      case 'grab':
        return Colors.white;
      case 'zalo':
        return const Color(0xFF1868F2);
      case 'momo':
        return Colors.white;
      case 'be':
        return const Color(0xFF1565C0);
      default:
        return AppColors.textPrimary;
    }
  }
}
