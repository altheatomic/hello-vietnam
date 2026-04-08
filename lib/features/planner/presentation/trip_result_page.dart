import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

class TripResultPage extends StatelessWidget {
  const TripResultPage({super.key});

  @override
  Widget build(BuildContext context) {
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
              bottom: 100,
              left: -40,
              child: _DecorativeOrb(size: 180, color: Color(0x5556E2D5)),
            ),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _BackButtonCircle(onTap: () => context.pop()),
                    const SizedBox(height: 18),
                    const Text(
                      'Your Vietnam Adventure',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '3 days • 0 interests • 10,000,000 VND',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF556273),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _ActionButton(
                            label: 'Save',
                            onTap: () {
                              _showToast(context, 'Saved trip');
                              context.push(AppRoutes.tripPlannerSaved);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            label: 'Download',
                            onTap: () =>
                                _showToast(context, 'Download started'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _IconActionButton(
                          icon: Icons.share_outlined,
                          onTap: () => _showToast(context, 'Share options'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _TagChip(label: 'culture'),
                        _TagChip(label: 'entertainment'),
                        _TagChip(label: 'adventure'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      children: <Widget>[
                        Expanded(
                          child: _StatCard(
                            icon: Icons.calendar_today_outlined,
                            value: '3',
                            label: 'Days',
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.location_on_outlined,
                            value: '12',
                            label: 'Activities',
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.access_time_rounded,
                            value: 'Full',
                            label: 'Schedule',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    const Text(
                      'Your Itinerary',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...TripPlannerMockData.tripDays.asMap().entries.map(
                      (MapEntry<int, TripPlannerDayData> entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _DayCard(
                          data: entry.value,
                          onTap: () => context.push(
                            AppRoutes.tripPlannerDayDetailPath(entry.key),
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

  static void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD5F4FF), width: 1.4),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x260F2C4F),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B495D),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD5F4FF), width: 1.4),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x260F2C4F),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF3B495D), size: 22),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22B7F1), width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x180F2C4F),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF22B7F1),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD5F4FF), width: 1.4),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x260F2C4F),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF22B7F1),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x3322B7F1),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, color: Color(0xFF556273)),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.data, required this.onTap});

  final TripPlannerDayData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: data.gradientColors
              .map(
                (Color color) => Color.alphaBlend(
                  Colors.white.withValues(alpha: 0.3),
                  color,
                ),
              )
              .toList(),
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF78DFFF), width: 2.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x280F2C4F),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF2C374C), width: 2),
            ),
            child: Text(
              data.dayLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.date,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF445163),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.activityCountLabel,
            style: const TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: Color(0xFF5D6A7A),
            ),
          ),
          const SizedBox(height: 14),
          ...data.activities.map(
            (TripPlannerActivityData activity) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _TripActivityTile(activity: activity),
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  data.moreActivitiesLabel,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF5D6A7A),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFFBFE),
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Color(0x2622B7F1),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF43A9DE),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripActivityTile extends StatelessWidget {
  const _TripActivityTile({required this.activity});

  final TripPlannerActivityData activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF90E9FF), width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x260F2C4F),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF22B7F1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${activity.time} • ${activity.slot}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5D6A7A),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        color: Colors.white.withValues(alpha: 0.74),
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
            width: 48,
            height: 48,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 24,
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
