import 'package:flutter/material.dart';

class PopularAppsItem {
  const PopularAppsItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.rating,
    required this.downloads,
    required this.logoUrl,
    required this.gradientColors,
    required this.accentColor,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final double rating;
  final String downloads;
  final String logoUrl;
  final List<Color> gradientColors;
  final Color accentColor;
}
