/// Represents a travel destination shown in the "Best Destination" section.
class Destination {
  final String id;
  final String name;
  final String category;
  final double rating;
  final String imagePath;  // asset or network URL
  final bool isFavorite;

  const Destination({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.imagePath,
    this.isFavorite = false,
  });

  /// Ready for future API integration – plug your JSON shape here.
  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      rating: (json['rating'] as num).toDouble(),
      imagePath: json['image_path'] as String,
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }
}
