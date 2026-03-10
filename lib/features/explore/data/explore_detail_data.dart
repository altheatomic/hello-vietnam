// Detail data for an explore item (food, activity, culture, product).

class ItemDetail {
  final String id;
  final String name;
  final String category; // "activity", "culture", "food", "local_product"
  final List<String> images;
  final double rating;
  final bool isFavorite;
  final int reviewCount;
  final String ratingLabel; // e.g. "Fantastic"
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
}

class ItemReview {
  final String userName;
  final String date;
  final String ratingLabel;
  final double rating;
  final String comment;
  final List<String> thumbnails; // review photos

  const ItemReview({
    required this.userName,
    required this.date,
    required this.ratingLabel,
    this.rating = 5.0,
    required this.comment,
    this.thumbnails = const [],
  });
}

/// Get detail for an item by id (mock). Falls back to a generic detail.
ItemDetail getItemDetail(String id, String name) {
  return _mockDetails[id] ?? _defaultDetail(id, name);
}

ItemDetail _defaultDetail(String id, String name) {
  return ItemDetail(
    id: id,
    name: name,
    category: 'general',
    images: ['', ''],
    rating: 4.5,
    isFavorite: false,
    reviewCount: 120,
    ratingLabel: 'Great',
    description:
        'Explore and discover the beauty of $name. '
        'A must-visit destination for anyone traveling to Vietnam.',
    whatToExpect:
        'Visit $name is a wonderful experience that allows '
        'visitors to explore the rich culture and traditions of Vietnam. '
        'You will have the opportunity to immerse yourself in local life '
        'and create unforgettable memories.',
    reviews: _buildMockReviews(name),
  );
}

final Map<String, ItemDetail> _mockDetails = {
  // Hue activities
  'ha1': ItemDetail(
    id: 'ha1',
    name: 'Hue Ancient Capital',
    category: 'activity',
    images: ['', '', '', ''],
    rating: 4.7,
    isFavorite: true,
    reviewCount: 500,
    ratingLabel: 'Fantastic',
    description:
        'Explore the Hue Imperial Citadel, '
        'the former political and cultural center of the Nguyen Dynasty.',
    whatToExpect:
        'Visit Hue Ancient Capital is a cultural activity '
        'that allows visitors to explore the historical imperial complex '
        'of the Nguyen Dynasty.',
    reviews: _buildMockReviews('Hue Ancient Capital'),
  ),
  'ha2': ItemDetail(
    id: 'ha2',
    name: 'Hue Festival',
    category: 'activity',
    images: ['', ''],
    rating: 4.8,
    isFavorite: true,
    reviewCount: 320,
    ratingLabel: 'Fantastic',
    description:
        'A biennial cultural event showcasing traditional Hue arts, '
        'music, and performances from around the world.',
    whatToExpect:
        'Hue Festival is a vibrant celebration featuring traditional '
        'music, dance, and cultural exhibitions that bring Hue\'s heritage to life.',
    reviews: _buildMockReviews('Hue Festival'),
  ),
  // Hue culture
  'hc1': ItemDetail(
    id: 'hc1',
    name: 'The Imperial City of Hue',
    category: 'culture',
    images: ['', '', ''],
    rating: 4.7,
    isFavorite: false,
    reviewCount: 680,
    ratingLabel: 'Fantastic',
    description:
        'The Imperial City is a walled palace within the citadel '
        'of Hue, the former imperial capital of Vietnam.',
    whatToExpect:
        'Walk through the grand gates, majestic halls, and serene '
        'gardens that once housed Vietnamese emperors and their court.',
    reviews: _buildMockReviews('The Imperial City of Hue'),
  ),
  // Hue food
  'hf1': ItemDetail(
    id: 'hf1',
    name: 'Traditional Cuisines',
    category: 'food',
    images: ['', '', ''],
    rating: 4.7,
    isFavorite: false,
    reviewCount: 450,
    ratingLabel: 'Fantastic',
    description:
        'Hue cuisine is known for its elaborate preparation, '
        'vibrant flavors, and beautiful presentation.',
    whatToExpect:
        'Taste the authentic royal cuisine of Hue, from delicate '
        'spring rolls to rich, spicy soups.',
    reviews: _buildMockReviews('Traditional Cuisines'),
  ),
  'hf2': ItemDetail(
    id: 'hf2',
    name: 'Bun Bo Hue',
    category: 'food',
    images: ['', ''],
    rating: 4.8,
    isFavorite: true,
    reviewCount: 720,
    ratingLabel: 'Fantastic',
    description:
        'A spicy beef noodle soup originating from Hue, '
        'considered one of Vietnam\'s most iconic dishes.',
    whatToExpect:
        'Savor the rich, lemongrass-infused broth with tender beef, '
        'pork, and thick rice noodles.',
    reviews: _buildMockReviews('Bun Bo Hue'),
  ),
  // Hue local products
  'hp1': ItemDetail(
    id: 'hp1',
    name: 'Incense Choke',
    category: 'local_product',
    images: ['', '', ''],
    rating: 4.7,
    isFavorite: false,
    reviewCount: 180,
    ratingLabel: 'Fantastic',
    description:
        'Traditional handmade incense from Hue, known for its '
        'delicate fragrance and cultural significance.',
    whatToExpect:
        'Discover the art of traditional incense making '
        'and bring home a piece of Hue\'s heritage.',
    reviews: _buildMockReviews('Incense Choke'),
  ),
};

List<ItemReview> _buildMockReviews(String topic) {
  return [
    ItemReview(
      userName: 'Maria',
      date: '21/01/2026',
      ratingLabel: 'Fantastic',
      rating: 5.0,
      comment:
          '$topic felt beautifully curated from start to finish. The pace was comfortable and the atmosphere stayed memorable the whole time.',
      thumbnails: const ['', '', ''],
    ),
    ItemReview(
      userName: 'James',
      date: '02/02/2026',
      ratingLabel: 'Amazing',
      rating: 4.9,
      comment:
          'I liked how easy it was to understand the story behind $topic. It felt authentic instead of overly touristy.',
      thumbnails: const ['', ''],
    ),
    ItemReview(
      userName: 'Linh',
      date: '18/02/2026',
      ratingLabel: 'Great',
      rating: 4.8,
      comment:
          'The highlights of $topic were worth the time, especially the smaller details that you only notice when you slow down and explore properly.',
      thumbnails: const ['', '', '', ''],
    ),
    ItemReview(
      userName: 'Sophie',
      date: '04/03/2026',
      ratingLabel: 'Fantastic',
      rating: 5.0,
      comment:
          '$topic exceeded expectations. I would absolutely recommend it to first-time visitors who want a strong and polished experience.',
      thumbnails: const ['', ''],
    ),
  ];
}
