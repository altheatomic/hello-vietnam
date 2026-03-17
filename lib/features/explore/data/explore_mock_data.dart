import '../domain/explore_item.dart';

/// ---------------------------------------------------------------
/// Mock data for the Explore page — swap with API later.
/// ---------------------------------------------------------------

/// Featured suggestions shown at the top (horizontal scroll).
const List<ExploreItem> exploreFeatured = [
  ExploreItem(id: 'f1', name: 'Bun bo',           imagePath: 'assets/images/explore/bun_bo.jpg'),
  ExploreItem(id: 'f2', name: 'Water puppetry',   imagePath: 'assets/images/explore/water_puppetry.jpg'),
  ExploreItem(id: 'f3', name: 'Pho',              imagePath: 'assets/images/explore/pho.jpg'),
  ExploreItem(id: 'f4', name: 'Hoi An',           imagePath: 'assets/images/explore/hoi_an.jpg'),
];

/// Category tabs data.
const List<ExploreCategory> exploreCategories = [
  ExploreCategory(
    id: 'activities',
    title: 'Activities',
    description: 'Hands-on experiences and cultural activities',
    items: [
      ExploreItem(id: 'a1', name: 'Floating market',         imagePath: 'assets/images/explore/floating_market.jpg'),
      ExploreItem(id: 'a2', name: 'Dropping water lanterns',  imagePath: 'assets/images/explore/water_lanterns.jpg'),
      ExploreItem(id: 'a3', name: 'Floating market',         imagePath: 'assets/images/explore/floating_market_2.jpg'),
      ExploreItem(id: 'a4', name: 'Dropping water lanterns',  imagePath: 'assets/images/explore/water_lanterns_2.jpg'),
    ],
  ),
  ExploreCategory(
    id: 'culture',
    title: 'Culture',
    description: 'Traditional customs, heritage, and cultural practices',
    items: [
      ExploreItem(id: 'c1', name: 'Water puppetry',           imagePath: 'assets/images/explore/water_puppetry.jpg'),
      ExploreItem(id: 'c2', name: 'Traditional craft villages', imagePath: 'assets/images/explore/craft_villages.jpg'),
      ExploreItem(id: 'c3', name: 'Water puppetry',           imagePath: 'assets/images/explore/water_puppetry_2.jpg'),
      ExploreItem(id: 'c4', name: 'Traditional craft villages', imagePath: 'assets/images/explore/craft_villages_2.jpg'),
    ],
  ),
  ExploreCategory(
    id: 'food',
    title: 'Food',
    description: 'Local dishes and culinary specialties from different regions',
    items: [
      ExploreItem(id: 'd1', name: 'Beef noodle soup',  imagePath: 'assets/images/explore/beef_noodle.jpg'),
      ExploreItem(id: 'd2', name: 'Pho',               imagePath: 'assets/images/explore/pho.jpg'),
      ExploreItem(id: 'd3', name: 'Banh mi',           imagePath: 'assets/images/explore/banh_mi.jpg'),
      ExploreItem(id: 'd4', name: 'Bun bo',            imagePath: 'assets/images/explore/bun_bo.jpg'),
    ],
  ),
  ExploreCategory(
    id: 'local_products',
    title: 'Local Products',
    description: 'Traditional goods and handcrafted regional products',
    items: [
      ExploreItem(id: 'p1', name: 'Conical hats',      imagePath: 'assets/images/explore/conical_hats.jpg'),
      ExploreItem(id: 'p2', name: 'Bat Trang pottery', imagePath: 'assets/images/explore/bat_trang.jpg'),
      ExploreItem(id: 'p3', name: 'Conical hats',      imagePath: 'assets/images/explore/conical_hats_2.jpg'),
      ExploreItem(id: 'p4', name: 'Bat Trang pottery', imagePath: 'assets/images/explore/bat_trang_2.jpg'),
    ],
  ),
];
