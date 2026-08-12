import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
import 'package:hellovietnam/features/planner/data/planner_province.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/data/reference_data_cache_repository.dart';
import 'package:hellovietnam/core/utils/vietnamese_text_utils.dart';

class TripLocationPage extends StatefulWidget {
  const TripLocationPage({super.key});

  @override
  State<TripLocationPage> createState() => _TripLocationPageState();
}

// Fallback shown when city_province table is empty / migration not yet applied.
const List<PlannerProvince> _kFallbackProvinces = <PlannerProvince>[
  PlannerProvince(id: 'halong', name: 'Ha Long Bay', area: 'Quang Ninh'),
  PlannerProvince(id: 'hoian', name: 'Hoi An', area: 'Quang Nam'),
  PlannerProvince(id: 'dalat', name: 'Da Lat', area: 'Lam Dong'),
  PlannerProvince(id: 'phuquoc', name: 'Phu Quoc', area: 'Kien Giang'),
  PlannerProvince(id: 'sapa', name: 'Sapa', area: 'Lao Cai'),
  PlannerProvince(id: 'nhatrang', name: 'Nha Trang', area: 'Khanh Hoa'),
];

class _TripLocationPageState extends State<TripLocationPage> {
  final TextEditingController _searchController = TextEditingController();
  List<PlannerProvince> _provinces = <PlannerProvince>[];
  String? _selectedId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadProvinces();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  Future<void> _loadProvinces() async {
    try {
      final List<ReferenceRecord> rows = await ReferenceDataCacheRepository
          .instance
          .getProvinces();

      if (!mounted) return;

      setState(() {
        _provinces = rows
            .map(PlannerProvince.fromReferenceRecord)
            .where(
              (PlannerProvince item) =>
                  item.id.isNotEmpty && item.name.isNotEmpty,
            )
            .take(100)
            .toList();

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _provinces = _kFallbackProvinces.toList();
        _isLoading = false;
      });
    }
  }

  List<PlannerProvince> get _filtered {
    final query = _searchController.text;
    if (query.trim().isEmpty) return _provinces;
    return _provinces
        .where(
          (p) =>
              matchesSearchQuery(query, p.name) ||
              matchesSearchQuery(query, p.area),
        )
        .toList();
  }

  void _onNext() {
    final selected = _provinces.firstWhere((p) => p.id == _selectedId);
    context.push(
      AppRoutes.tripPlannerDuration,
      extra: TripWizardData(
        idProvince: selected.id,
        provinceName: selected.name,
      ).toJson(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlannerStepScaffold(
      currentStep: 2,
      badgeIcon: Icons.location_on_outlined,
      title: 'Where to?',
      subtitle: 'Choose your dream destination',
      onBack: () => context.pop(),
      nextEnabled: _selectedId != null,
      onNext: _onNext,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _provinces.isEmpty
          ? const _EmptyView()
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SearchField(controller: _searchController),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.ui('Destinations'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    itemCount: _filtered.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.25,
                        ),
                    itemBuilder: (context, index) {
                      final p = _filtered[index];
                      return _DestinationCard(
                        item: p,
                        selected: p.id == _selectedId,
                        onTap: () => setState(() => _selectedId = p.id),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? theme.colorScheme.outline : const Color(0xFFC4F4FF),
          width: isDark ? 1.2 : 1.6,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.18)
                : const Color(0x260F2C4F),
            blurRadius: isDark ? 18 : 28,
            offset: Offset(0, isDark ? 8 : 14),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 24,
          ),
          hintText: context.l10n.ui('Search destination...'),
          hintStyle: TextStyle(
            fontSize: 15.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PlannerProvince item;
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
                  child: item.coverImage != null
                      ? Image.network(
                          item.coverImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const _PlaceholderBackground(),
                        )
                      : const _PlaceholderBackground(),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.32),
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
                        removeVietnameseDiacritics(item.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: Color(0xFF24B8EF),
                      child: Icon(Icons.check, size: 14, color: Colors.white),
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

class _PlaceholderBackground extends StatelessWidget {
  const _PlaceholderBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFE4F4FB),
            Color(0xFFD0EEF8),
            Color(0xFFB8E5F4),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.landscape_outlined,
          size: 46,
          color: Color(0xFF6BBFDC),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.l10n.ui('No destinations available yet.'),
        style: TextStyle(
          fontSize: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
