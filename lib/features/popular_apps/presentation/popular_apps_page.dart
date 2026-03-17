import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
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
  String selectedCategory = 'ALL';

  List<PopularAppsItem> get filteredItems {
    if (selectedCategory == 'ALL') return popularAppsItems;
    if (selectedCategory == 'MORE') {
      return popularAppsItems
          .where(
            (item) =>
                item.category != 'TRANSPORT' &&
                item.category != 'CHAT' &&
                item.category != 'PAYMENT',
          )
          .toList();
    }
    return popularAppsItems
        .where((item) => item.category == selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                topPadding + 8,
                AppConstants.pagePadding,
                8,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => context.pop(),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Popular Apps in VN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PopularAppsCategoryTabs(
                    categories: popularAppsCategories,
                    selectedCategory: selectedCategory,
                    onSelected: (value) {
                      setState(() => selectedCategory = value);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: filteredItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return PopularAppsCard(
                    item: item,
                    onTap: () => context.push('/popular-apps/${item.id}'),
                  );
                },
              ),
            ),
          ],
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD6DCE5)),
          color: Colors.white.withValues(alpha: 0.7),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}
