import 'package:flutter/material.dart';

class PopularAppsItem {
  const PopularAppsItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.logo,
    required this.badgeColor,
    required this.badgeTextColor,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String logo;
  final Color badgeColor;
  final Color badgeTextColor;
}
