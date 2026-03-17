import '../domain/explore_item.dart';

/// ---------------------------------------------------------------
/// Mock search results per destination — swap with API later.
/// Keys are lowercase destination names.
/// ---------------------------------------------------------------

/// A result item with multiple images (for carousel), rating, etc.
class SearchResultItem {
  final String id;
  final String name;
  final List<String> images; // multiple images for carousel
  final double rating;
  final bool isFavorite;

  const SearchResultItem({
    required this.id,
    required this.name,
    required this.images,
    this.rating = 4.7,
    this.isFavorite = false,
  });
}

/// Category results for a specific destination.
class DestinationResults {
  final String destination;
  final List<SearchResultItem> activities;
  final List<SearchResultItem> culture;
  final List<SearchResultItem> food;
  final List<SearchResultItem> localProducts;

  const DestinationResults({
    required this.destination,
    required this.activities,
    required this.culture,
    required this.food,
    required this.localProducts,
  });

  List<SearchResultItem> byCategory(int index) {
    switch (index) {
      case 0: return activities;
      case 1: return culture;
      case 2: return food;
      case 3: return localProducts;
      default: return activities;
    }
  }
}

/// Get results for a destination (mock).
DestinationResults getResultsForDestination(String destination) {
  final key = destination.toLowerCase().trim();
  return _mockResults[key] ?? _defaultResults(destination);
}

DestinationResults _defaultResults(String destination) {
  return DestinationResults(
    destination: destination,
    activities: [
      SearchResultItem(id: 'a1', name: 'Local Tour', images: [''], rating: 4.5),
      SearchResultItem(id: 'a2', name: 'Walking Tour', images: [''], rating: 4.3),
      SearchResultItem(id: 'a3', name: 'Night Market', images: [''], rating: 4.6),
    ],
    culture: [
      SearchResultItem(id: 'c1', name: 'Historical Sites', images: [''], rating: 4.7),
      SearchResultItem(id: 'c2', name: 'Museums', images: [''], rating: 4.4),
      SearchResultItem(id: 'c3', name: 'Temples', images: [''], rating: 4.5),
    ],
    food: [
      SearchResultItem(id: 'f1', name: 'Local Cuisine', images: [''], rating: 4.6),
      SearchResultItem(id: 'f2', name: 'Street Food', images: [''], rating: 4.5),
      SearchResultItem(id: 'f3', name: 'Traditional Dishes', images: [''], rating: 4.7),
    ],
    localProducts: [
      SearchResultItem(id: 'p1', name: 'Handicrafts', images: [''], rating: 4.3),
      SearchResultItem(id: 'p2', name: 'Souvenirs', images: [''], rating: 4.2),
      SearchResultItem(id: 'p3', name: 'Local Specialties', images: [''], rating: 4.5),
    ],
  );
}

