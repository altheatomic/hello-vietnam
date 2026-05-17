import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

import '../domain/explore_item.dart';

/// ---------------------------------------------------------------
/// Mock data for the Explore page — swap with API later.
/// ---------------------------------------------------------------

/// Featured suggestions shown at the top (horizontal scroll).
const List<ExploreItem> exploreFeatured = [
  ExploreItem(
    id: 'f1',
    name: 'Bun bo',
    imagePath: 'assets/images/homepage/bestdishes_bg.jpeg',
    category: DetailCategory.food,
  ),
  ExploreItem(
    id: 'f2',
    name: 'Water puppetry',
    imagePath: 'assets/images/Auth_Image/Vietnam.jpg',
    category: DetailCategory.culture,
  ),
  ExploreItem(
    id: 'f3',
    name: 'Pho',
    imagePath: 'assets/images/explore/explore_bg.jpeg',
    category: DetailCategory.food,
  ),
  ExploreItem(
    id: 'f4',
    name: 'Hoi An',
    imagePath: 'assets/images/homepage/bestdestination_bg.jpeg',
    category: DetailCategory.culture,
  ),
];

/// Category tabs data.
const List<ExploreCategory> exploreCategories = [
  ExploreCategory(
    id: 'activities',
    title: 'Activities',
    description: 'Hands-on experiences and cultural activities',
    items: [
      ExploreItem(
        id: 'a1',
        name: 'Floating market',
        imagePath: 'assets/images/explore/explore_bg.jpeg',
        category: DetailCategory.activities,
      ),
      ExploreItem(
        id: 'a2',
        name: 'Dropping water lanterns',
        imagePath: 'assets/images/recommend/when.png',
        category: DetailCategory.activities,
      ),
      ExploreItem(
        id: 'a3',
        name: 'Floating market',
        imagePath: 'assets/images/homepage/bestdestination_bg.jpeg',
        category: DetailCategory.activities,
      ),
      ExploreItem(
        id: 'a4',
        name: 'Dropping water lanterns',
        imagePath: 'assets/images/recommend/where.png',
        category: DetailCategory.activities,
      ),
    ],
  ),
  ExploreCategory(
    id: 'culture',
    title: 'Culture',
    description: 'Traditional customs, heritage, and cultural practices',
    items: [
      ExploreItem(
        id: 'c1',
        name: 'Water puppetry',
        imagePath: 'assets/images/Auth_Image/Vietnam.jpg',
        category: DetailCategory.culture,
      ),
      ExploreItem(
        id: 'c2',
        name: 'Traditional craft villages',
        imagePath: 'assets/images/homepage/bestdestination_bg.jpeg',
        category: DetailCategory.culture,
      ),
      ExploreItem(
        id: 'c3',
        name: 'Water puppetry',
        imagePath: 'assets/images/explore/explore_bg.jpeg',
        category: DetailCategory.culture,
      ),
      ExploreItem(
        id: 'c4',
        name: 'Traditional craft villages',
        imagePath: 'assets/images/recommend/where.png',
        category: DetailCategory.culture,
      ),
    ],
  ),
  ExploreCategory(
    id: 'food',
    title: 'Food',
    description: 'Local dishes and culinary specialties from different regions',
    items: [
      ExploreItem(
        id: 'd1',
        name: 'Beef noodle soup',
        imagePath: 'assets/images/homepage/bestdishes_bg.jpeg',
        category: DetailCategory.food,
      ),
      ExploreItem(
        id: 'd2',
        name: 'Pho',
        imagePath: 'assets/images/explore/explore_bg.jpeg',
        category: DetailCategory.food,
      ),
      ExploreItem(
        id: 'd3',
        name: 'Banh mi',
        imagePath: 'assets/images/dishes/banh_mi.jpg',
        category: DetailCategory.food,
      ),
      ExploreItem(
        id: 'd4',
        name: 'Bun bo',
        imagePath: 'assets/images/homepage/bestdishes_bg.jpeg',
        category: DetailCategory.food,
      ),
    ],
  ),
  ExploreCategory(
    id: 'local_products',
    title: 'Local Products',
    description: 'Traditional goods and handcrafted regional products',
    items: [
      ExploreItem(
        id: 'p1',
        name: 'Conical hats',
        imagePath: 'assets/images/Auth_Image/Vietnam.jpg',
        category: DetailCategory.localProducts,
      ),
      ExploreItem(
        id: 'p2',
        name: 'Bat Trang pottery',
        imagePath: 'assets/images/recommend/where.png',
        category: DetailCategory.localProducts,
      ),
      ExploreItem(
        id: 'p3',
        name: 'Conical hats',
        imagePath: 'assets/images/homepage/bestdestination_bg.jpeg',
        category: DetailCategory.localProducts,
      ),
      ExploreItem(
        id: 'p4',
        name: 'Bat Trang pottery',
        imagePath: 'assets/images/explore/explore_bg.jpeg',
        category: DetailCategory.localProducts,
      ),
    ],
  ),
];
