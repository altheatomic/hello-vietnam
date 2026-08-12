import 'package:flutter/material.dart';
import 'package:hellovietnam/app/router.dart';

import '../domain/feature_item.dart';

const List<FeatureItem> homeFeatures = <FeatureItem>[
  FeatureItem(
    title: 'Recommend',
    icon: Icons.recommend_outlined,
    route: AppRoutes.recommendWhereSearch,
  ),
  FeatureItem(
    title: 'Explore',
    icon: Icons.explore_outlined,
    route: AppRoutes.explore,
  ),
  FeatureItem(
    title: 'Trip Planner',
    icon: Icons.luggage_outlined,
    route: AppRoutes.tripPlanner,
  ),
  FeatureItem(
    title: 'Forum',
    icon: Icons.forum_outlined,
    route: AppRoutes.messages,
  ),
  FeatureItem(
    title: 'Translate',
    icon: Icons.translate_outlined,
    route: AppRoutes.translate,
  ),
  FeatureItem(
    title: 'AI Search',
    icon: Icons.auto_awesome_outlined,
    route: AppRoutes.aiSearch,
  ),
  FeatureItem(
    title: 'Send\nReport',
    icon: Icons.report_problem_outlined,
    route: AppRoutes.feedback,
  ),
  FeatureItem(
    title: 'Popular\nApps',
    icon: Icons.apps_outlined,
    route: AppRoutes.popularApps,
  ),
];
