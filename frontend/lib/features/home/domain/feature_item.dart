import 'package:flutter/material.dart';

/// A single quick-action button on the home screen grid.
class FeatureItem {
  final String title;
  final IconData icon;
  final String route;

  const FeatureItem({
    required this.title,
    required this.icon,
    required this.route,
  });
}
