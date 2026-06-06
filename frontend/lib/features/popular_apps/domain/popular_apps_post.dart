import 'package:flutter/material.dart';

class PopularAppsPost {
  const PopularAppsPost({
    required this.appId,
    required this.title,
    required this.ctaLabel,
    required this.summaryTitle,
    required this.summaryBody,
    required this.stepsTitle,
    required this.steps,
    required this.logoUrl,
    required this.accentColor,
    required this.downloadUrl,
    required this.imageUrl,
    this.galleryImages = const <String>[],
  });

  final String appId;
  final String title;
  final String ctaLabel;
  final String summaryTitle;
  final String summaryBody;
  final String stepsTitle;
  final List<String> steps;
  final String logoUrl;
  final Color accentColor;
  final String downloadUrl;
  final String imageUrl;
  final List<String> galleryImages;
}
