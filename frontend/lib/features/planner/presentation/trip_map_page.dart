import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/core/config/app_identity.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/utils/maps_launcher.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';
import 'package:latlong2/latlong.dart';

class TripMapPage extends StatefulWidget {
  const TripMapPage({
    super.key,
    required this.dayIndex,
    required this.activityIndex,
    this.activity,
  });

  final int dayIndex;
  final int activityIndex;
  final TripPlannerActivityData? activity;

  @override
  State<TripMapPage> createState() => _TripMapPageState();
}

class _TripMapPageState extends State<TripMapPage> {
  late final TripPlannerActivityData _activity;
  List<TripPlannerNearbyPlace> _places = <TripPlannerNearbyPlace>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _activity =
        widget.activity ??
        TripPlannerMockData.activityAt(widget.dayIndex, widget.activityIndex);
    _loadNearby();
  }

  Future<void> _loadNearby() async {
    final double lat = _activity.lat;
    final double lng = _activity.lng;
    if (lat == 0.0 && lng == 0.0) {
      setState(() {
        _places = _activity.nearbyPlaces;
        _loading = false;
      });
      return;
    }
    try {
      final nearby = await TripRepository().getNearbyPlaces(lat, lng);
      if (!mounted) return;
      setState(() {
        _places = nearby
            .map(
              (p) => TripPlannerNearbyPlace(
                title: p.name,
                subtitle: p.subcategoryName,
                distance: p.distanceKm < 1
                    ? '${(p.distanceKm * 1000).round()}m'
                    : '${p.distanceKm.toStringAsFixed(1)}km',
                eta: '${p.estimatedMinutes} mins',
                lat: p.latitude,
                lng: p.longitude,
              ),
            )
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _places = _activity.nearbyPlaces;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Real map fills the screen
          _RealMap(
            activity: _activity,
            places: _loading ? <TripPlannerNearbyPlace>[] : _places,
          ),

          // Decorative blur orbs
          const Positioned(
            top: -90,
            right: -60,
            child: IgnorePointer(
              child: _DecorativeOrb(size: 220, color: Color(0x332BC3FF)),
            ),
          ),
          const Positioned(
            bottom: 240,
            left: -40,
            child: IgnorePointer(
              child: _DecorativeOrb(size: 180, color: Color(0x3356E2D5)),
            ),
          ),

          // Header card (back + title)
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: <Widget>[
                      _BackButtonCircle(onTap: () => context.pop()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFD8F2FF),
                              width: 1.2,
                            ),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x220F2C4F),
                                blurRadius: 22,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                context.l10n.ui(_activity.title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                context.l10n.ui(_activity.distanceLabel),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Pushes result sheet to bottom
                const Spacer(),

                _ResultSheet(
                  places: _places,
                  loading: _loading,
                  originLat: _activity.lat,
                  originLng: _activity.lng,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Real map ──────────────────────────────────────────────────────────────────

class _RealMap extends StatelessWidget {
  const _RealMap({required this.activity, required this.places});

  final TripPlannerActivityData activity;
  final List<TripPlannerNearbyPlace> places;

  @override
  Widget build(BuildContext context) {
    final bool hasCoords = activity.lat != 0.0 || activity.lng != 0.0;
    final LatLng center = hasCoords
        ? LatLng(activity.lat, activity.lng)
        : const LatLng(21.0285, 105.8357); // fallback: Hanoi

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 15),
      children: <Widget>[
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: AppIdentity.androidApplicationId,
        ),
        MarkerLayer(
          markers: <Marker>[
            // Origin marker (red)
            if (hasCoords)
              Marker(
                point: LatLng(activity.lat, activity.lng),
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            // Nearby place markers (blue)
            ...places
                .where((p) => p.lat != 0.0 || p.lng != 0.0)
                .map(
                  (p) => Marker(
                    point: LatLng(p.lat, p.lng),
                    child: const Icon(
                      Icons.place,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

// ── Result sheet ──────────────────────────────────────────────────────────────

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.places,
    required this.loading,
    required this.originLat,
    required this.originLng,
  });

  final List<TripPlannerNearbyPlace> places;
  final bool loading;
  final double originLat;
  final double originLng;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 290,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x240F2C4F),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.ui('Nearby'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                context.l10n.ui('Sort by: Nearest'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.swap_vert_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : places.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.ui('No nearby places found.'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: places.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) {
                      return _NearbyPlaceTile(
                        place: places[index],
                        originLat: originLat,
                        originLng: originLng,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Nearby place tile ─────────────────────────────────────────────────────────

class _NearbyPlaceTile extends StatelessWidget {
  const _NearbyPlaceTile({
    required this.place,
    required this.originLat,
    required this.originLng,
  });

  final TripPlannerNearbyPlace place;
  final double originLat;
  final double originLng;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE8F3), width: 1.4),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x180F2C4F),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                _iconForType(place.subtitle),
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.ui(place.title),
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${context.l10n.ui(place.subtitle)} • ${place.distance}',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFC7DFFF)),
            ),
            child: Text(
              place.eta,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF286EF0),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => openGoogleMapsDirections(
                originLat: originLat,
                originLng: originLng,
                destLat: place.lat,
                destLng: place.lng,
              ),
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF13C5E8), Color(0xFF4A99F7)],
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x2213C5E8),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  context.l10n.ui('Route'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _iconForType(String type) {
    final String value = type.toLowerCase();
    if (value.contains('y tế') ||
        value.contains('bệnh viện') ||
        value.contains('hospital')) {
      return '🏥';
    }
    if (value.contains('nhà thuốc') || value.contains('pharmacy')) {
      return '💊';
    }
    if (value.contains('bến xe') ||
        value.contains('sân bay') ||
        value.contains('ga tàu') ||
        value.contains('transport')) {
      return '🚌';
    }
    if (value.contains('cafe')) return '☕';
    if (value.contains('shopping')) return '🛍️';
    return '📍';
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _BackButtonCircle extends StatelessWidget {
  const _BackButtonCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 22,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _DecorativeOrb extends StatelessWidget {
  const _DecorativeOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color,
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.02),
            ],
          ),
        ),
      ),
    );
  }
}
