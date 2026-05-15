import 'package:flutter/material.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/profile/data/wishlist_repository.dart';

import 'shared_item_detail_page.dart';

class LocalProductsDetailPage extends StatelessWidget {
  const LocalProductsDetailPage({super.key, required this.request});

  final ItemDetailRequest request;

  @override
  Widget build(BuildContext context) {
    return SharedItemDetailPage(
      request: request,
      favoriteType: FavoriteType.place,
    );
  }
}
