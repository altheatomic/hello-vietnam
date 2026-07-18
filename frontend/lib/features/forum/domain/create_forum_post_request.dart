import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';

class CreateForumPostRequest {
  final SharedExploreItem? sharedExploreItem;

  const CreateForumPostRequest({this.sharedExploreItem});
}

class SharedExploreItem {
  final String contentType;
  final String contentId;
  final String? provinceId;
  final String title;
  final String imagePath;
  final DetailCategory category;
  final String? subtitle;
  final String? provinceName;
  final String? labelOverride;

  const SharedExploreItem({
    required this.contentType,
    required this.contentId,
    required this.provinceId,
    required this.title,
    required this.imagePath,
    required this.category,
    this.subtitle,
    this.provinceName,
    this.labelOverride,
  });

  factory SharedExploreItem.fromJson(Map<String, dynamic> json) {
    return SharedExploreItem(
      contentType: (json['contentType'] as String? ?? '').trim(),
      contentId: (json['contentId'] as String? ?? '').trim(),
      provinceId: (json['provinceId'] as String?)?.trim(),
      title: (json['title'] as String? ?? '').trim(),
      imagePath: (json['imagePath'] as String? ?? '').trim(),
      category: _parseDetailCategory(json['category'] as String?),
      subtitle: (json['subtitle'] as String?)?.trim(),
      provinceName: (json['provinceName'] as String?)?.trim(),
      labelOverride: (json['labelOverride'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'contentType': contentType,
      'contentId': contentId,
      'provinceId': provinceId,
      'title': title,
      'imagePath': imagePath,
      'category': category.storageKey,
      'subtitle': subtitle,
      'provinceName': provinceName,
      'labelOverride': labelOverride,
    };
  }

  ItemDetailRequest toItemDetailRequest({bool trackExploreBehavior = true}) {
    return ItemDetailRequest(
      id: contentId,
      name: title,
      category: category,
      fallbackImages: imagePath.trim().isEmpty
          ? const <String>[]
          : <String>[imagePath],
      fallbackImagePath: imagePath.trim().isEmpty ? null : imagePath,
      trackExploreBehavior: trackExploreBehavior,
      exploreProvinceId: provinceId,
    );
  }
}

DetailCategory _parseDetailCategory(String? rawValue) {
  final String raw = (rawValue ?? '').trim().toLowerCase();
  switch (raw) {
    case 'culture':
      return DetailCategory.culture;
    case 'food':
      return DetailCategory.food;
    case 'local_product':
    case 'local_products':
      return DetailCategory.localProducts;
    case 'activity':
    case 'activities':
    default:
      return DetailCategory.activities;
  }
}
