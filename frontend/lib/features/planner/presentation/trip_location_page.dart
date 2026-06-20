import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/planner_step_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripLocationPage extends StatefulWidget {
  const TripLocationPage({super.key});

  @override
  State<TripLocationPage> createState() => _TripLocationPageState();
}

// Fallback shown when city_province table is empty / migration not yet applied.
const List<_ProvinceItem> _kFallbackProvinces = <_ProvinceItem>[
  _ProvinceItem(id: 'halong',   name: 'Ha Long Bay', area: 'Quang Ninh'),
  _ProvinceItem(id: 'hoian',    name: 'Hoi An',      area: 'Quang Nam'),
  _ProvinceItem(id: 'dalat',    name: 'Da Lat',      area: 'Lam Dong'),
  _ProvinceItem(id: 'phuquoc',  name: 'Phu Quoc',    area: 'Kien Giang'),
  _ProvinceItem(id: 'sapa',     name: 'Sapa',        area: 'Lao Cai'),
  _ProvinceItem(id: 'nhatrang', name: 'Nha Trang',   area: 'Khanh Hoa'),
];

class _TripLocationPageState extends State<TripLocationPage> {
  final TextEditingController _searchController = TextEditingController();
  List<_ProvinceItem> _provinces = <_ProvinceItem>[];
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
      final rows = await Supabase.instance.client
          .from('old_province')
          .select('id_province, name')
          .order('name');
      if (!mounted) return;
      setState(() {
        _provinces = (rows as List<dynamic>)
            .map((r) => _ProvinceItem(
                  id: r['id_province'] as String,
                  name: r['name'] as String? ?? '',
                  area: '',
                ))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Table missing (migration not yet applied) or network error — use fallback.
      setState(() {
        _provinces = _kFallbackProvinces.toList();
        _isLoading = false;
      });
    }
  }

  List<_ProvinceItem> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _provinces;
    return _provinces
        .where((p) =>
            p.name.toLowerCase().contains(query) ||
            p.area.toLowerCase().contains(query))
        .toList();
  }

  void _onNext() {
    final selected = _provinces.firstWhere((p) => p.id == _selectedId);
    context.push(
      AppRoutes.tripPlannerDuration,
      extra: TripWizardData(
        idProvince: selected.id,
        provinceName: selected.name,
      ),
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
                          const Text(
                            'Destinations',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF162235),
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

class _ProvinceItem {
  const _ProvinceItem({required this.id, required this.name, required this.area});

  final String id;
  final String name;
  final String area;
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

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
        decoration: const InputDecoration(
          prefixIcon:
              Icon(Icons.search_rounded, color: Color(0xFF98A2B3), size: 24),
          hintText: 'Search destination...',
          hintStyle: TextStyle(
            fontSize: 15.5,
            color: Color(0xFF98A2B3),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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

  final _ProvinceItem item;
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
              color:
                  selected ? const Color(0xFF24B8EF) : const Color(0xFFC4F4FF),
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
                  child: Container(
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
                  ),
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
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (item.area.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          item.area,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No destinations available yet.',
        style: TextStyle(fontSize: 15, color: Color(0xFF8A95A5)),
      ),
    );
  }
}
