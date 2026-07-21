import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

/// A single item in the Explore page (activity, cultural site, dish, product).
class ExploreItem {
  final String id;
  final String name;
  final String imagePath; // asset or network URL
  final String? subtitle;
  final String? provinceId;
  final String? provinceName;
  final double? rating;
  final int reviewCount;
  final DetailCategory category;

  const ExploreItem({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.category,
    this.subtitle,
    this.provinceId,
    this.provinceName,
    this.rating,
    this.reviewCount = 0,
  });

  factory ExploreItem.fromJson(Map<String, dynamic> json) {
    return ExploreItem(
      id: _readRequiredString(json['id']),
      name: _readRequiredString(json['name']),
      imagePath: _readRequiredString(json['imagePath']),
      category: _parseDetailCategory(
        _readNullableString(json['category']) ?? 'activities',
      ),
      subtitle: _readNullableString(json['subtitle']),
      provinceId: _readNullableString(json['provinceId']),
      provinceName: _readNullableString(json['provinceName']),
      rating: _readNullableDouble(json['rating']),
      reviewCount: _readNullableInt(json['reviewCount']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'category': category.storageKey,
      'subtitle': subtitle,
      'provinceId': provinceId,
      'provinceName': provinceName,
      'rating': rating,
      'reviewCount': reviewCount,
    };
  }
}

double? _readNullableDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int? _readNullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _readRequiredString(Object? value) {
  final String? normalized = _readNullableString(value);
  return normalized ?? '';
}

String? _readNullableString(Object? value) {
  if (value is String) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  return null;
}

DetailCategory _parseDetailCategory(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'culture':
      return DetailCategory.culture;
    case 'food':
      return DetailCategory.food;
    case 'local_products':
    case 'local product':
    case 'local products':
      return DetailCategory.localProducts;
    case 'activities':
    case 'activity':
    default:
      return DetailCategory.activities;
  }
}

/// A category section (e.g. "Activities") containing a description and items.
class ExploreCategory {
  final String id;
  final String title; // tab label: "Activities", "Culture", etc.
  final String description; // subtitle shown under the tab content
  final List<ExploreItem> items;
  final String? emptyMessage;

  const ExploreCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.items,
    this.emptyMessage,
  });

  factory ExploreCategory.fromJson(Map<String, dynamic> json) {
    final List<Object?> rawItems = json['items'] is List
        ? (json['items'] as List<Object?>)
        : const <Object?>[];

    return ExploreCategory(
      id: (json['id'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      items: rawItems
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> item) => ExploreItem.fromJson(
              item.map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            ),
          )
          .toList(growable: false),
      emptyMessage: (json['emptyMessage'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'items': items.map((ExploreItem item) => item.toJson()).toList(),
      'emptyMessage': emptyMessage,
    };
  }
}