final Map<String, DestinationResults> _mockResults = {
  'vietnam': DestinationResults(
    destination: 'Vietnam',
    activities: [
      SearchResultItem(id: 'v_a1', name: 'Floating Market', images: ['', '', ''], rating: 4.7, isFavorite: true),
      SearchResultItem(id: 'v_a2', name: 'Dropping Water Lanterns', images: ['', ''], rating: 4.8),
      SearchResultItem(id: 'v_a3', name: 'Hue Royal Court Music', images: ['', '', ''], rating: 4.9),
    ],
    culture: [
      SearchResultItem(id: 'v_c1', name: 'Water Puppetry', images: ['', '', ''], rating: 4.7, isFavorite: true),
      SearchResultItem(id: 'v_c2', name: 'Traditional Craft Villages', images: ['', ''], rating: 4.6),
      SearchResultItem(id: 'v_c3', name: 'The Imperial City of Hue', images: ['', ''], rating: 4.8),
    ],
    food: [
      SearchResultItem(id: 'v_f1', name: 'Pho', images: ['', '', ''], rating: 4.9, isFavorite: true),
      SearchResultItem(id: 'v_f2', name: 'Bun Bo Hue', images: ['', ''], rating: 4.8),
      SearchResultItem(id: 'v_f3', name: 'Banh Mi', images: ['', ''], rating: 4.7),
    ],
    localProducts: [
      SearchResultItem(id: 'v_p1', name: 'Conical Hats', images: ['', '', ''], rating: 4.5, isFavorite: true),
      SearchResultItem(id: 'v_p2', name: 'Bat Trang Pottery', images: ['', ''], rating: 4.6),
      SearchResultItem(id: 'v_p3', name: 'Ao Dai', images: ['', ''], rating: 4.7),
    ],
  ),
  'hue': DestinationResults(
    destination: 'Hue',
    activities: [
      SearchResultItem(id: 'ha1', name: 'Hue Royal Court Music', images: ['', '', ''], rating: 4.7, isFavorite: true),
      SearchResultItem(id: 'ha2', name: 'Hue Festival', images: ['', ''], rating: 4.8),
      SearchResultItem(id: 'ha3', name: 'Nhã nhạc cung đình Huế', images: ['', '', ''], rating: 4.9),
    ],
    culture: [
      SearchResultItem(id: 'hc1', name: 'The Imperial City of Hue', images: ['', '', ''], rating: 4.7, isFavorite: true),
      SearchResultItem(id: 'hc2', name: 'Huong River', images: ['', ''], rating: 4.6),
      SearchResultItem(id: 'hc3', name: 'Huong River', images: ['', ''], rating: 4.5),
    ],
    food: [
      SearchResultItem(id: 'hf1', name: 'Traditional Cuisines', images: ['', '', ''], rating: 4.7, isFavorite: true),
      SearchResultItem(id: 'hf2', name: 'Bun Bo Hue', images: ['', ''], rating: 4.8),
      SearchResultItem(id: 'hf3', name: 'Bun Bo Hue', images: ['', ''], rating: 4.6),
    ],
    localProducts: [
      SearchResultItem(id: 'hp1', name: 'Incense Choke', images: ['', '', ''], rating: 4.7, isFavorite: true),
      SearchResultItem(id: 'hp2', name: 'Me Xung', images: ['', ''], rating: 4.5),
      SearchResultItem(id: 'hp3', name: 'Me Xung', images: ['', ''], rating: 4.4),
    ],
  ),
  'ha noi': DestinationResults(
    destination: 'Ha Noi',
    activities: [
      SearchResultItem(id: 'hn_a1', name: 'Water Puppet Show', images: ['', ''], rating: 4.6, isFavorite: true),
      SearchResultItem(id: 'hn_a2', name: 'Hanoi Night Tour', images: ['', ''], rating: 4.5),
      SearchResultItem(id: 'hn_a3', name: 'Cooking Class', images: ['', ''], rating: 4.7),
    ],
    culture: [
      SearchResultItem(id: 'hn_c1', name: 'Temple of Literature', images: ['', ''], rating: 4.8, isFavorite: true),
      SearchResultItem(id: 'hn_c2', name: 'Ho Chi Minh Mausoleum', images: ['', ''], rating: 4.7),
      SearchResultItem(id: 'hn_c3', name: 'Old Quarter', images: ['', ''], rating: 4.6),
    ],
    food: [
      SearchResultItem(id: 'hn_f1', name: 'Pho', images: ['', ''], rating: 4.9, isFavorite: true),
      SearchResultItem(id: 'hn_f2', name: 'Bun Cha', images: ['', ''], rating: 4.8),
      SearchResultItem(id: 'hn_f3', name: 'Banh Mi', images: ['', ''], rating: 4.7),
    ],
    localProducts: [
      SearchResultItem(id: 'hn_p1', name: 'Bat Trang Pottery', images: ['', ''], rating: 4.5, isFavorite: true),
      SearchResultItem(id: 'hn_p2', name: 'Silk Products', images: ['', ''], rating: 4.4),
      SearchResultItem(id: 'hn_p3', name: 'Dong Ho Paintings', images: ['', ''], rating: 4.6),
    ],
  ),
};
