import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';

class TripLocationPage extends StatefulWidget {
  const TripLocationPage({super.key});

  @override
  State<TripLocationPage> createState() => _TripLocationPageState();
}

class _TripLocationPageState extends State<TripLocationPage> {
  static const List<_DestinationCardData>
  _allDestinations = <_DestinationCardData>[
    _DestinationCardData(
      id: 'halong',
      name: 'Ha Long Bay',
      region: 'Quang Ninh',
      imageUrl:
          'https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&w=900&q=80',
    ),
    _DestinationCardData(
      id: 'hoian',
      name: 'Hoi An',
      region: 'Quang Nam',
      imageUrl:
          'https://images.unsplash.com/photo-1583417319070-4a69db38a482?auto=format&fit=crop&w=900&q=80',
    ),
    _DestinationCardData(
      id: 'dalat',
      name: 'Da Lat',
      region: 'Lam Dong',
      imageUrl:
          'https://images.unsplash.com/photo-1521295121783-8a321d551ad2?auto=format&fit=crop&w=900&q=80',
    ),
    _DestinationCardData(
      id: 'phuquoc',
      name: 'Phu Quoc',
      region: 'Kien Giang',
      imageUrl:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=900&q=80',
    ),
    _DestinationCardData(id: 'sapa', name: 'Sapa', region: 'Lao Cai'),
    _DestinationCardData(
      id: 'nhatrang',
      name: 'Nha Trang',
      region: 'Khanh Hoa',
      imageUrl:
          'https://images.unsplash.com/photo-1526481280695-3c4691f7d2d5?auto=format&fit=crop&w=900&q=80',
    ),
  ];

  final TextEditingController _searchController = TextEditingController();
  String? _selectedDestinationId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {});
  }

  List<_DestinationCardData> get _filteredDestinations {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _allDestinations;
    return _allDestinations.where((_DestinationCardData item) {
      return item.name.toLowerCase().contains(query) ||
          item.region.toLowerCase().contains(query);
    }).toList();
  }

  void _showNextPlaceholder() {
    context.push(AppRoutes.tripPlannerDuration);
  }

  @override
  Widget build(BuildContext context) {
    final List<_DestinationCardData> visibleDestinations =
        _filteredDestinations;

    return PlannerStepScaffold(
      currentStep: 2,
      badgeIcon: Icons.location_on_outlined,
      title: context.l10n.ui('Where to?'),
      subtitle: context.l10n.ui('Choose your dream destination'),
      onBack: () => context.pop(),
      nextEnabled: _selectedDestinationId != null,
      onNext: _showNextPlaceholder,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SearchDestinationField(controller: _searchController),
            const SizedBox(height: 18),
            Text(
              context.l10n.ui('Popular Destinations'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF162235),
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              itemCount: visibleDestinations.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              itemBuilder: (BuildContext context, int index) {
                final _DestinationCardData destination =
                    visibleDestinations[index];
                return _DestinationCard(
                  data: destination,
                  selected: destination.id == _selectedDestinationId,
                  onTap: () {
                    setState(() {
                      _selectedDestinationId = destination.id;
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchDestinationField extends StatelessWidget {
  const _SearchDestinationField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC4F4FF), width: 1.6),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x260F2C4F),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          color: Color(0xFF162235),
        ),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF98A2B3),
            size: 24,
          ),
          hintText: context.l10n.ui('Search destination...'),
          hintStyle: const TextStyle(
            fontSize: 15.5,
            color: Color(0xFF98A2B3),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _DestinationCardData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFF24B8EF)
                  : const Color(0xFFC4F4FF),
              width: selected ? 2.2 : 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: selected
                    ? const Color(0x2624B8EF)
                    : const Color(0x260F2C4F),
                blurRadius: selected ? 24 : 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: data.imageUrl == null
                      ? Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xFFF4F4F6),
                                Color(0xFFD8D9DD),
                                Color(0xFF737577),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 54,
                              color: Color(0xFF303236),
                            ),
                          ),
                        )
                      : Image.network(
                          data.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return Container(
                                  color: const Color(0xFFD6D9E0),
                                );
                              },
                        ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.02),
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.46),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        data.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.region,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationCardData {
  const _DestinationCardData({
    required this.id,
    required this.name,
    required this.region,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String region;
  final String? imageUrl;
}
