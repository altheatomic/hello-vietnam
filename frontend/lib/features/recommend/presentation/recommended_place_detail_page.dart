import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/item_detail/presentation/shared_item_detail_page.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';
import 'package:hellovietnam/features/reviews/domain/review_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/recommend_repository.dart';

class RecommendedPlaceDetailPage extends StatefulWidget {
  const RecommendedPlaceDetailPage({
    super.key,
    required this.idProvince,
    required this.idPlace,
  });

  final String idProvince;
  final String idPlace;

  @override
  State<RecommendedPlaceDetailPage> createState() =>
      _RecommendedPlaceDetailPageState();
}

class _RecommendedPlaceDetailPageState
    extends State<RecommendedPlaceDetailPage> {
  late final Future<ProvinceTopPlace> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    unawaited(_logViewDetail());
  }

  Future<void> _logViewDetail() async {
    try {
      final User? currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      await Supabase.instance.client.rpc(
        'log_user_event',
        params: <String, dynamic>{
          'p_user_id': currentUser.id,
          'p_place_id': widget.idPlace,
          'p_event_type': 'view_detail',
        },
      );
    } catch (error) {
      debugPrint('log_user_event(view_detail) failed: $error');
    }
  }

  Future<ProvinceTopPlace> _load() async {
    final ProvinceDetail detail = await RecommendRepository()
        .getTopPlacesForProvince(widget.idProvince);
    return detail.topPlaces.firstWhere(
      (ProvinceTopPlace place) => place.idPlace == widget.idPlace,
      orElse: () => throw StateError('Destination is no longer available.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProvinceTopPlace>(
      future: _future,
      builder:
          (BuildContext context, AsyncSnapshot<ProvinceTopPlace> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Scaffold(
                appBar: AppBar(),
                body: const Center(
                  child: Text('Could not load destination. Please try again.'),
                ),
              );
            }

            final ProvinceTopPlace place = snapshot.data!;
            final List<String> images = <String>[
              if (place.coverImage?.trim().isNotEmpty == true)
                place.coverImage!,
              if (place.galleryUrl?.trim().isNotEmpty == true &&
                  place.galleryUrl != place.coverImage)
                place.galleryUrl!,
            ];
            final String description = <String>[
              if (place.subcategoryName?.trim().isNotEmpty == true)
                place.subcategoryName!,
              if (place.address?.trim().isNotEmpty == true) place.address!,
            ].join(' · ');

            return SharedItemDetailPage(
              detail: ItemDetail(
                id: place.idPlace,
                reviewContentId: place.idPlace,
                name: place.name,
                category: DetailCategory.activities,
                images: images,
                rating: place.averageRating ?? 0,
                reviewCount: place.reviewCount ?? 0,
                ratingLabel: (place.averageRating ?? 0).toStringAsFixed(1),
                description: description,
                whatToExpect: description,
                reviews: const <ItemReview>[],
              ),
              favoriteType: FavoriteType.place,
              favoriteRawId: place.idPlace,
              favoriteName: place.name,
              reviewContentType: ReviewContentType.place,
              showShareAction: true,
            );
          },
    );
  }
}
