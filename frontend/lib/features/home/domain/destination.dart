/// Represents a travel destination shown in the "Best Destination" section.
class Destination {
  final String id;
  final String name;
  final String category;
  final double? rating;
  final int reviewCount;
  final String imagePath;  // asset or network URL
  final bool isFavorite;

  /// Real translated description (e.g. description_en) from the backend,
  /// when available.
  final String? description;

  const Destination({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    this.reviewCount = 0,
    required this.imagePath,
    this.isFavorite = false,
    this.description,
  });

  /// Ready for future API integration – plug your JSON shape here.
  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      imagePath: json['image_path']?.toString() ?? '',
      isFavorite: json['is_favorite'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }
}
