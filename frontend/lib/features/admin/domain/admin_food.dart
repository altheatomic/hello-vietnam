import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';

// ── Colour palette ────────────────────────────────────────────────────────────

/// Same 8-colour palette as the Popular Apps system, reused for food types.
const List<Color> foodTypeColorPalette = [
  AppColors.primary,        // 0  sky blue
  Color(0xFF22C55E),        // 1  green
  Color(0xFFF59E0B),        // 2  amber
  Color(0xFFF97316),        // 3  orange
  Color(0xFF9CA3AF),        // 4  slate grey  — Other / unknown
  Color(0xFF8B5CF6),        // 5  violet
  Color(0xFF06B6D4),        // 6  cyan
  Color(0xFFEC4899),        // 7  pink
];

// ── FoodType ──────────────────────────────────────────────────────────────────

/// Runtime-mutable food type, mirroring [AppCategory] from Popular Apps.
class FoodType {
  const FoodType({
    required this.id,
    required this.label,
    this.colorIndex = 0,
  });

  final String id;
  final String label;
  final int colorIndex;

  Color get color =>
      foodTypeColorPalette[colorIndex % foodTypeColorPalette.length];

  FoodType copyWith({String? id, String? label, int? colorIndex}) => FoodType(
        id:         id         ?? this.id,
        label:      label      ?? this.label,
        colorIndex: colorIndex ?? this.colorIndex,
      );
}

/// Default food types for mock/local state.
final List<FoodType> defaultFoodTypes = [
  const FoodType(id: 'street-food', label: 'Street Food', colorIndex: 3),
  const FoodType(id: 'noodles',     label: 'Noodles',     colorIndex: 0),
  const FoodType(id: 'rice',        label: 'Rice',        colorIndex: 1),
  const FoodType(id: 'grilled',     label: 'Grilled',     colorIndex: 2),
  const FoodType(id: 'dessert',     label: 'Dessert',     colorIndex: 7),
  const FoodType(id: 'drinks',      label: 'Drinks',      colorIndex: 6),
  const FoodType(id: 'other',       label: 'Other',       colorIndex: 4),
];

// ── AdminFood ─────────────────────────────────────────────────────────────────

/// Domain model for the admin food management table.
class AdminFood {
  const AdminFood({
    required this.id,
    required this.name,
    required this.typeId,
    required this.city,
    this.urlImage,
    this.description,
  });

  final String id;
  final String name;

  /// Foreign key referencing [FoodType.id].
  final String typeId;

  /// City or province where this dish is representative.
  final String city;

  final String? urlImage;
  final String? description;

  bool get hasImage => urlImage != null && urlImage!.isNotEmpty;

  AdminFood copyWith({
    String? id,
    String? name,
    String? typeId,
    String? city,
    String? urlImage,
    String? description,
  }) {
    return AdminFood(
      id:          id          ?? this.id,
      name:        name        ?? this.name,
      typeId:      typeId      ?? this.typeId,
      city:        city        ?? this.city,
      urlImage:    urlImage    ?? this.urlImage,
      description: description ?? this.description,
    );
  }
}
