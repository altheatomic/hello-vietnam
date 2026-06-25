import 'detail_category.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';

class ItemDetailRequest {
  final String id;
  final String name;
  final DetailCategory category;
  final List<String> fallbackImages;
  final String? fallbackImagePath;
  final FavoriteType? favoriteType;
  final bool trackExploreBehavior;
  final String? exploreProvinceId;

  const ItemDetailRequest({
    required this.id,
    required this.name,
    required this.category,
    this.fallbackImages = const <String>[],
    this.fallbackImagePath,
    this.favoriteType,
    this.trackExploreBehavior = false,
    this.exploreProvinceId,
  });

  ItemDetailRequest copyWith({
    String? id,
    String? name,
    DetailCategory? category,
    List<String>? fallbackImages,
    String? fallbackImagePath,
    FavoriteType? favoriteType,
    bool? trackExploreBehavior,
    String? exploreProvinceId,
  }) {
    return ItemDetailRequest(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      fallbackImages: fallbackImages ?? this.fallbackImages,
      fallbackImagePath: fallbackImagePath ?? this.fallbackImagePath,
      favoriteType: favoriteType ?? this.favoriteType,
      trackExploreBehavior: trackExploreBehavior ?? this.trackExploreBehavior,
      exploreProvinceId: exploreProvinceId ?? this.exploreProvinceId,
    );
  }
}

class ItemDetail {
  final String id;
  final String name;
  final DetailCategory category;
  final List<String> images;
  final double rating;
  final bool isFavorite;
  final int reviewCount;
  final String ratingLabel;
  final String description;
  final String whatToExpect;
  final List<ItemReview> reviews;

  const ItemDetail({
    required this.id,
    required this.name,
    required this.category,
    required this.images,
    required this.rating,
    this.isFavorite = false,
    required this.reviewCount,
    required this.ratingLabel,
    required this.description,
    required this.whatToExpect,
    required this.reviews,
  });

  ItemDetail copyWith({
    String? id,
    String? name,
    DetailCategory? category,
    List<String>? images,
    double? rating,
    bool? isFavorite,
    int? reviewCount,
    String? ratingLabel,
    String? description,
    String? whatToExpect,
    List<ItemReview>? reviews,
  }) {
    return ItemDetail(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      images: images ?? this.images,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
      reviewCount: reviewCount ?? this.reviewCount,
      ratingLabel: ratingLabel ?? this.ratingLabel,
      description: description ?? this.description,
      whatToExpect: whatToExpect ?? this.whatToExpect,
      reviews: reviews ?? this.reviews,
    );
  }
}

class ItemReview {
  final String userName;
  final String date;
  final String ratingLabel;
  final double rating;
  final String comment;
  final List<String> thumbnails;

  const ItemReview({
    required this.userName,
    required this.date,
    required this.ratingLabel,
    this.rating = 5.0,
    required this.comment,
    this.thumbnails = const [],
  });
}
