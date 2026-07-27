/// Represents a Vietnamese dish shown in the "Best Dishes" section.
class Dish {
  final String id;
  final String name;
  final String category;
  final double? rating;
  final int reviewCount;
  final String imagePath;  // asset or network URL
  final bool isFavorite;

  const Dish({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    this.reviewCount = 0,
    required this.imagePath,
    this.isFavorite = false,
  });

  /// Ready for future API integration – plug your JSON shape here.
  factory Dish.fromJson(Map<String, dynamic> json) {
    return Dish(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      imagePath: json['image_path']?.toString() ?? '',
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }
}
