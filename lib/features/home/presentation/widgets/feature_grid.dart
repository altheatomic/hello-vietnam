import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import '../../domain/feature_item.dart';

/// A 2 × 4 grid of quick-action feature buttons.
///
/// Each button shows an icon and label text INSIDE a rounded blue box,
/// with white icon/text on a light-blue background.
class FeatureGrid extends StatelessWidget {
  const FeatureGrid({super.key, required this.items});

  final List<FeatureItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _FeatureButton(item: item);
      },
    );
  }
}

class _FeatureButton extends StatelessWidget {
  const _FeatureButton({required this.item});
  final FeatureItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (item.route == AppRoutes.tripPlanner) {
          context.go(item.route);
          return;
        }
        context.push(item.route);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryLight.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 6),
            // Label text inside the box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
