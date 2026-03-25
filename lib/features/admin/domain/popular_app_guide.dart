// Domain model for the Popular App Guide admin feature.
//
// Reflects the approved schema from the data-model review:
//   id, name, description, guide, category,
//   url_image, url_video, package_name, store_url, created_at

enum PopularAppCategory {
  transport,
  chat,
  payment,
  delivery,
  other;

  String get label {
    switch (this) {
      case PopularAppCategory.transport: return 'Transport';
      case PopularAppCategory.chat:      return 'Chat';
      case PopularAppCategory.payment:   return 'Payment';
      case PopularAppCategory.delivery:  return 'Delivery';
      case PopularAppCategory.other:     return 'Other';
    }
  }
}

class PopularAppGuide {
  const PopularAppGuide({
    required this.id,
    required this.name,
    required this.category,
    required this.packageName,
    required this.storeUrl,
    required this.createdAt,
    this.description,
    this.guide,
    this.urlImage,
    this.urlVideo,
  });

  final String id;

  /// Display name shown to end users.
  final String name;

  /// Short teaser shown on list/card views (1–3 sentences).
  final String? description;

  /// Full how-to body shown on the guide detail screen.
  final String? guide;

  final PopularAppCategory category;

  /// Cover image URL.
  final String? urlImage;

  /// Optional video URL.
  final String? urlVideo;

  /// Android package name used to check if app is installed.
  /// e.g. "com.grabtaxi.passenger"
  final String packageName;

  /// Direct Play Store / App Store link for the "Download App" button.
  final String storeUrl;

  final DateTime createdAt;

  bool get hasImage => urlImage != null && urlImage!.isNotEmpty;
  bool get hasVideo => urlVideo != null && urlVideo!.isNotEmpty;

  PopularAppGuide copyWith({
    String? id,
    String? name,
    String? description,
    String? guide,
    PopularAppCategory? category,
    String? urlImage,
    String? urlVideo,
    String? packageName,
    String? storeUrl,
    DateTime? createdAt,
  }) {
    return PopularAppGuide(
      id:          id          ?? this.id,
      name:        name        ?? this.name,
      description: description ?? this.description,
      guide:       guide       ?? this.guide,
      category:    category    ?? this.category,
      urlImage:    urlImage    ?? this.urlImage,
      urlVideo:    urlVideo    ?? this.urlVideo,
      packageName: packageName ?? this.packageName,
      storeUrl:    storeUrl    ?? this.storeUrl,
      createdAt:   createdAt   ?? this.createdAt,
    );
  }
}
