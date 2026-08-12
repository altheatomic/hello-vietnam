import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/utils/maps_launcher.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';
import 'package:hellovietnam/features/planner/presentation/lunch_anchor_selector.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/lunch_discovery_card.dart';

typedef NearbyRestaurantsLauncher = Future<bool> Function({
  required double lat,
  required double lng,
  required String placeName,
  required String provinceName,
});

Future<bool> _openNearbyRestaurants({
  required double lat,
  required double lng,
  required String placeName,
  required String provinceName,
}) {
  return openGoogleMapsNearbyRestaurants(
    lat: lat,
    lng: lng,
    placeName: placeName,
    provinceName: provinceName,
  );
}

void _openDayRoute(List<TripPlannerActivityData> activities) {
  final realPlaces = activities.where((a) => a.tag != 'lunch_break').toList();
  if (realPlaces.isEmpty) return;
  if (realPlaces.length == 1) {
    openGoogleMapsPin(lat: realPlaces.first.lat, lng: realPlaces.first.lng);
    return;
  }
  final first = realPlaces.first;
  final last = realPlaces.last;
  final middle = realPlaces.sublist(1, realPlaces.length - 1);
  openGoogleMapsDirections(
    originLat: first.lat,
    originLng: first.lng,
    destLat: last.lat,
    destLng: last.lng,
    waypoints: middle.map((a) => (lat: a.lat, lng: a.lng)).toList(),
  );
}

class TripDayDetailPage extends StatelessWidget {
  const TripDayDetailPage({
    super.key,
    required this.dayIndex,
    this.dayData,
    this.nearbyRestaurantsLauncher = _openNearbyRestaurants,
  });

  final int dayIndex;
  final TripPlannerDayData? dayData;
  final NearbyRestaurantsLauncher nearbyRestaurantsLauncher;

  @override
  Widget build(BuildContext context) {
    final TripPlannerDayData day =
        dayData ?? TripPlannerMockData.dayAt(dayIndex);
    // includeLunchBreak is the explicit plan-level signal for whether this
    // trip reserved a lunch break at all — selectLunchAnchor() only picks
    // an anchor place and has no way to distinguish "user opted out of
    // lunch" from "lunch got dropped for some other reason", so it must
    // not be relied on alone to decide whether to show the card.
    final TripPlannerActivityData? lunchAnchor = day.includeLunchBreak
        ? selectLunchAnchor(day.activities)
        : null;
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<Color> pageColors = isDark
        ? const <Color>[Color(0xFF020B10), Color(0xFF0B1A22), Color(0xFF0B2426)]
        : const <Color>[
            Color(0xFFF1F6FE),
            Color(0xFFDFF5FF),
            Color(0xFFCCF6F1),
          ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: pageColors,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -90,
              right: -60,
              child: _DecorativeOrb(
                size: 220,
                color: Color(isDark ? 0x332BC3FF : 0x662BC3FF),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -40,
              child: _DecorativeOrb(
                size: 180,
                color: Color(isDark ? 0x2856E2D5 : 0x5556E2D5),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _BackButtonCircle(onTap: () => context.pop()),
                    const SizedBox(height: 20),
                    _DayPill(label: context.l10n.ui(day.dayLabel)),
                    const SizedBox(height: 12),
                    Text(
                      day.date,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.ui(day.activityCountLabel),
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _GradientActionButton(
                      label: context.l10n.ui('Create Trip on Google Maps'),
                      onTap: () => _openDayRoute(day.activities),
                    ),
                    const SizedBox(height: 22),
                    ..._buildActivitySections(
                      context: context,
                      day: day,
                      dayIndex: dayIndex,
                      lunchAnchor: lunchAnchor,
                      nearbyRestaurantsLauncher: nearbyRestaurantsLauncher,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActivitySections({
    required BuildContext context,
    required TripPlannerDayData day,
    required int dayIndex,
    required TripPlannerActivityData? lunchAnchor,
    required NearbyRestaurantsLauncher nearbyRestaurantsLauncher,
  }) {
    final List<TripPlannerActivityData> realPlaces = day.activities
        .where((a) => a.tag != 'lunch_break')
        .toList(growable: false);
    final List<Widget> sections = <Widget>[];
    for (int index = 0; index < realPlaces.length; index++) {
      final TripPlannerActivityData activity = realPlaces[index];
      if (index > 0) {
        sections.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _TravelTimeRow(activity: activity),
          ),
        );
      }
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: _ActivityDetailCard(
            activity: activity,
            onImageTap: activity.idPlace.isNotEmpty
                ? () => context.push(
                    AppRoutes.recommendedPlaceDetailPath(
                      idProvince: activity.idProvince.isNotEmpty
                          ? activity.idProvince
                          : null,
                      idPlace: activity.idPlace,
                    ),
                  )
                : null,
            onDirections: () => context.push(
              AppRoutes.tripPlannerMapPath(dayIndex, index),
              extra: activity,
            ),
          ),
        ),
      );

      if (identical(activity, lunchAnchor)) {
        final bool hasCoordinates = hasValidMapCoordinates(
          lat: activity.lat,
          lng: activity.lng,
        );
        sections.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: LunchDiscoveryCard(
              key: const ValueKey<String>('lunch-discovery-card'),
              anchorName: context.l10n.ui(activity.title),
              enabled: hasCoordinates,
              onTap: hasCoordinates
                  ? () {
                      nearbyRestaurantsLauncher(
                        lat: activity.lat,
                        lng: activity.lng,
                        placeName: activity.title,
                        provinceName: day.provinceName,
                      );
                    }
                  : null,
            ),
          ),
        );
      }
    }
    return sections;
  }
}

class _ActivityDetailCard extends StatelessWidget {
  const _ActivityDetailCard({
    required this.activity,
    required this.onDirections,
    this.onImageTap,
  });

