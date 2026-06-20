import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';
import 'package:hellovietnam/features/planner/data/trip_store.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';

class TripResultPage extends StatefulWidget {
  const TripResultPage({super.key, this.plan});

  final TripPlanResponse? plan;

  @override
  State<TripResultPage> createState() => _TripResultPageState();
}

class _TripResultPageState extends State<TripResultPage> {
  bool _isSaving = false;

  Future<void> _handleSave() async {
    final idPlan = widget.plan?.idPlan;
    if (idPlan == null) {
      _showSnackBar('No plan ID — please generate again.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await TripRepository().savePlan(idPlan);
      if (!mounted) return;
      _showSnackBar('Trip saved!');
      context.push(AppRoutes.tripPlannerSaved);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Could not save trip. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.plan != null
        ? _convertPlan(widget.plan!)
        : TripPlannerMockData.tripDays;

    final totalActivities =
        days.fold<int>(0, (sum, d) => sum + d.activities.length);

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
                    Text(
                      '${days.length} ${days.length == 1 ? 'day' : 'days'} • $totalActivities activities',
                      style: const TextStyle(
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
                            label: _isSaving ? 'Saving…' : 'Save',
                            onTap: _isSaving ? null : _handleSave,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            label: 'Download',
                            onTap: () =>
                                _showSnackBar('Download started'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _IconActionButton(
                          icon: Icons.share_outlined,
                          onTap: () => _showSnackBar('Share options'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StartTripButton(
                      onTap: () {
                        TripStore.instance.startTrip(
                          title: 'Your Vietnam Adventure',
                          days: days,
                        );
                        context.go(AppRoutes.home);
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _StatCard(
                            icon: Icons.calendar_today_outlined,
                            value: '${days.length}',
                            label: 'Days',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.location_on_outlined,
                            value: '$totalActivities',
                            label: 'Activities',
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
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
                    ...days.asMap().entries.map(
                      (MapEntry<int, TripPlannerDayData> entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _DayCard(
                          data: entry.value,
                          onTap: () => context.push(
                            AppRoutes.tripPlannerDayDetailPath(entry.key),
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

// ── Conversion helpers ────────────────────────────────────────────────────────

List<TripPlannerDayData> _convertPlan(TripPlanResponse plan) {
  const gradients = <List<Color>>[
    <Color>[Color(0xFFE9F0FD), Color(0xFFE7FAFD), Color(0xFFD6F7F6)],
    <Color>[Color(0xFFF4EAFB), Color(0xFFEBF7FB), Color(0xFFD6F0F7)],
    <Color>[Color(0xFFFDEFE9), Color(0xFFFAF7E7), Color(0xFFF7F6D6)],
  ];

  return plan.days.asMap().entries.map((entry) {
    final int i = entry.key;
    final TripPlanDay day = entry.value;

    final activities = day.places.map((TripPlanPlace p) {
      return TripPlannerActivityData(
        title: p.name.isEmpty ? 'Place ${p.order}' : p.name,
        time: _slotToTime(p.slot),
        slot: _capitalizeSlot(p.slot),
        tag: 'culture',
        description: '',
        distanceLabel: p.estimatedTravelMinutes != null
            ? '~${p.estimatedTravelMinutes} min travel'
            : '',
        tips: const <String>[],
        nearbyPlaces: const <TripPlannerNearbyPlace>[],
      );
    }).toList();

    final count = activities.length;
    final shown = count > 3 ? 3 : count;

    return TripPlannerDayData(
      dayLabel: 'Day ${day.day}',
      date: _formatIsoDate(day.date),
      activityCountLabel: '$count ${count == 1 ? 'activity' : 'activities'} planned',
      moreActivitiesLabel: count > shown ? '+ ${count - shown} more' : '',
      gradientColors: gradients[i % gradients.length],
      activities: activities,
    );
  }).toList();
}

String _slotToTime(String? slot) {
  switch (slot?.toLowerCase()) {
    case 'morning':
      return '08:00';
    case 'afternoon':
      return '13:00';
    case 'evening':
      return '17:00';
    default:
      return '09:00';
  }
}

String _capitalizeSlot(String? slot) {
  if (slot == null || slot.isEmpty) return '';
  return slot[0].toUpperCase() + slot.substring(1);
}

String _formatIsoDate(String iso) {
  // 'YYYY-MM-DD' → 'Dec 5, 2025'
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final month = int.tryParse(parts[1]) ?? 0;
  final day = int.tryParse(parts[2]) ?? 0;
  if (month < 1 || month > 12) return iso;
  return '${months[month - 1]} $day, ${parts[0]}';
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

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

class _StartTripButton extends StatelessWidget {
  const _StartTripButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF10C4E8), Color(0xFF4E98F7)],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x2910C4E8),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Start Trip',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
              border:
                  Border.all(color: const Color(0xFF2C374C), width: 2),
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
          ...data.activities.take(3).map(
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
