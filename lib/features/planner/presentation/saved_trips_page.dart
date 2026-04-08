import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/app/theme.dart';

class SavedTripsPage extends StatefulWidget {
  const SavedTripsPage({super.key});

  @override
  State<SavedTripsPage> createState() => _SavedTripsPageState();
}

class _SavedTripsPageState extends State<SavedTripsPage> {
  final List<_SavedTrip> _trips = <_SavedTrip>[
    _SavedTrip(
      id: 'trip-hoian',
      monthLabel: 'April 2026',
      title: 'Hoi An Heritage Escape',
      destination: 'Hoi An',
      tripType: 'Leisure',
      dateLabel: '16 Apr • 3 days 2 nights',
      budgetLabel: '900,000 VND / day',
      accentColors: const <Color>[
        Color(0xFFFFD6B5),
        Color(0xFFFFF1C8),
        Color(0xFFCFF5F6),
      ],
      stops: <_SavedStop>[
        _SavedStop(
          id: 'hoian-1',
          timeLabel: '08:00',
          title: 'Japanese Covered Bridge',
          note: 'Architecture and old town walk',
          isCompleted: true,
        ),
        _SavedStop(
          id: 'hoian-2',
          timeLabel: '12:30',
          title: 'Riverside Lunch Market',
          note: 'Try cao lau and local desserts',
          isCompleted: false,
        ),
        _SavedStop(
          id: 'hoian-3',
          timeLabel: '18:30',
          title: 'Lantern Boat Ride',
          note: 'Evening activity on Thu Bon River',
          isCompleted: false,
        ),
      ],
    ),
    _SavedTrip(
      id: 'trip-dalat',
      monthLabel: 'April 2026',
      title: 'Da Lat Cool Weather Weekend',
      destination: 'Da Lat',
      tripType: 'Leisure',
      dateLabel: '22 Apr • 2 days 1 night',
      budgetLabel: 'Standard range',
      accentColors: const <Color>[
        Color(0xFFE5F7F4),
        Color(0xFFDDF4FF),
        Color(0xFFF1ECFF),
      ],
      stops: <_SavedStop>[
        _SavedStop(
          id: 'dalat-1',
          timeLabel: '07:30',
          title: 'Pine Hill Sunrise Spot',
          note: 'Coffee stop with valley view',
          isCompleted: false,
        ),
        _SavedStop(
          id: 'dalat-2',
          timeLabel: '10:00',
          title: 'Domaine de Marie Church',
          note: 'Photo stop and short sightseeing',
          isCompleted: false,
        ),
        _SavedStop(
          id: 'dalat-3',
          timeLabel: '15:00',
          title: 'Night Market Walk',
          note: 'Street food and souvenirs',
          isCompleted: false,
        ),
      ],
    ),
    _SavedTrip(
      id: 'trip-hanoi',
      monthLabel: 'March 2026',
      title: 'Hanoi Culture Sprint',
      destination: 'Hanoi',
      tripType: 'Business',
      dateLabel: '28 Mar • 1 day',
      budgetLabel: '1,200,000 VND / day',
      accentColors: const <Color>[
        Color(0xFFDDEBFF),
        Color(0xFFE3FBFF),
        Color(0xFFF4F2FF),
      ],
      stops: <_SavedStop>[
        _SavedStop(
          id: 'hanoi-1',
          timeLabel: '09:00',
          title: 'Temple of Literature',
          note: 'Morning cultural visit',
          isCompleted: true,
        ),
        _SavedStop(
          id: 'hanoi-2',
          timeLabel: '13:00',
          title: 'Old Quarter Food Tour',
          note: 'Lunch tasting route',
          isCompleted: true,
        ),
        _SavedStop(
          id: 'hanoi-3',
          timeLabel: '17:30',
          title: 'Hoan Kiem Lake',
          note: 'Late afternoon walk',
          isCompleted: true,
        ),
      ],
    ),
  ];

  _TripFilter _selectedFilter = _TripFilter.all;

  List<_SavedTrip> get _visibleTrips {
    return _trips.where((_SavedTrip trip) {
      switch (_selectedFilter) {
        case _TripFilter.all:
          return true;
        case _TripFilter.upcoming:
          return trip.status == _TripStatus.upcoming;
        case _TripFilter.inProgress:
          return trip.status == _TripStatus.inProgress;
        case _TripFilter.completed:
          return trip.status == _TripStatus.completed;
      }
    }).toList();
  }

  int get _remainingStops {
    return _trips.fold<int>(
      0,
      (int total, _SavedTrip trip) => total + trip.remainingStops,
    );
  }

