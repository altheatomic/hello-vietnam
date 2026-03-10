import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';

import '../data/explore_mock_data.dart';
import '../domain/explore_destination.dart';
import 'widgets/search_filter_bar.dart';
import 'widgets/category_tabs.dart';
import 'widgets/destination_card.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String _selectedCategory = 'Beach';
  late List<ExploreDestination> _filteredDestinations;

  @override
  void initState() {
    super.initState();
    _updateFilteredDestinations();
  }

  void _updateFilteredDestinations() {
    setState(() {
      if (_selectedCategory == 'All') {
        _filteredDestinations = List.from(exploreDestinations);
      } else {
        _filteredDestinations = exploreDestinations
            .where((dest) => dest.category == _selectedCategory)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            // ── Header with search ──────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              elevation: 0,
              expandedHeight: 0,
              collapsedHeight: kToolbarHeight + statusBarHeight + 80,
              toolbarHeight: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: Colors.white,
                  padding: EdgeInsets.only(
                    top: statusBarHeight + 12,
                    left: AppConstants.pagePadding,
                    right: AppConstants.pagePadding,
                    bottom: 16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SearchFilterBar(
                        onSearchTap: () {
                          // TODO: Navigate to advanced search
                        },
                        onFilterTap: () {
                          // TODO: Show filter options
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),

            // ── Category Tabs ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: CategoryTabs(
                  categories: exploreCategories,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (category) {
                    _selectedCategory = category;
                    _updateFilteredDestinations();
                  },
                ),
              ),
            ),

            // ── Destination List ────────────────────────
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final destination = _filteredDestinations[index];
                  return DestinationCard(
                    destination: destination,
                    onTap: () {
                      // TODO: Navigate to detail page
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${destination.name} tapped'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    onFavoriteChanged: (isFavorite) {
                      // TODO: Save favorite to database
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFavorite 
                              ? '❤️ Added to wishlist' 
                              : '💔 Removed from wishlist',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
                childCount: _filteredDestinations.length,
              ),
            ),

            // ── Bottom padding ──────────────────────────
            SliverToBoxAdapter(
              child: const SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }
}
