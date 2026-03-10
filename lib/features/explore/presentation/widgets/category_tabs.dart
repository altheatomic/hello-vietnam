import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';

class CategoryTabs extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const CategoryTabs({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  State<CategoryTabs> createState() => _CategoryTabsState();
}

class _CategoryTabsState extends State<CategoryTabs> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(
          widget.categories.length,
          (index) {
            final category = widget.categories[index];
            final isSelected = category == widget.selectedCategory;

            return Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 16 : 8,
                right: index == widget.categories.length - 1 ? 16 : 8,
              ),
              child: GestureDetector(
                onTap: () {
                  widget.onCategorySelected(category);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? AppColors.textPrimary 
                      : Colors.white,
                    border: Border.all(
                      color: isSelected 
                        ? AppColors.textPrimary 
                        : AppColors.divider,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected 
                        ? Colors.white 
                        : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