  void _toggleStop(String tripId, String stopId) {
    setState(() {
      final int tripIndex = _trips.indexWhere(
        (_SavedTrip trip) => trip.id == tripId,
      );
      if (tripIndex == -1) return;
      _trips[tripIndex] = _trips[tripIndex].toggleStop(stopId);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<_SavedTrip>> groupedTrips =
        <String, List<_SavedTrip>>{};
    for (final _SavedTrip trip in _visibleTrips) {
      groupedTrips.putIfAbsent(trip.monthLabel, () => <_SavedTrip>[]).add(trip);
    }

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
              top: 280,
              left: -70,
              child: _DecorativeOrb(size: 180, color: Color(0x5532D2FF)),
            ),
            const Positioned(
              bottom: 100,
              right: -40,
              child: _DecorativeOrb(size: 190, color: Color(0x5556E2D5)),
            ),
            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              _CircleIconButton(
                                icon: Icons.arrow_back_rounded,
                                onTap: () => context.pop(),
                              ),
                              const Spacer(),
                              _CircleIconButton(
                                icon: Icons.add_rounded,
                                onTap: () => context.go(AppRoutes.tripPlanner),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Saved Trips',
                            style: TextStyle(
                              fontSize: 31,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pick up where you left off and tick places as you complete them.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF687384),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _SummaryCard(
                            totalTrips: _trips.length,
                            remainingStops: _remainingStops,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: _TripFilter.values.map((
                                _TripFilter filter,
                              ) {
                                final bool selected = filter == _selectedFilter;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: _FilterChipButton(
                                    label: filter.label,
                                    selected: selected,
                                    onTap: () {
                                      setState(() {
                                        _selectedFilter = filter;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 22),
                        ],
                      ),
                    ),
                  ),
                  if (groupedTrips.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptySavedTripsState(),
                    )
                  else
                    ...groupedTrips.entries.map(
                      (
                        MapEntry<String, List<_SavedTrip>> entry,
                      ) => SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${entry.value.length} trips',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF738092),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...entry.value.map(
                                (_SavedTrip trip) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _SavedTripCard(
                                    trip: trip,
                                    onToggleStop: (String stopId) =>
                                        _toggleStop(trip.id, stopId),
                                    onOpenPlan: () => context.push(
                                      AppRoutes.tripPlannerResult,
                                    ),
                                    onPlanAgain: () =>
                                        context.go(AppRoutes.tripPlanner),
                                    onTripTapped: () => _showMessage(
                                      '${trip.title} updated in Saved Trips',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalTrips, required this.remainingStops});

  final int totalTrips;
  final int remainingStops;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD7F1FF), width: 1.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x180F2C4F),
            blurRadius: 26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF1AC2EB), Color(0xFF4A99F7)],
              ),
            ),
            child: const Icon(
              Icons.bookmark_added_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$totalTrips saved itineraries',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$remainingStops places still waiting to be checked off.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF667488),
                    height: 1.4,
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

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFEEF9FF)
                : Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF22B7F1)
                  : const Color(0xFFD8EAF3),
              width: selected ? 1.8 : 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF1FAFE6)
                  : const Color(0xFF5B687B),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedTripCard extends StatelessWidget {
  const _SavedTripCard({
    required this.trip,
    required this.onToggleStop,
    required this.onOpenPlan,
    required this.onPlanAgain,
    required this.onTripTapped,
  });

  final _SavedTrip trip;
  final ValueChanged<String> onToggleStop;
  final VoidCallback onOpenPlan;
  final VoidCallback onPlanAgain;
  final VoidCallback onTripTapped;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD8EEF7), width: 1.4),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x190F2C4F),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTripTapped,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(colors: trip.accentColors),
                      ),
                      child: const Icon(
                        Icons.luggage_rounded,
                        color: Color(0xFF2579B7),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            trip.title,
                            style: const TextStyle(
                              fontSize: 18.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${trip.destination} • ${trip.tripType}',
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: Color(0xFF5D6A7E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            trip.dateLabel,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF8391A2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(status: trip.status),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _InfoPill(
                        icon: Icons.account_balance_wallet_outlined,
                        label: trip.budgetLabel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoPill(
                        icon: Icons.checklist_rounded,
                        label:
                            '${trip.completedStops}/${trip.stops.length} completed',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: trip.progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE6EDF5),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF23B7F1),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  trip.statusMessage,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF768496),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBFE),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: trip.stops.map((_SavedStop stop) {
                      final bool last = stop == trip.stops.last;
                      return Padding(
                        padding: EdgeInsets.only(bottom: last ? 10 : 14),
                        child: _SavedStopTile(
                          stop: stop,
                          onToggle: () => onToggleStop(stop.id),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _TripActionButton(
                        label: 'Open itinerary',
                        filled: false,
                        onTap: onOpenPlan,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TripActionButton(
                        label: 'Plan again',
                        filled: true,
                        onTap: onPlanAgain,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedStopTile extends StatelessWidget {
  const _SavedStopTile({required this.stop, required this.onToggle});

  final _SavedStop stop;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: stop.isCompleted
                    ? const Color(0xFF22B7F1)
                    : const Color(0xFFFFC759),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 40,
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: const Color(0xFFD7E1EC),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                stop.timeLabel,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8895A6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stop.title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: stop.isCompleted
                      ? const Color(0xFF7D8A9A)
                      : AppColors.textPrimary,
                  decoration: stop.isCompleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stop.note,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF6E7C8F),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stop.isCompleted ? const Color(0xFF23B7F1) : Colors.white,
              border: Border.all(
                color: stop.isCompleted
                    ? const Color(0xFF23B7F1)
                    : const Color(0xFFC8D9E6),
                width: 1.8,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x140F2C4F),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.check_rounded,
              color: stop.isCompleted ? Colors.white : const Color(0xFFA1AEBE),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _TripActionButton extends StatelessWidget {
  const _TripActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: filled ? const Color(0xFF23B7F1) : const Color(0xFFF1F8FD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: filled ? const Color(0xFF23B7F1) : const Color(0xFFD8EAF3),
              width: 1.3,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: filled ? Colors.white : const Color(0xFF4D5D71),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FBFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: const Color(0xFF51A3D8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF54657A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _TripStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color backgroundColor;
    late final Color textColor;

    switch (status) {
      case _TripStatus.upcoming:
        backgroundColor = const Color(0xFFFFF3D9);
        textColor = const Color(0xFFB77A15);
      case _TripStatus.inProgress:
        backgroundColor = const Color(0xFFDFF7FF);
        textColor = const Color(0xFF168EC2);
      case _TripStatus.completed:
        backgroundColor = const Color(0xFFDCF7E7);
        textColor = const Color(0xFF259B58);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD9EEF7)),
          ),
          child: Icon(icon, color: const Color(0xFF38506A), size: 22),
        ),
      ),
    );
  }
}

class _EmptySavedTripsState extends StatelessWidget {
  const _EmptySavedTripsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFD7F0F7)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.luggage_outlined, size: 42, color: Color(0xFF6F8093)),
              SizedBox(height: 12),
              Text(
                'No trips match this filter yet.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try another filter or create a new itinerary from Trip Planner.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF718093),
                  height: 1.45,
                ),
              ),
            ],
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
    return IgnorePointer(
      child: ImageFiltered(
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
      ),
    );
  }
}

