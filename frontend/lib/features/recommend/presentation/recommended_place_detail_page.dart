import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/item_detail/presentation/shared_item_detail_page.dart';
import 'package:hellovietnam/features/data_freshness/domain/content_freshness_models.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';
import 'package:hellovietnam/features/reviews/domain/review_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/recommend_repository.dart';

String recommendedPlaceDescription(ProvinceTopPlace place, String fallback) {
  final String detailed = place.detailedDescription?.trim() ?? '';
  if (detailed.isNotEmpty) return detailed;
  final String short = place.shortDescription?.trim() ?? '';
  return short.isNotEmpty ? short : fallback;
}

class RecommendedPlaceDetailPage extends StatefulWidget {
  const RecommendedPlaceDetailPage({
    super.key,
    this.idProvince,
    required this.idPlace,
  });

  final String? idProvince;
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
    final String? idProvince = widget.idProvince?.trim();
    if (idProvince == null || idProvince.isEmpty) {
      return RecommendRepository().getPlaceById(widget.idPlace);
    }
    final ProvinceDetail detail = await RecommendRepository()
        .getTopPlacesForProvince(idProvince);
    for (final ProvinceTopPlace place in detail.topPlaces) {
      if (place.idPlace == widget.idPlace) return place;
    }
    return RecommendRepository().getPlaceById(widget.idPlace);
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
            final String? coverImage =
                place.coverImage?.trim().isNotEmpty == true
                ? place.coverImage!.trim()
                : null;
            final List<String> galleryImages = place.gallery
                .map((String image) => image.trim())
                .where(
                  (String image) => image.isNotEmpty && image != coverImage,
                )
                .toList(growable: false);
            final List<String> images = coverImage == null
                ? galleryImages.take(1).toList(growable: false)
                : <String>[coverImage];
            final String fallbackDescription = <String>[
              if (place.subcategoryName?.trim().isNotEmpty == true)
                place.subcategoryName!,
              if (place.address?.trim().isNotEmpty == true) place.address!,
            ].join(' · ');

            final String description = recommendedPlaceDescription(
              place,
              fallbackDescription,
            );
            final List<String> metadata = _placeMetadata(context, place);

            return SharedItemDetailPage(
              detail: ItemDetail(
                id: place.idPlace,
                reviewContentId: place.idPlace,
                name: place.name,
                category: DetailCategory.activities,
                images: images,
                coverImage: coverImage,
                galleryImages: galleryImages,
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
              showFeedbackAction: false,
              quickInfoMetadata: metadata,
              showShareAction: true,
              reportContentType: FreshnessContentType.place,
            );
          },
    );
  }
}

List<String> _placeMetadata(BuildContext context, ProvinceTopPlace place) {
  final List<String> metadata = <String>[];
  final int? duration = place.estimatedDurationMinutes;
  if (duration != null && duration > 0) {
    final int hours = duration ~/ 60;
    final int minutes = duration % 60;
    final String value = hours == 0
        ? '$minutes ${context.l10n.ui('min')}'
        : minutes == 0
        ? '$hours${context.l10n.ui('h')}'
        : '$hours${context.l10n.ui('h')} $minutes${context.l10n.ui('m')}';
    metadata.add('${context.l10n.ui('Duration')}: $value');
  }

  final num? minimum = place.minimumPrice;
  final num? maximum = place.maximumPrice;
  if (minimum != null || maximum != null) {
    final String value;
    if (minimum != null && maximum != null) {
      value = '${_formatVnd(minimum)} - ${_formatVnd(maximum)}';
    } else if (minimum != null) {
      value = '${context.l10n.ui('From')} ${_formatVnd(minimum)}';
    } else {
      value = '${context.l10n.ui('Up to')} ${_formatVnd(maximum!)}';
    }
    metadata.add('${context.l10n.ui('Price')}: $value');
  }

  final String? phone = _nonEmpty(place.phone);
  if (phone != null) {
    metadata.add('${context.l10n.ui('Phone')}: $phone');
  }
  final String? website = _nonEmpty(place.website);
  if (website != null) {
    metadata.add('${context.l10n.ui('Website')}: $website');
  }
  final String? address = _nonEmpty(place.address);
  if (address != null) {
    metadata.add('${context.l10n.ui('Address')}: $address');
  }
  final String? opens = _nonEmpty(place.timespan);
  final String? closes = _nonEmpty(place.timeclose);
  if (opens != null && closes != null) {
    metadata.add('${context.l10n.ui('Open')} $opens - $closes');
  }
  return metadata;
}

String? _nonEmpty(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _formatVnd(num value) {
  final String digits = value.round().toString();
  final StringBuffer result = StringBuffer();
  for (int index = 0; index < digits.length; index++) {
    result.write(digits[index]);
    final int remaining = digits.length - index - 1;
    if (remaining > 0 && remaining % 3 == 0) result.write(',');
  }
  return '$result VND';
}