  final TripPlannerActivityData activity;
  final VoidCallback onDirections;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? theme.colorScheme.outline : const Color(0xFFD9EDF7),
          width: 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0x220F2C4F),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TimePill(time: activity.time),
          const SizedBox(height: 18),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onImageTap,
              child: SizedBox(
                height: 112,
                width: double.infinity,
                child: activity.imageUrl != null
                  ? Builder(
                      builder: (BuildContext context) {
                        debugPrint(
                          '[TripDayDetailPage.Image.network] imageUrl='
                          '${activity.imageUrl}',
                        );
                        return Image.network(
                          activity.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) {
                            debugPrint(
                              '[TripDayDetailPage.Image.network] load failed '
                              'imageUrl=${activity.imageUrl} error=$error',
                            );
                            return _ImagePlaceholder();
                          },
                        );
                      },
                    )
                    : _ImagePlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.ui(activity.title),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.2,
            ),
          ),
          if (activity.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: activity.tags
                  .map((String tag) => _CategoryChip(label: context.l10n.ui(tag)))
                  .toList(growable: false),
            ),
          ],
          if (_activityFacts(context, activity).isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _activityFacts(context, activity)
                  .map((String fact) => _FactChip(label: fact))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            context.l10n.ui(activity.description),
            style: TextStyle(
              fontSize: 15.5,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          _GradientActionButton(
            label: context.l10n.ui('Get Directions'),
            onTap: onDirections,
          ),
        ],
      ),
    );
  }
}

/// Travel time/distance row between two consecutive place cards, sourced
/// from Goong Distance Matrix data attached to `activity` (the edge FROM
/// the previous activity TO this one — see TripPlannerActivityData docs).
/// Renders bike first, then car; hides entirely if neither has data, and
/// hides a single line if only one vehicle has data (both are edge cases
/// covered by the backend's per-day all-or-nothing Goong fallback).
class _TravelTimeRow extends StatelessWidget {
  const _TravelTimeRow({required this.activity});

  final TripPlannerActivityData activity;

  @override
  Widget build(BuildContext context) {
    final bool hasBike = activity.travelTimeBikeSeconds != null;
    final bool hasCar = activity.travelTimeCarSeconds != null;
    if (!hasBike && !hasCar) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: <Widget>[
        if (hasBike)
          _TravelModeChip(
            icon: Icons.two_wheeler,
            seconds: activity.travelTimeBikeSeconds!,
            meters: activity.travelDistanceBikeMeters,
          ),
        if (hasCar)
          _TravelModeChip(
            icon: Icons.directions_car,
            seconds: activity.travelTimeCarSeconds!,
            meters: activity.travelDistanceCarMeters,
          ),
      ],
    );
  }
}

class _TravelModeChip extends StatelessWidget {
  const _TravelModeChip({
    required this.icon,
    required this.seconds,
    required this.meters,
  });

  final IconData icon;
  final int seconds;
  final int? meters;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int minutes = (seconds / 60).round();
    final String label = meters != null
        ? '$minutes ${context.l10n.ui('min')} · ${_formatDistance(meters!)}'
        : '$minutes ${context.l10n.ui('min')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Same < 1km/>= 1km threshold and no-space-before-unit format already used
/// for nearby-place distances in trip_map_page.dart, adapted for a meters
/// (int) input instead of a distanceKm (double) one.
String _formatDistance(int meters) {
  if (meters < 1000) return '${meters}m';
  return '${(meters / 1000).toStringAsFixed(1)}km';
}

List<String> _activityFacts(
  BuildContext context,
  TripPlannerActivityData activity,
) {
  final List<String> facts = <String>[];
  final int? duration = activity.estimatedDurationMinutes;
  if (duration != null && duration > 0) {
    final int hours = duration ~/ 60;
    final int minutes = duration % 60;
    final String value = hours == 0
        ? '$minutes ${context.l10n.ui('min')}'
        : minutes == 0
        ? '$hours${context.l10n.ui('h')}'
        : '$hours${context.l10n.ui('h')} $minutes${context.l10n.ui('m')}';
    facts.add('${context.l10n.ui('Duration')}: $value');
  }

  final num? minimum = activity.minimumPrice;
  final num? maximum = activity.maximumPrice;
  if (minimum != null || maximum != null) {
    final String value;
    if (minimum != null && maximum != null) {
      value = '${_formatVnd(minimum)} - ${_formatVnd(maximum)}';
    } else if (minimum != null) {
      value = '${context.l10n.ui('From')} ${_formatVnd(minimum)}';
    } else {
      value = '${context.l10n.ui('Up to')} ${_formatVnd(maximum!)}';
    }
    facts.add('${context.l10n.ui('Price')}: $value');
  }

  final String? opens = activity.timespan?.trim();
  final String? closes = activity.timeclose?.trim();
  if (opens?.isNotEmpty == true && closes?.isNotEmpty == true) {
    facts.add('${context.l10n.ui('Open')} $opens - $closes');
  }
  return facts;
}

String _formatVnd(num value) {
  final String digits = value.round().toString();
  final StringBuffer result = StringBuffer();
  for (int index = 0; index < digits.length; index++) {
    result.write(digits[index]);
    final int remaining = digits.length - index - 1;
    if (remaining > 0 && remaining % 3 == 0) result.write(',');
  }
  return '$result VND';
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEF1F5),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 42, color: Color(0xFFAEB7C4)),
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF10C4E8), Color(0xFF4E98F7)],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x2913B7E8),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.send_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2EBEFB), width: 2),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2EBEFB),
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2EBEFB), width: 2),
      ),
      child: Text(
        time,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2EBEFB),
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _BackButtonCircle extends StatelessWidget {
  const _BackButtonCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
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
