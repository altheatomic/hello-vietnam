import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

/// A single item in the Explore page (activity, cultural site, dish, product).
class ExploreItem {
  final String id;
  final String name;
  final String imagePath; // asset or network URL
  final String? subtitle;
  final DetailCategory category;

  const ExploreItem({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.category,
    this.subtitle,
  });

  factory ExploreItem.fromJson(Map<String, dynamic> json) {
    return ExploreItem(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String,
      category: _parseDetailCategory(
        json['category'] as String? ?? 'activities',
      ),
      subtitle: json['subtitle'] as String?,
    );
  }
}

DetailCategory _parseDetailCategory(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'culture':
      return DetailCategory.culture;
    case 'food':
      return DetailCategory.food;
    case 'local_products':
    case 'local product':
    case 'local products':
      return DetailCategory.localProducts;
    case 'activities':
    case 'activity':
    default:
      return DetailCategory.activities;
  }
}

/// A category section (e.g. "Activities") containing a description and items.
class ExploreCategory {
  final String id;
  final String title; // tab label: "Activities", "Culture", etc.
  final String description; // subtitle shown under the tab content
  final List<ExploreItem> items;

  const ExploreCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.items,
  });
}
