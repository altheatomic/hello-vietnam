import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';

// ── Colour palette ────────────────────────────────────────────────────────────

/// Fixed 8-colour palette indexed by [AppCategory.colorIndex].
/// Admin picks a colour when creating / editing a category.
const List<Color> categoryColorPalette = [
  AppColors.primary,          // 0  sky blue   — default for Transport
  Color(0xFF22C55E),          // 1  green       — Chat
  Color(0xFFF59E0B),          // 2  amber       — Payment
  Color(0xFFF97316),          // 3  orange      — Delivery
  Color(0xFF9CA3AF),          // 4  slate grey  — Other / unknown
  Color(0xFF8B5CF6),          // 5  violet
  Color(0xFF06B6D4),          // 6  cyan
  Color(0xFFEC4899),          // 7  pink
];

// ── AppCategory ───────────────────────────────────────────────────────────────

/// A runtime-mutable category, replacing the old compile-time enum.
///
/// [id] is used as the stable foreign key stored on [PopularAppGuide].
/// [colorIndex] indexes into [categoryColorPalette].
class AppCategory {
  const AppCategory({
    required this.id,
    required this.label,
    this.colorIndex = 0,
  });

  final String id;
  final String label;
  final int colorIndex;

  Color get color =>
      categoryColorPalette[colorIndex % categoryColorPalette.length];

  AppCategory copyWith({String? id, String? label, int? colorIndex}) =>
      AppCategory(
        id:         id         ?? this.id,
        label:      label      ?? this.label,
        colorIndex: colorIndex ?? this.colorIndex,
      );
}

/// Default category list — mirrors the five values the old enum had.
/// The page state initialises from this list so the data survives
/// hot-reload; swap for a Supabase fetch when the backend is wired.
final List<AppCategory> defaultAppCategories = [
  const AppCategory(id: 'transport', label: 'Transport', colorIndex: 0),
  const AppCategory(id: 'chat',      label: 'Chat',      colorIndex: 1),
  const AppCategory(id: 'payment',   label: 'Payment',   colorIndex: 2),
  const AppCategory(id: 'delivery',  label: 'Delivery',  colorIndex: 3),
  const AppCategory(id: 'other',     label: 'Other',     colorIndex: 4),
];

// ── PopularAppGuide ───────────────────────────────────────────────────────────

/// Guide post domain model.
///
/// [categoryId] is a string foreign key that references [AppCategory.id].
class PopularAppGuide {
  const PopularAppGuide({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.packageName,
    required this.storeUrl,
    required this.createdAt,
    this.description,
    this.guide,
    this.urlImage,
    this.urlVideo,
  });

  final String id;
  final String name;

  /// Short teaser shown on list / card views (1–3 sentences).
  final String? description;

  /// Full how-to body shown on the guide detail screen.
  final String? guide;

  /// References [AppCategory.id].
  final String categoryId;

  final String? urlImage;
  final String? urlVideo;
  final String packageName;
  final String storeUrl;
  final DateTime createdAt;

  bool get hasImage => urlImage != null && urlImage!.isNotEmpty;
  bool get hasVideo => urlVideo != null && urlVideo!.isNotEmpty;

  PopularAppGuide copyWith({
    String? id,
    String? name,
    String? description,
    String? guide,
    String? categoryId,
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
      categoryId:  categoryId  ?? this.categoryId,
      urlImage:    urlImage    ?? this.urlImage,
      urlVideo:    urlVideo    ?? this.urlVideo,
      packageName: packageName ?? this.packageName,
      storeUrl:    storeUrl    ?? this.storeUrl,
      createdAt:   createdAt   ?? this.createdAt,
    );
  }
}
