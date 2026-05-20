import 'package:flutter/material.dart';
import 'package:hellovietnam/core/widgets/glass_card.dart';
import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/item_detail/presentation/shared_item_detail_page.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';
import 'package:hellovietnam/features/report/presentation/report_issue_popup.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  WishlistType? _selectedType;
  final Set<String> _favoriteIds = <String>{};
  final WishlistRepository _wishlistRepository = WishlistRepository();
  List<WishlistItem> _syncedItems = <WishlistItem>[];
  bool _isLoading = true;
  String? _loadError;

  static const List<WishlistItem> _items = <WishlistItem>[
    WishlistItem(
      id: 'dalat',
      title: 'TP. Da Lat',
      shortDescription:
          'Da Lat is a highland city in the Lam Vien Plateau, known for its '
          'cool climate, pine forests, and peaceful mountain scenery.',
      detailDescription:
          'The cathedral is a signature landmark of Ho Chi Minh City, known '
          'for its red bricks and twin bell towers. Its French colonial '
          'architecture makes it one of the most visited cultural sites '
          'in the city.',
      highlightsDescription:
          'Da Lat offers serene lakes, green tea hills, cool pine forests, '
          'and refreshing mountain views. Visitors can enjoy Xuan Huong Lake, '
          'explore Cau Dat Tea Hill, hike Langbiang Mountain, or experience '
          'the lively atmosphere of the Da Lat Night Market.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1583417267826-aebc4d1542e1?auto=format&fit=crop&w=1400&q=80',
      galleryImageUrls: <String>[
        'https://images.unsplash.com/photo-1548502499-ef49e8cf98d0?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1505765050516-f72dcac9c60b?auto=format&fit=crop&w=900&q=80',
      ],
      mapImageUrl:
          'https://staticmap.openstreetmap.de/staticmap.php?center=11.9404,108.4583&zoom=10&size=900x420&markers=11.9404,108.4583,red-pushpin',
      rating: 4.7,
      type: WishlistType.city,
    ),
    WishlistItem(
      id: 'hanoi-food',
      title: 'Mi Quang',
      shortDescription:
          'Mi Quang is a signature noodle dish from Central Vietnam, known for '
          'its turmeric noodles, rich broth, and fresh herbs.',
      detailDescription:
          'Mi Quang uses flat turmeric noodles paired with a savory broth made '
          'from pork bones and shrimp. Each bowl is finished with fresh herbs, '
          'bean sprouts, shrimp, pork belly, peanuts, and a crunchy rice '
          'cracker, giving it its signature mix of soft and crispy textures.',
      highlightsDescription:
          'A well-balanced bowl combines rich broth, fresh herbs, and crunchy '
          'rice crackers for the classic Mi Quang experience.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=1400&q=80',
      galleryImageUrls: <String>[
        'https://images.unsplash.com/photo-1557872943-16a5ac26437e?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1466978913421-dad2ebd01d17?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1604908177076-5d2f6f1430df?auto=format&fit=crop&w=900&q=80',
      ],
      ingredients: <String>[
        'Turmeric noodles',
        'Pork or shrimps',
        'Quail eggs',
        'Fresh herbs',
        'Peanuts',
        'Rice crackers',
      ],
      flavors: <String>[
        'Savory',
        'Aromatic',
        'Slightly sweet',
        'Crunchy toppings',
      ],
      mapImageUrl:
          'https://staticmap.openstreetmap.de/staticmap.php?center=21.0285,105.8542&zoom=12&size=900x420&markers=21.0285,105.8542,red-pushpin',
      rating: 4.7,
      type: WishlistType.food,
    ),
    WishlistItem(
      id: 'hanoi-place',
      title: 'Notre-Dame Cathedral of Saigon',
      shortDescription:
          'The cathedral is a signature landmark of Ho Chi Minh City, known '
          'for its red bricks and twin bell towers.',
      detailDescription:
          'Da Lat is a misty highland city known for its cool climate, pine '
          'forests, flower gardens, and peaceful lakes. It is one of the most '
          'popular destinations in Vietnam for relaxation and sightseeing.',
      highlightsDescription:
          'The cathedral is a signature landmark of Ho Chi Minh City, known '
          'for its twin bell towers and colonial architecture.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1545569341-9eb8b30979d9?auto=format&fit=crop&w=1400&q=80',
      galleryImageUrls: <String>[
        'https://images.unsplash.com/photo-1545569341-9eb8b30979d9?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1473448912268-2022ce9509d8?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1518548419970-58e3b4079ab2?auto=format&fit=crop&w=900&q=80',
      ],
      mapImageUrl:
          'https://staticmap.openstreetmap.de/staticmap.php?center=10.7797,106.6990&zoom=15&size=900x420&markers=10.7797,106.6990,red-pushpin',
      rating: 4.7,
      type: WishlistType.place,
    ),
    WishlistItem(
      id: 'hanoi-city',
      title: 'TP. Ha Noi',
      shortDescription:
          'The capital of Vietnam with historic streets, local food, and a '
          'vibrant blend of tradition and modern life.',
      detailDescription:
          'Ha Noi is known for its rich history, tree-lined boulevards, and '
          'lively old quarter. Visitors can explore museums, local cafes, and '
          'traditional markets while enjoying authentic street food.',
      highlightsDescription:
          'Walk around Hoan Kiem Lake, visit the Old Quarter, enjoy egg '
          'coffee, and discover famous cultural landmarks across the city.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&w=1400&q=80',
      galleryImageUrls: <String>[
        'https://images.unsplash.com/photo-1466442929976-97f336a657be?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1526481280695-3c46963c9c1d?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1562602833-0f4ab2fc46e8?auto=format&fit=crop&w=900&q=80',
      ],
      mapImageUrl:
          'https://staticmap.openstreetmap.de/staticmap.php?center=21.0278,105.8342&zoom=11&size=900x420&markers=21.0278,105.8342,red-pushpin',
      rating: 4.6,
      type: WishlistType.city,
    ),
    WishlistItem(
      id: 'hoi-an-city',
      title: 'TP. Hoi An',
      shortDescription:
          'A charming ancient town famous for lantern streets, yellow houses, '
          'and riverside night views.',
      detailDescription:
          'Hoi An offers a relaxing atmosphere with preserved architecture, '
          'traditional craft shops, and beautiful lantern-lit evenings. It is '
          'a perfect destination for culture, food, and photography.',
      highlightsDescription:
          'Explore the Ancient Town, ride a bicycle to nearby villages, and '
          'enjoy the lantern night by the Hoai River.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?auto=format&fit=crop&w=1400&q=80',
      galleryImageUrls: <String>[
        'https://images.unsplash.com/photo-1528181304800-259b08848526?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1577083552431-6e5fd01aa342?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1518544866330-95a2e1b3d0f9?auto=format&fit=crop&w=900&q=80',
      ],
      mapImageUrl:
          'https://staticmap.openstreetmap.de/staticmap.php?center=15.8801,108.3380&zoom=12&size=900x420&markers=15.8801,108.3380,red-pushpin',
      rating: 4.8,
      type: WishlistType.city,
    ),
    WishlistItem(
      id: 'nha-trang-city',
      title: 'TP. Nha Trang',
      shortDescription:
          'A coastal city known for sunny beaches, clear water, seafood, and '
          'popular island tours.',
      detailDescription:
          'Nha Trang is one of Vietnam\'s top beach destinations with beautiful '
          'coastline, ocean activities, and lively nightlife. It is great for '
          'both relaxing trips and active sea adventures.',
      highlightsDescription:
          'Visit the main beach, explore nearby islands, enjoy fresh seafood, '
          'and watch sunset views along the coast.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1595877244574-e90ce41ce089?auto=format&fit=crop&w=1400&q=80',
      galleryImageUrls: <String>[
        'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1483683804023-6ccdb62f86ef?auto=format&fit=crop&w=900&q=80',
      ],
      mapImageUrl:
          'https://staticmap.openstreetmap.de/staticmap.php?center=12.2388,109.1967&zoom=11&size=900x420&markers=12.2388,109.1967,red-pushpin',
      rating: 4.5,
      type: WishlistType.city,
    ),
    WishlistItem(
      id: 'ba-na-place',
      title: 'Ba Na Hills',
      shortDescription:
          'A mountain resort near Da Nang with cool weather, scenic cable '
          'car views, and iconic architecture.',
      detailDescription:
          'Ba Na Hills is a popular attraction with a European-inspired village, '
          'gardens, and entertainment areas at high altitude. The cable car '
          'ride offers panoramic views of forests and mountains.',
      highlightsDescription:
          'Take the cable car, visit French Village, enjoy mountain air, and '
          'capture unique viewpoints across the hills.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1623746603918-bc4bfe9c3c36?auto=format&fit=crop&w=1400&q=80',
      galleryImageUrls: <String>[
        'https://images.unsplash.com/photo-1549692520-acc6669e2f0c?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1578894381278-7f5f3f1f6f73?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1623746604027-1e59b88f6a15?auto=format&fit=crop&w=900&q=80',
      ],
      mapImageUrl:
          'https://staticmap.openstreetmap.de/staticmap.php?center=15.9973,107.9964&zoom=12&size=900x420&markers=15.9973,107.9964,red-pushpin',
      rating: 4.6,
      type: WishlistType.place,
    ),
    WishlistItem(
      id: 'trang-an-place',
      title: 'Trang An Scenic',
      shortDescription:
          'A UNESCO site in Ninh Binh with river caves, limestone mountains, '
          'and tranquil boat routes.',
      detailDescription:
          'Trang An is famous for its natural beauty and peaceful waterways. '
          'Boat tours take visitors through caves and valleys surrounded by '
          'dramatic limestone landscapes.',
      highlightsDescription:
          'Join a boat trip, visit cave systems, and enjoy panoramic viewpoints '
          'of the Ninh Binh karst region.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1616740540792-3daec6047779?auto=format&fit=crop&w=1400&q=80',
      galleryImageUrls: <String>[
        'https://images.unsplash.com/photo-1623744371652-9c3574932b09?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1586802224715-0f6ec0fd71c1?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1589308078050-8324f6fcb534?auto=format&fit=crop&w=900&q=80',
      ],
      mapImageUrl:
          'https://staticmap.openstreetmap.de/staticmap.php?center=20.2545,105.9703&zoom=12&size=900x420&markers=20.2545,105.9703,red-pushpin',
      rating: 4.8,
      type: WishlistType.place,
    ),
    WishlistItem(
      id: 'bun-cha-food',
      title: 'Bun Cha',
      shortDescription:
          'Bun Cha is a classic Hanoi dish with grilled pork, rice noodles, '
          'fresh herbs, and a sweet-savory dipping sauce.',
      detailDescription:
          'Bun Cha features charcoal-grilled pork served with vermicelli, '
          'pickled vegetables, and herbs. The warm dipping broth gives it a '
          'balanced flavor that is smoky, sweet, and savory.',
      highlightsDescription:
          'The contrast of smoky pork, fresh herbs, and tangy-sweet sauce '
          'makes Bun Cha one of Vietnam\'s most loved noodle dishes.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1604908177076-5d2f6f1430df?auto=format&fit=crop&w=1400&q=80',
      galleryImageUrls: <String>[
        'https://images.unsplash.com/photo-1498654896293-37aacf113fd9?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1515003197210-e0cd71810b5f?auto=format&fit=crop&w=900&q=80',
      ],
      ingredients: <String>[
        'Rice noodles',
        'Grilled pork',
        'Fresh herbs',
        'Pickled vegetables',
        'Sweet fish sauce',
      ],
      flavors: <String>['Savory', 'Smoky', 'Slightly sweet', 'Fresh herbs'],
      mapImageUrl:
          'https://staticmap.openstreetmap.de/staticmap.php?center=21.0157,105.8513&zoom=13&size=900x420&markers=21.0157,105.8513,red-pushpin',
      rating: 4.7,
      type: WishlistType.food,
    ),
    WishlistItem(
      id: 'banh-mi-food',
      title: 'Banh Mi',
      shortDescription:
          'Banh Mi is a Vietnamese baguette sandwich with savory fillings, '
          'fresh herbs, and crunchy pickled vegetables.',
      detailDescription:
          'Banh Mi combines a crispy baguette with pate, meats, pickles, '
          'cucumber, and fresh herbs. It is one of the most iconic Vietnamese '
          'street foods, loved for its rich and layered texture.',
      highlightsDescription:
          'A good Banh Mi should be crispy outside, soft inside, and filled '
          'with savory, fresh, and slightly tangy flavors.',
      coverImageUrl:
          'https://images.unsplash.com/photo-1562967916-eb82221dfb92?auto=format&fit=crop&w=1400&q=80',
      galleryImageUrls: <String>[
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?auto=format&fit=crop&w=900&q=80',
      ],
      ingredients: <String>[
        'Vietnamese baguette',
        'Cold cuts and pate',
        'Pickled vegetables',
        'Fresh cucumber and herbs',
        'Homemade sauce',
      ],
      flavors: <String>['Savory', 'Rich', 'Crunchy', 'Fresh'],
      mapImageUrl:
          'https://staticmap.openstreetmap.de/staticmap.php?center=10.7718,106.6915&zoom=13&size=900x420&markers=10.7718,106.6915,red-pushpin',
      rating: 4.6,
      type: WishlistType.food,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  List<WishlistItem> get _filteredItems {
    final items = _selectedType == null
        ? List<WishlistItem>.from(_syncedItems)
        : _syncedItems
              .where((WishlistItem item) => item.type == _selectedType)
              .toList();
    items.sort((WishlistItem a, WishlistItem b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return items;
  }

  Future<void> _openDetail(WishlistItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => SharedItemDetailPage(
          detail: _toSharedDetail(item),
          favoriteType: _wishlistTypeToFavoriteType(item.type),
          topRightOverlayBuilder: (context, detail) {
            return _ReportAssetIconButton(
              onTap: () {
                showReportIssueFlow(context);
              },
            );
          },
        ),
      ),
    );
    if (!mounted) return;
    await _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final userId = AuthRepository.instance.user?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _syncedItems = <WishlistItem>[];
        _favoriteIds.clear();
      });
      return;
    }

    try {
      final repoItems = await _wishlistRepository.fetchWishlist();
      if (!mounted) return;

      final mappedItems = repoItems.map(_toWishlistItem).toList(growable: true)
        ..sort((WishlistItem a, WishlistItem b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
      setState(() {
        _syncedItems = mappedItems;
        _favoriteIds
          ..clear()
          ..addAll(mappedItems.map((WishlistItem item) => item.id));
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _syncedItems = List<WishlistItem>.from(_items);
        _favoriteIds
          ..clear()
          ..addAll(_syncedItems.map((WishlistItem item) => item.id));
        _loadError = error.toString();
      });
    }
  }

  Future<void> _toggleFavorite(String id) async {
    WishlistItem? item;
    for (final current in _syncedItems) {
      if (current.id == id) {
        item = current;
        break;
      }
    }
    if (item == null) return;
    final targetItem = item;

    final userId = AuthRepository.instance.user?.id;
    if (userId == null) {
      _showSnackBar('Please sign in to update wishlist.');
      return;
    }

    final wasFavorite = _favoriteIds.contains(id);
    if (!wasFavorite) {
      return;
    }

    setState(() {
      _favoriteIds.remove(id);
      _syncedItems.removeWhere((WishlistItem current) => current.id == id);
    });

    try {
      await _wishlistRepository.setFavorite(
        itemId: targetItem.id,
        type: _wishlistTypeToFavoriteType(targetItem.type),
        isFavorite: false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _favoriteIds.add(id);
        if (_syncedItems.every((WishlistItem current) => current.id != id)) {
          _syncedItems.add(targetItem);
        }
      });
      _showSnackBar('Update wishlist failed: $error');
    }
  }

  WishlistItem _toWishlistItem(WishlistRepositoryItem item) {
    final image = item.imageUrl ?? '';
    final description = item.description.trim().isEmpty
        ? 'No description available.'
        : item.description.trim();

    return WishlistItem(
      id: item.id,
      title: item.title,
      shortDescription: description,
      detailDescription: description,
      highlightsDescription: description,
      coverImageUrl: image,
      galleryImageUrls: image.isEmpty ? const <String>[] : <String>[image],
      mapImageUrl: '',
      rating: 4.5,
      type: _displayTypeToWishlistType(item.displayType),
      createdAt: item.createdAt,
    );
  }

  WishlistType _displayTypeToWishlistType(WishlistDisplayType type) {
    switch (type) {
      case WishlistDisplayType.city:
        return WishlistType.city;
      case WishlistDisplayType.place:
        return WishlistType.place;
      case WishlistDisplayType.food:
        return WishlistType.food;
      case WishlistDisplayType.culture:
        return WishlistType.culture;
      case WishlistDisplayType.activity:
        return WishlistType.activity;
      case WishlistDisplayType.localProduct:
        return WishlistType.localProduct;
    }
  }

  FavoriteType _wishlistTypeToFavoriteType(WishlistType type) {
    switch (type) {
      case WishlistType.city:
        return FavoriteType.city;
      case WishlistType.food:
        return FavoriteType.food;
      case WishlistType.place:
        return FavoriteType.place;
      case WishlistType.culture:
        return FavoriteType.culture;
      case WishlistType.activity:
        return FavoriteType.activity;
      case WishlistType.localProduct:
        return FavoriteType.localProduct;
    }
  }

  ItemDetail _toSharedDetail(WishlistItem item) {
    final images = item.galleryImageUrls.isNotEmpty
        ? item.galleryImageUrls
        : (item.coverImageUrl.isEmpty
              ? const <String>[]
              : <String>[item.coverImageUrl]);

    return ItemDetail(
      id: item.id,
      name: item.title,
      category: _wishlistTypeToDetailCategory(item.type),
      images: images,
      rating: item.rating,
      isFavorite: _favoriteIds.contains(item.id),
      reviewCount: 0,
      ratingLabel: 'No reviews yet',
      description: item.detailDescription,
      whatToExpect: item.highlightsDescription,
      reviews: const <ItemReview>[],
    );
  }

  DetailCategory _wishlistTypeToDetailCategory(WishlistType type) {
    switch (type) {
      case WishlistType.city:
      case WishlistType.place:
      case WishlistType.activity:
        return DetailCategory.activities;
      case WishlistType.culture:
        return DetailCategory.culture;
      case WishlistType.food:
        return DetailCategory.food;
      case WishlistType.localProduct:
        return DetailCategory.localProducts;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ForumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 8),
              SizedBox(
                height: 58,
                child: Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _WishlistBackButton(
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Wishlist',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2EB9F8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _WishlistCategoryDropdown(
                  selectedType: _selectedType,
                  onChanged: (WishlistType? value) {
                    setState(() => _selectedType = value);
                  },
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2EB9F8),
                        ),
                      )
                    : _loadError != null
                    ? _WishlistStatusView(
                        message: 'Load wishlist failed.\n$_loadError',
                        actionLabel: 'Retry',
                        onActionTap: () => _loadWishlist(),
                      )
                    : _filteredItems.isEmpty
                    ? _WishlistStatusView(
                        message: AuthRepository.instance.isLoggedIn
                            ? 'No ${_selectedType?.label.toLowerCase() ?? 'saved'} item in wishlist.'
                            : 'Please sign in to use wishlist.',
                        actionLabel: AuthRepository.instance.isLoggedIn
                            ? null
                            : 'Sign in',
                        onActionTap: AuthRepository.instance.isLoggedIn
                            ? null
                            : () => Navigator.of(context).maybePop(),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                        itemCount: _filteredItems.length,
                        separatorBuilder: (BuildContext context, int index) =>
                            const SizedBox(height: 24),
                        itemBuilder: (BuildContext context, int index) {
                          final WishlistItem item = _filteredItems[index];
                          return _WishlistCard(
                            item: item,
                            isFavorite: _favoriteIds.contains(item.id),
                            onTap: () => _openDetail(item),
                            onToggleFavorite: () => _toggleFavorite(item.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WishlistDetailPage extends StatefulWidget {
  const WishlistDetailPage({
    super.key,
    required this.item,
    required this.initialFavorite,
  });

  final WishlistItem item;
  final bool initialFavorite;

  @override
  State<WishlistDetailPage> createState() => _WishlistDetailPageState();
}

class _WishlistDetailPageState extends State<WishlistDetailPage> {
  late bool _isFavorite = widget.initialFavorite;

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  void _handleBack() {
    Navigator.of(context).pop(_isFavorite);
  }

  void _openAllImages(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WishlistAllImagesPage(item: widget.item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final bool isPlace = widget.item.type == WishlistType.place;
    final bool isFood = widget.item.type == WishlistType.food;
    final double headerHeight = (isPlace || isFood) ? 300 : 320;
    const double galleryHeight = 92;
    const double galleryWidth = 122;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          Navigator.of(context).pop(_isFavorite);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: <Widget>[
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Stack(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(14),
                        ),
                        child: _NetworkImageWithFallback(
                          imageUrl: widget.item.coverImageUrl,
                          width: double.infinity,
                          height: headerHeight,
                        ),
                      ),
                      Positioned(
                        top: topInset + 6,
                        right: 8,
                        child: Column(
                          children: <Widget>[
                            _CircleIconButton(
                              icon: _isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              iconColor: const Color(0xFFFF4D79),
                              onTap: _toggleFavorite,
                            ),
                            const SizedBox(height: 2),
                            _ReportAssetIconButton(
                              onTap: () => showReportIssueFlow(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (isPlace || isFood)
                          Text(
                            widget.item.title.replaceFirst('TP. ', ''),
                            style: const TextStyle(
                              fontSize: 35,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2EB9F8),
                            ),
                          )
                        else
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  widget.item.title.replaceFirst('TP. ', ''),
                                  style: const TextStyle(
                                    fontSize: 35,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2EB9F8),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFCC00),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${widget.item.rating.toStringAsFixed(1)} \u2605',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        Text(
                          widget.item.detailDescription,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.45,
                            color: Color(0xFF222222),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Images',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0C709D),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _openAllImages(context),
                              child: const Text(
                                'See all',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6ABFE6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: galleryHeight,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.item.galleryImageUrls.length,
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    const SizedBox(width: 10),
                            itemBuilder: (_, int index) {
                              return GestureDetector(
                                onTap: () => _openAllImages(context),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: _NetworkImageWithFallback(
                                    imageUrl:
                                        widget.item.galleryImageUrls[index],
                                    width: galleryWidth,
                                    height: galleryHeight,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (isPlace) ...<Widget>[
                          const SizedBox(height: 16),
                          const Text(
                            'Location',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0C709D),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _NetworkImageWithFallback(
                              imageUrl: widget.item.mapImageUrl,
                              width: double.infinity,
                              height: 120,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _RatingSection(rating: widget.item.rating),
                        ] else if (isFood) ...<Widget>[
                          const SizedBox(height: 16),
                          const Text(
                            'Ingredients',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0C709D),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _BulletList(items: widget.item.ingredients),
                          const SizedBox(height: 12),
                          const Text(
                            'Flavor',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0C709D),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _BulletList(items: widget.item.flavors),
                          const SizedBox(height: 12),
                          _RatingSection(rating: widget.item.rating),
                        ] else ...<Widget>[
                          const SizedBox(height: 16),
                          const Text(
                            'The highlights of a visit',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0C709D),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.item.highlightsDescription,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: Color(0xFF232323),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: _NetworkImageWithFallback(
                              imageUrl: widget.item.mapImageUrl,
                              width: double.infinity,
                              height: 220,
                            ),
                          ),
                        ],
                        SizedBox(height: bottomInset + 90),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: topInset + 6,
              left: 8,
              child: _CircleIconButton(
                icon: Icons.arrow_back,
                onTap: _handleBack,
              ),
            ),
            if (isFood)
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomInset + 14,
                child: Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: Color(0xFF7FD4F7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WishlistAllImagesPage extends StatelessWidget {
  const WishlistAllImagesPage({super.key, required this.item});

  final WishlistItem item;

  List<String> get _allImages => <String>[
    item.coverImageUrl,
    ...item.galleryImageUrls,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 24,
                      color: Color(0xFF2EB9F8),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${item.title.replaceFirst('TP. ', '')} Images',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0C709D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  itemCount: _allImages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (_, int index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _NetworkImageWithFallback(
                        imageUrl: _allImages[index],
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection({required this.rating});

  final double rating;

  static const List<double> _distribution = <double>[
    0.82, // 5
    0.60, // 4
    0.20, // 3
    0.12, // 2
    0.08, // 1
  ];

  @override
  Widget build(BuildContext context) {
    final String ratingText = rating.toStringAsFixed(1).replaceAll('.', ',');
    final int filledStars = rating.floor().clamp(0, 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Rating',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0C709D),
                ),
              ),
            ),
            Text(
              'Show all (1322)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFCC00),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                children: List<Widget>.generate(5, (int index) {
                  final int label = 5 - index;
                  final double value = _distribution[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 12,
                          child: Text(
                            '$label',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF202020),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFE6E6E6),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFFFCC00),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: <Widget>[
                Text(
                  ratingText,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: List<Widget>.generate(5, (int index) {
                    return Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: index < filledStars
                          ? const Color(0xFFFFCC00)
                          : const Color(0xFFD8D8D8),
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• $item',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  color: Color(0xFF222222),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WishlistStatusView extends StatelessWidget {
  const _WishlistStatusView({
    required this.message,
    this.actionLabel,
    this.onActionTap,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Color(0xFF4C5A67),
              ),
            ),
            if (actionLabel != null && onActionTap != null) ...<Widget>[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onActionTap,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2EB9F8),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({
    required this.item,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final WishlistItem item;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 28,
      blur: 18,
      opacity: 0.58,
      border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: Stack(
                  children: <Widget>[
                    _NetworkImageWithFallback(
                      imageUrl: item.coverImageUrl,
                      width: double.infinity,
                      height: 208,
                    ),
                    Positioned(
                      top: 18,
                      right: 18,
                      child: _WishlistHeartButton(
                        isFavorite: isFavorite,
                        onTap: onToggleFavorite,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2EB9F8),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.shortDescription,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF566170),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WishlistBackButton extends StatelessWidget {
  const _WishlistBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 18,
      blur: 16,
      opacity: 0.5,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Color(0xFF2EB9F8),
          ),
        ),
      ),
    );
  }
}

class _WishlistCategoryDropdown extends StatelessWidget {
  const _WishlistCategoryDropdown({
    required this.selectedType,
    required this.onChanged,
  });

  final WishlistType? selectedType;
  final ValueChanged<WishlistType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = selectedType?.label ?? 'All Categories';

    return PopupMenuButton<String>(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 10,
      offset: const Offset(0, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (String value) {
        if (value == _allCategoryKey) {
          onChanged(null);
          return;
        }
        onChanged(
          WishlistType.values.firstWhere(
            (WishlistType type) => type.name == value,
          ),
        );
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: _allCategoryKey,
          child: Text('All Categories'),
        ),
        ...WishlistType.values.map(
          (WishlistType type) =>
              PopupMenuItem<String>(value: type.name, child: Text(type.label)),
        ),
      ],
      child: GlassCard(
        borderRadius: 999,
        blur: 18,
        opacity: 0.66,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        border: Border.all(color: const Color(0x662EB9F8), width: 1.4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2EB9F8),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF2EB9F8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

const String _allCategoryKey = 'all';

class _WishlistHeartButton extends StatelessWidget {
  const _WishlistHeartButton({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 999,
      blur: 16,
      opacity: 0.58,
      padding: EdgeInsets.zero,
      border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            size: 23,
            color: const Color(0xFFFF4D79),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = const Color(0xFF2C2C2C),
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

class _ReportAssetIconButton extends StatelessWidget {
  const _ReportAssetIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Image.asset(
            'assets/images/Auth_Image/problem.png',
            width: 28,
            height: 28,
            fit: BoxFit.contain,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) =>
                    const Icon(
                      Icons.bug_report_outlined,
                      size: 28,
                      color: Color(0xFF2C2C2C),
                    ),
          ),
        ),
      ),
    );
  }
}

class _NetworkImageWithFallback extends StatelessWidget {
  const _NetworkImageWithFallback({
    required this.imageUrl,
    required this.width,
    required this.height,
  });

  final String imageUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool isMap = imageUrl.toLowerCase().contains('map');
    if (imageUrl.trim().isNotEmpty) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              return _ImagePlaceholder(
                width: width,
                height: height,
                isMap: isMap,
              );
            },
      );
    }

    return _ImagePlaceholder(width: width, height: height, isMap: isMap);
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({
    required this.width,
    required this.height,
    required this.isMap,
  });

  final double width;
  final double height;
  final bool isMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMap
              ? const <Color>[Color(0xFFDFF3E7), Color(0xFFCBE6D4)]
              : const <Color>[Color(0xFFE8EEF3), Color(0xFFD6E0E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isMap ? Icons.map_outlined : Icons.image_outlined,
            color: const Color(0xFF7E8B97),
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            isMap ? 'Map placeholder' : 'Image placeholder',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E7A86),
            ),
          ),
        ],
      ),
    );
  }
}

enum WishlistType { city, food, place, culture, activity, localProduct }

extension WishlistTypeLabel on WishlistType {
  String get label {
    switch (this) {
      case WishlistType.city:
        return 'City';
      case WishlistType.food:
        return 'Food';
      case WishlistType.place:
        return 'Place';
      case WishlistType.culture:
        return 'Culture';
      case WishlistType.activity:
        return 'Activity';
      case WishlistType.localProduct:
        return 'Local Product';
    }
  }
}

class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.detailDescription,
    required this.highlightsDescription,
    required this.coverImageUrl,
    required this.galleryImageUrls,
    required this.mapImageUrl,
    required this.rating,
    required this.type,
    this.createdAt,
    this.ingredients = const <String>[],
    this.flavors = const <String>[],
  });

  final String id;
  final String title;
  final String shortDescription;
  final String detailDescription;
  final String highlightsDescription;
  final String coverImageUrl;
  final List<String> galleryImageUrls;
  final String mapImageUrl;
  final double rating;
  final WishlistType type;
  final DateTime? createdAt;
  final List<String> ingredients;
  final List<String> flavors;
}
