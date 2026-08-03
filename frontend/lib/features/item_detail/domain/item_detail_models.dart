import 'detail_category.dart';
import 'package:hellovietnam/features/data_freshness/domain/content_freshness_models.dart';
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
  final String? coverImage;
  final List<String> galleryImages;
  final double rating;
  final bool isFavorite;
  final int reviewCount;
  final String ratingLabel;
  final String description;
  final String whatToExpect;
  final List<ItemReview> reviews;
  final ContentFreshnessInfo? freshnessInfo;

  const ItemDetail({
    required this.id,
    this.reviewContentId,
    required this.name,
    required this.category,
    required this.images,
    this.coverImage,
    this.galleryImages = const <String>[],
    required this.rating,
    this.isFavorite = false,
    required this.reviewCount,
    required this.ratingLabel,
    required this.description,
    required this.whatToExpect,
    this.reviews = const <ItemReview>[],
    this.freshnessInfo,
  });

  String get effectiveReviewContentId => reviewContentId ?? id;

  bool get hasReviewTarget =>
      (reviewContentId != null && reviewContentId!.trim().isNotEmpty) ||
      _uuidPattern.hasMatch(id);

  List<String> get effectiveHeroImages {
    final String? cover = coverImage?.trim();
    if (cover != null && cover.isNotEmpty) return <String>[cover];
    return images.take(1).toList(growable: false);
  }

  List<String> get effectiveGalleryImages {
    if (coverImage != null) return galleryImages;
    if (galleryImages.isNotEmpty) return galleryImages;
    if (images.length > 1) return images.skip(1).toList(growable: false);
    return images;
  }

  ItemDetail copyWith({
    String? id,
    String? reviewContentId,
    String? name,
    DetailCategory? category,
    List<String>? images,
    String? coverImage,
    List<String>? galleryImages,
    double? rating,
    bool? isFavorite,
    int? reviewCount,
    String? ratingLabel,
    String? description,
    String? whatToExpect,
    List<ItemReview>? reviews,
    ContentFreshnessInfo? freshnessInfo,
  }) {
    return ItemDetail(
      id: id ?? this.id,
      reviewContentId: reviewContentId ?? this.reviewContentId,
      name: name ?? this.name,
      category: category ?? this.category,
      images: images ?? this.images,
      coverImage: coverImage ?? this.coverImage,
      galleryImages: galleryImages ?? this.galleryImages,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
      reviewCount: reviewCount ?? this.reviewCount,
      ratingLabel: ratingLabel ?? this.ratingLabel,
      description: description ?? this.description,
      whatToExpect: whatToExpect ?? this.whatToExpect,
      reviews: reviews ?? this.reviews,
      freshnessInfo: freshnessInfo ?? this.freshnessInfo,
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
