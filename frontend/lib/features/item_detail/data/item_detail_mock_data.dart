import '../domain/detail_category.dart';
import '../domain/item_detail_models.dart';

ItemDetail resolveItemDetail(ItemDetailRequest request) {
  final detailKey = '${request.category.storageKey}:${request.id}';
  final detail = _mockDetails[detailKey] ?? _defaultDetail(request);
  return detail.copyWith(
    images: _sanitizeImages(
      detail.images,
      fallbackImages: request.fallbackImages,
      fallbackImagePath: request.fallbackImagePath,
    ),
  );
}

ItemDetail _defaultDetail(ItemDetailRequest request) {
  final categoryLabel = request.category.label.toLowerCase();
  return ItemDetail(
    id: request.id,
    name: request.name,
    category: request.category,
    images: _sanitizeImages(
      const <String>[],
      fallbackImages: request.fallbackImages,
      fallbackImagePath: request.fallbackImagePath,
    ),
    rating: 4.5,
    isFavorite: false,
    reviewCount: 120,
    ratingLabel: 'Great',
    description:
        'Explore and discover the beauty of ${request.name}. '
        'This $categoryLabel highlight offers a memorable way to experience Vietnam.',
    whatToExpect:
        'Visiting ${request.name} gives travelers a closer look at local stories, flavors, and traditions. '
        'Take your time, explore the details, and enjoy a more personal connection with the destination.',
  );
}

List<String> _sanitizeImages(
  List<String> images, {
  List<String> fallbackImages = const <String>[],
  String? fallbackImagePath,
}) {
  final cleaned = images.where((image) => image.trim().isNotEmpty).toList();
  if (cleaned.isNotEmpty) {
    return cleaned;
  }
  final cleanedFallbacks = fallbackImages
      .where((image) => image.trim().isNotEmpty)
      .toList();
  if (cleanedFallbacks.isNotEmpty) {
    return cleanedFallbacks;
  }
  if (fallbackImagePath != null && fallbackImagePath.trim().isNotEmpty) {
    return <String>[fallbackImagePath, fallbackImagePath, fallbackImagePath];
  }
  return const <String>['', '', ''];
}

final Map<String, ItemDetail> _mockDetails = <String, ItemDetail>{
  'activities:ha1': ItemDetail(
    id: 'ha1',
    reviewContentId: '11111111-1111-4111-8111-111111111111',
    name: 'Hue Ancient Capital',
    category: DetailCategory.activities,
    images: const <String>['', '', '', ''],
    rating: 4.7,
    isFavorite: true,
    reviewCount: 500,
    ratingLabel: 'Fantastic',
    description:
        'Explore the Hue Imperial Citadel, the former political and cultural center of the Nguyen Dynasty.',
    whatToExpect:
        'Visit Hue Ancient Capital to experience a cultural activity that reveals the historical imperial complex of the Nguyen Dynasty.',
  ),
  'activities:ha2': ItemDetail(
    id: 'ha2',
    reviewContentId: '22222222-2222-4222-8222-222222222222',
    name: 'Hue Festival',
    category: DetailCategory.activities,
    images: const <String>['', ''],
    rating: 4.8,
    isFavorite: true,
    reviewCount: 320,
    ratingLabel: 'Fantastic',
    description:
        'A biennial cultural event showcasing traditional Hue arts, music, and performances from around the world.',
    whatToExpect:
        'Hue Festival is a vibrant celebration featuring traditional music, dance, and cultural exhibitions that bring Hue heritage to life.',
  ),
  'culture:hc1': ItemDetail(
    id: 'hc1',
    reviewContentId: '33333333-3333-4333-8333-333333333333',
    name: 'The Imperial City of Hue',
    category: DetailCategory.culture,
    images: const <String>['', '', ''],
    rating: 4.7,
    isFavorite: false,
    reviewCount: 680,
    ratingLabel: 'Fantastic',
    description:
        'The Imperial City is a walled palace within the citadel of Hue, the former imperial capital of Vietnam.',
    whatToExpect:
        'Walk through the grand gates, majestic halls, and serene gardens that once housed Vietnamese emperors and their court.',
  ),
  'food:hf1': ItemDetail(
    id: 'hf1',
    reviewContentId: '44444444-4444-4444-8444-444444444444',
    name: 'Traditional Cuisines',
    category: DetailCategory.food,
    images: const <String>['', '', ''],
    rating: 4.7,
    isFavorite: false,
    reviewCount: 450,
    ratingLabel: 'Fantastic',
    description:
        'Hue cuisine is known for its elaborate preparation, vibrant flavors, and beautiful presentation.',
    whatToExpect:
        'Taste the authentic royal cuisine of Hue, from delicate spring rolls to rich, spicy soups.',
  ),
  'food:hf2': ItemDetail(
    id: 'hf2',
    reviewContentId: '55555555-5555-4555-8555-555555555555',
    name: 'Bun Bo Hue',
    category: DetailCategory.food,
    images: const <String>['', ''],
    rating: 4.8,
    isFavorite: true,
    reviewCount: 720,
    ratingLabel: 'Fantastic',
    description:
        'A spicy beef noodle soup originating from Hue, considered one of Vietnam most iconic dishes.',
    whatToExpect:
        'Savor the rich, lemongrass-infused broth with tender beef, pork, and thick rice noodles.',
  ),
  'local_products:hp1': ItemDetail(
    id: 'hp1',
    reviewContentId: '66666666-6666-4666-8666-666666666666',
    name: 'Incense Choke',
    category: DetailCategory.localProducts,
    images: const <String>['', '', ''],
    rating: 4.7,
    isFavorite: false,
    reviewCount: 180,
    ratingLabel: 'Fantastic',
    description:
        'Traditional handmade incense from Hue, known for its delicate fragrance and cultural significance.',
    whatToExpect:
        'Discover the art of traditional incense making and bring home a piece of Hue heritage.',
  ),
};
