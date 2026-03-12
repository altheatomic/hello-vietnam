/// A single item in the Explore page (activity, cultural site, dish, product).
class ExploreItem {
  final String id;
  final String name;
  final String imagePath; // asset or network URL
  final String? subtitle;

  const ExploreItem({
    required this.id,
    required this.name,
    required this.imagePath,
    this.subtitle,
  });

  factory ExploreItem.fromJson(Map<String, dynamic> json) {
    return ExploreItem(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String,
      subtitle: json['subtitle'] as String?,
    );
  }
}

/// A category section (e.g. "Activities") containing a description and items.
class ExploreCategory {
  final String id;
  final String title;       // tab label: "Activities", "Culture", etc.
  final String description; // subtitle shown under the tab content
  final List<ExploreItem> items;

  const ExploreCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.items,
  });
}
