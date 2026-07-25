import 'package:hellovietnam/features/city_detail/domain/city_detail_models.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/recommend/data/recommend_mock_data.dart';
import 'package:hellovietnam/features/recommend/domain/recommend_destination.dart';

CityDetailData resolveCityDetail(CityDetailRequest request) {
  final destination =
      _findDestination(request) ?? _buildFallbackDestination(request);

  return CityDetailData(
    detail: ItemDetail(
      id: destination.id,
      name: destination.name,
      category: DetailCategory.culture,
      images: _buildImages(destination, request),
      rating:
          request.fallbackRating ??
          destination.avgRating ??
          destination.rating,
      reviewCount: _reviewCountFor(destination.name),
      ratingLabel: _ratingLabelFor(
        request.fallbackRating ?? destination.avgRating ?? destination.rating,
      ),
      description: destination.description,
      whatToExpect: destination.highlights.isNotEmpty
          ? destination.highlights
          : _defaultWhatToExpect(destination.name),
      reviews: _buildCityReviews(destination.name),
    ),
    bestTimeTitle: destination.bestTimeTitle.isNotEmpty
        ? destination.bestTimeTitle
        : 'Year-round',
    bestTimeDetails: destination.bestTimeDetails.isNotEmpty
        ? destination.bestTimeDetails
        : _defaultBestTimeDetails(destination.name),
  );
}

RecommendDestination? _findDestination(CityDetailRequest request) {
  final normalizedName = _normalize(request.name);

  for (final destination in mockRecommendDestinations) {
    if (_normalize(destination.name) == normalizedName) {
      return destination;
    }
  }

  for (final destination in mockRecommendDestinations) {
    if (destination.id == request.id) {
      return destination;
    }
  }

  return null;
}

RecommendDestination _buildFallbackDestination(CityDetailRequest request) {
  return RecommendDestination(
    id: request.id,
    name: request.name,
    shortDescription:
        '${request.name} is a memorable stop full of local charm.',
    description:
        '${request.name} offers a balanced mix of local culture, everyday life, and memorable sights for travelers exploring Vietnam.',
    imagePath: request.fallbackImagePath ?? '',
    rating: request.fallbackRating ?? 4.5,
    tags: const <String>['Culture', 'Local Life', 'Sightseeing'],
    bestTimeTitle: 'Best enjoyed in the dry and mild months',
    bestTimeDetails: _defaultBestTimeDetails(request.name),
    highlights: _defaultWhatToExpect(request.name),
    gallery: request.fallbackImages,
    bestMonths: const <int>[],
  );
}

List<String> _buildImages(
  RecommendDestination destination,
  CityDetailRequest request,
) {
  final imagePool = <String>[
    ...request.fallbackImages,
    if (request.fallbackImagePath != null) request.fallbackImagePath!,
    destination.imagePath,
    ...destination.gallery,
  ];

  final cleaned = <String>[];
  for (final image in imagePool) {
    final trimmed = image.trim();
    if (trimmed.isEmpty || cleaned.contains(trimmed)) {
      continue;
    }
    cleaned.add(trimmed);
  }

  if (cleaned.isNotEmpty) {
    return cleaned;
  }

  return const <String>['', '', ''];
}

String _normalize(String value) {
  return value.toLowerCase().trim();
}

int _reviewCountFor(String cityName) {
  return 180 + (cityName.length * 18);
}

String _ratingLabelFor(double rating) {
  if (rating >= 4.8) {
    return 'Fantastic';
  }
  if (rating >= 4.5) {
    return 'Amazing';
  }
  if (rating >= 4.2) {
    return 'Great';
  }
  return 'Good';
}

String _defaultWhatToExpect(String cityName) {
  return '$cityName rewards slow exploration with a mix of local flavors, scenic corners, and cultural moments that feel distinctly Vietnamese.';
}

List<String> _defaultBestTimeDetails(String cityName) {
  return <String>[
    'Comfortable weather makes it easier to explore $cityName on foot.',
    'Clearer days are best for sightseeing, photography, and local food stops.',
    'Plan early-morning or late-afternoon outings for the most pleasant experience.',
  ];
}

List<ItemReview> _buildCityReviews(String cityName) {
  return <ItemReview>[
    ItemReview(
      userName: 'Minh',
      date: '06/01/2026',
      ratingLabel: 'Fantastic',
      rating: 5.0,
      comment:
          '$cityName felt lively and easy to explore. The mix of landmarks, food, and local neighborhoods made the visit feel full without being rushed.',
    ),
    ItemReview(
      userName: 'Anna',
      date: '19/01/2026',
      ratingLabel: 'Amazing',
      rating: 4.9,
      comment:
          'I especially liked how $cityName offered both iconic sights and quieter moments away from the busiest areas.',
    ),
    ItemReview(
      userName: 'Khoa',
      date: '08/02/2026',
      ratingLabel: 'Great',
      rating: 4.7,
      comment:
          'The best part of $cityName was how much there was to do in a single day, from food stops to cultural places and evening views.',
    ),
    ItemReview(
      userName: 'Sana',
      date: '27/02/2026',
      ratingLabel: 'Fantastic',
      rating: 5.0,
      comment:
          '$cityName is a place I would gladly revisit. It felt welcoming, photogenic, and very easy to recommend to first-time visitors.',
    ),
  ];
}
