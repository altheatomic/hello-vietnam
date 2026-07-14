import 'package:flutter/material.dart';
import 'package:hellovietnam/app/router.dart';
import '../domain/destination.dart';
import '../domain/dish.dart';
import '../domain/feature_item.dart';

/// ---------------------------------------------------------------
/// Mock data — swap this file with an API repository in the future.
/// ---------------------------------------------------------------

const List<FeatureItem> homeFeatures = [
  FeatureItem(
    title: 'Trip Planner',
    icon: Icons.luggage_outlined,
    route: AppRoutes.tripPlanner,
  ),
  FeatureItem(
    title: 'Forum',
    icon: Icons.forum_outlined,
    route: AppRoutes.forum,
  ),
  FeatureItem(
    title: 'Translate',
    icon: Icons.translate_outlined,
    route: AppRoutes.translate,
  ),
  FeatureItem(
    title: 'Send\nReport',
    icon: Icons.report_problem_outlined,
    route: AppRoutes.feedback,
  ),
  FeatureItem(
    title: 'Recommend',
    icon: Icons.recommend_outlined,
    route: AppRoutes.recommend,
  ),
  FeatureItem(
    title: 'Explore',
    icon: Icons.explore_outlined,
    route: AppRoutes.explore,
  ),
  FeatureItem(
    title: 'Popular\nApps',
    icon: Icons.apps_outlined,
    route: AppRoutes.popularApps,
  ),
  FeatureItem(
    title: 'AI Search',
    icon: Icons.auto_awesome_outlined,
    route: AppRoutes.aiSearch,
  ),
];

const List<Destination> mockDestinations = [
  Destination(
    id: '1',
    name: 'Nha Trang',
    category: 'Beach · Seafood',
    rating: 4.33,
    imagePath: 'assets/images/homepage/bestdestination_bg.jpeg',
  ),
  Destination(
    id: '2',
    name: 'Da Lat',
    category: 'Nature · Highland',
    rating: 4.55,
    imagePath: 'assets/images/explore/explore_bg.jpeg',
  ),
  Destination(
    id: '3',
    name: 'Ho Chi Minh City',
    category: 'City · Culture',
    rating: 4.40,
    imagePath: 'assets/images/Auth_Image/Vietnam.jpg',
  ),
  Destination(
    id: '4',
    name: 'Ha Noi',
    category: 'History · Culture',
    rating: 4.50,
    imagePath: 'assets/images/recommend/where.png',
  ),
];

const List<Dish> mockDishes = [
  Dish(
    id: '1',
    name: 'Bun Bo Hue',
    category: 'Traditional · Main course',
    rating: 4.33,
    imagePath: 'assets/images/homepage/bestdishes_bg.jpeg',
  ),
  Dish(
    id: '2',
    name: 'Bun Ca',
    category: 'Traditional · Main course',
    rating: 4.20,
    imagePath: 'assets/images/explore/explore_bg.jpeg',
  ),
  Dish(
    id: '3',
    name: 'Pho',
    category: 'Traditional · Soup',
    rating: 4.70,
    imagePath: 'assets/images/Auth_Image/Login.png',
  ),
  Dish(
    id: '4',
    name: 'Banh Mi',
    category: 'Street food · Snack',
    rating: 4.60,
    imagePath: 'assets/images/homepage/bestdishes_bg.jpeg',
  ),
];
