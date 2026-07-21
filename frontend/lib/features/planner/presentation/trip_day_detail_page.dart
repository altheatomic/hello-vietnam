import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/utils/maps_launcher.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

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
  const TripDayDetailPage({super.key, required this.dayIndex, this.dayData});

  final int dayIndex;
  final TripPlannerDayData? dayData;

  @override
  Widget build(BuildContext context) {
    final TripPlannerDayData day =
        dayData ?? TripPlannerMockData.dayAt(dayIndex);
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
                    ...day.activities
                        .where((a) => a.tag != 'lunch_break')
                        .toList()
                        .asMap()
                        .entries
                        .map(
                          (MapEntry<int, TripPlannerActivityData> entry) =>
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: _ActivityDetailCard(
                                  activity: entry.value,
                                  onDirections: () => context.push(
                                    AppRoutes.tripPlannerMapPath(
                                      dayIndex,
                                      entry.key,
                                    ),
                                    extra: entry.value,
                                  ),
                                ),
                              ),
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
}

class _ActivityDetailCard extends StatelessWidget {
  const _ActivityDetailCard({
    required this.activity,
    required this.onDirections,
  });

  final TripPlannerActivityData activity;
  final VoidCallback onDirections;

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
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 12),
          _CategoryChip(label: context.l10n.ui(activity.tag)),
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
