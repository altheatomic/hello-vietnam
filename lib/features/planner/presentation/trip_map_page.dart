import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

class TripMapPage extends StatelessWidget {
  const TripMapPage({
    super.key,
    required this.dayIndex,
    required this.activityIndex,
  });

  final int dayIndex;
  final int activityIndex;

  @override
  Widget build(BuildContext context) {
    final TripPlannerActivityData activity = TripPlannerMockData.activityAt(
      dayIndex,
      activityIndex,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF1F6FE),
              Color(0xFFDFF5FF),
              Color(0xFFCCF6F1),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            const Positioned(
              top: -90,
              right: -60,
              child: _DecorativeOrb(size: 220, color: Color(0x662BC3FF)),
            ),
            const Positioned(
              bottom: 120,
              left: -40,
              child: _DecorativeOrb(size: 180, color: Color(0x5556E2D5)),
            ),
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
                              color: Colors.white.withValues(alpha: 0.96),
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
                                  activity.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  activity.distanceLabel,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF6A7585),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        const Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(18, 26, 18, 300),
                            child: _MapIllustration(),
                          ),
                        ),
                        Positioned(
                          left: 156,
                          top: 250,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFF2F8FF8),
                                  Color(0xFF3D6EF4),
                                ],
                              ),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x2D2F8FF8),
                                  blurRadius: 18,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Text(
                              activity.nearbyPlaces.first.eta,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 22,
                          bottom: 260,
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFF2D9BF8),
                                  Color(0xFF3269F4),
                                ],
                              ),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x332D9BF8),
                                  blurRadius: 18,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.send_outlined,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _ResultSheet(places: activity.nearbyPlaces),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({required this.places});

  final List<TripPlannerNearbyPlace> places;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 290,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
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
            children: const <Widget>[
              Expanded(
                child: Text(
                  'Result',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                'Sort by: Nearest',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4F5B6D),
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.swap_vert_rounded, size: 18, color: Color(0xFF4F5B6D)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1E7F0)),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.search_rounded, color: Color(0xFF9BA5B4), size: 24),
                SizedBox(width: 10),
                Text(
                  'Find in results',
                  style: TextStyle(fontSize: 16, color: Color(0xFF98A2B1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final TripPlannerNearbyPlace place = places[index];
                return _NearbyPlaceTile(place: place);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyPlaceTile extends StatelessWidget {
  const _NearbyPlaceTile({required this.place});

  final TripPlannerNearbyPlace place;

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
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  place.title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${place.subtitle} • ${place.distance}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF707B8B),
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
              style: const TextStyle(
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
              onTap: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('Routing to ${place.title}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              },
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
                child: const Text(
                  'Route',
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
    if (value.contains('hospital') ||
        value.contains('clinic') ||
        value.contains('medical')) {
      return '🏥';
    }
    if (value.contains('pharmacy')) {
      return '💊';
    }
    if (value.contains('cafe')) {
      return '☕';
    }
    if (value.contains('shopping')) {
      return '🛍️';
    }
    if (value.contains('transport')) {
      return '🚌';
    }
    return '📍';
  }
}

class _MapIllustration extends StatelessWidget {
  const _MapIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
        const Positioned(
          left: 74,
          top: 54,
          child: _RedMapMarker(icon: Icons.account_balance_rounded),
        ),
        const Positioned(
          left: 176,
          top: 138,
          child: _RedMapMarker(icon: Icons.circle, iconSize: 12),
        ),
        const Positioned(
          left: 154,
          top: 214,
          child: Text('🚶', style: TextStyle(fontSize: 20)),
        ),
      ],
    );
  }
}

class _RedMapMarker extends StatelessWidget {
  const _RedMapMarker({required this.icon, this.iconSize = 20});

  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFFFF3341),
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x29FF3341),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF5B8DF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final Path path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height * 0.12,
        size.width * 0.55,
        size.height * 0.24,
      )
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * 0.35,
        size.width * 0.88,
        size.height * 0.18,
      );

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      const double dashWidth = 1.6;
      const double dashSpace = 2.4;
      while (distance < metric.length) {
        final Path extract = metric.extractPath(
          distance,
          math.min(distance + dashWidth, metric.length),
        );
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BackButtonCircle extends StatelessWidget {
  const _BackButtonCircle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.82),
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
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 22,
              color: Color(0xFF3A465D),
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
