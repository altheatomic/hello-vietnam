import 'detail_category.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

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
  final String? reviewContentId;
  final String name;
  final DetailCategory category;
  final List<String> images;
  final double rating;
  final bool isFavorite;
  final int reviewCount;
  final String ratingLabel;
  final String description;
  final String whatToExpect;

  const ItemDetail({
    required this.id,
    this.reviewContentId,
    required this.name,
    required this.category,
    required this.images,
    required this.rating,
    this.isFavorite = false,
    required this.reviewCount,
    required this.ratingLabel,
    required this.description,
    required this.whatToExpect,
  });

  String get effectiveReviewContentId => reviewContentId ?? id;

  bool get hasReviewTarget =>
      (reviewContentId != null && reviewContentId!.trim().isNotEmpty) ||
      _uuidPattern.hasMatch(id);

  ItemDetail copyWith({
    String? id,
    String? reviewContentId,
    String? name,
    DetailCategory? category,
    List<String>? images,
    double? rating,
    bool? isFavorite,
    int? reviewCount,
    String? ratingLabel,
    String? description,
    String? whatToExpect,
  }) {
    return ItemDetail(
      id: id ?? this.id,
      reviewContentId: reviewContentId ?? this.reviewContentId,
      name: name ?? this.name,
      category: category ?? this.category,
      images: images ?? this.images,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
      reviewCount: reviewCount ?? this.reviewCount,
      ratingLabel: ratingLabel ?? this.ratingLabel,
      description: description ?? this.description,
      whatToExpect: whatToExpect ?? this.whatToExpect,
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