enum _TripFilter {
  all('All'),
  upcoming('Upcoming'),
  inProgress('In Progress'),
  completed('Completed');

  const _TripFilter(this.label);

  final String label;
}

enum _TripStatus {
  upcoming('Upcoming'),
  inProgress('In Progress'),
  completed('Completed');

  const _TripStatus(this.label);

  final String label;
}

class _SavedTrip {
  const _SavedTrip({
    required this.id,
    required this.monthLabel,
    required this.title,
    required this.destination,
    required this.tripType,
    required this.dateLabel,
    required this.budgetLabel,
    required this.accentColors,
    required this.stops,
  });

  final String id;
  final String monthLabel;
  final String title;
  final String destination;
  final String tripType;
  final String dateLabel;
  final String budgetLabel;
  final List<Color> accentColors;
  final List<_SavedStop> stops;

  int get completedStops =>
      stops.where((_SavedStop stop) => stop.isCompleted).length;

  int get remainingStops => stops.length - completedStops;

  double get progress => stops.isEmpty ? 0 : completedStops / stops.length;

  _TripStatus get status {
    if (completedStops == 0) return _TripStatus.upcoming;
    if (completedStops == stops.length) return _TripStatus.completed;
    return _TripStatus.inProgress;
  }

  String get statusMessage {
    switch (status) {
      case _TripStatus.upcoming:
        return 'Everything is still planned and ready to go.';
      case _TripStatus.inProgress:
        return '$remainingStops places left to complete on this trip.';
      case _TripStatus.completed:
        return 'All planned places are marked as completed.';
    }
  }

  _SavedTrip toggleStop(String stopId) {
    return _SavedTrip(
      id: id,
      monthLabel: monthLabel,
      title: title,
      destination: destination,
      tripType: tripType,
      dateLabel: dateLabel,
      budgetLabel: budgetLabel,
      accentColors: accentColors,
      stops: stops.map((_SavedStop stop) {
        if (stop.id != stopId) return stop;
        return stop.copyWith(isCompleted: !stop.isCompleted);
      }).toList(),
    );
  }
}

class _SavedStop {
  const _SavedStop({
    required this.id,
    required this.timeLabel,
    required this.title,
    required this.note,
    required this.isCompleted,
  });

  final String id;
  final String timeLabel;
  final String title;
  final String note;
  final bool isCompleted;

  _SavedStop copyWith({
    String? id,
    String? timeLabel,
    String? title,
    String? note,
    bool? isCompleted,
  }) {
    return _SavedStop(
      id: id ?? this.id,
      timeLabel: timeLabel ?? this.timeLabel,
      title: title ?? this.title,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
