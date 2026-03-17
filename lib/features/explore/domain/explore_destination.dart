class ExploreDestination {
  final String id;
  final String name;
  final String country;
  final List<String> imageUrls;
  final double rating;
  final int reviews;
  final double distance; // in kilometers
  final String checkIn;
  final String checkOut;
  final double pricePerNight;
  final String category; // Beach, Islands, Amazing pools, etc.
  final bool isFavorite;

  ExploreDestination({
    required this.id,
    required this.name,
    required this.country,
    required this.imageUrls,
    required this.rating,
    required this.reviews,
    required this.distance,
    required this.checkIn,
    required this.checkOut,
    required this.pricePerNight,
    required this.category,
    this.isFavorite = false,
  });

  ExploreDestination copyWith({
    String? id,
    String? name,
    String? country,
    List<String>? imageUrls,
    double? rating,
    int? reviews,
    double? distance,
    String? checkIn,
    String? checkOut,
    double? pricePerNight,
    String? category,
    bool? isFavorite,
  }) {
    return ExploreDestination(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      imageUrls: imageUrls ?? this.imageUrls,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      distance: distance ?? this.distance,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      pricePerNight: pricePerNight ?? this.pricePerNight,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
