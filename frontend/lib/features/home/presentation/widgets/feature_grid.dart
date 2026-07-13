import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/language/app_language.dart';
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
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 10,
        mainAxisExtent: 84,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color containerColor = isDark
        ? AppColors.primaryLight.withValues(alpha: 0.11)
        : AppColors.primaryLight.withValues(alpha: 0.25);
    final Color borderColor = isDark
        ? AppColors.primaryLight.withValues(alpha: 0.12)
        : AppColors.primaryLight.withValues(alpha: 0.15);
    final Color labelColor = isDark
        ? AppColors.primaryLight
        : AppColors.primary;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              if (item.route == AppRoutes.tripPlanner ||
                  item.route == AppRoutes.messages) {
                context.go(item.route);
                return;
              }
              context.push(item.route);
            },
            child: Container(
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      context.l10n.featureLabelForRoute(item.route),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (item.route == AppRoutes.tripPlanner)
          Positioned(
            top: -6,
            left: -6,
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.tripPlannerSaved),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF102A36) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isDark ? AppColors.primaryLight : AppColors.primary)
                        .withValues(alpha: 0.2),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.24 : 0.08,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.bookmark_added_rounded,
                  size: 16,
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
