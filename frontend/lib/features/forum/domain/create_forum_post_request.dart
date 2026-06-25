import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

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

  const SharedExploreItem({
    required this.contentType,
    required this.contentId,
    required this.provinceId,
    required this.title,
    required this.imagePath,
    required this.category,
  });
}
