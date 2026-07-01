import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/planner/data/trip_store.dart';

// ── Color constants for each trip status ─────────────────────────────────────

const _kGreen = Color(0xFF22D09E);
const _kAmber = Color(0xFFE8A020);
const _kBlue = AppColors.primary;

// ── Public widget ─────────────────────────────────────────────────────────────

/// Compact Home-page card that reflects the real-time state of an active trip.
///
/// Renders three distinct states:
/// - [TripStatus.upcoming]   — trip is activated but hasn't started yet
/// - [TripStatus.inProgress] — itinerary is underway; shows next stop + route
/// - [TripStatus.completed]  — all activities are past; prompts dismissal
///
/// Navigation ([onViewOrRoute]) and dismissal ([onEnd]) are delegated to the
/// caller so this widget stays free of routing knowledge.
class ActiveTripCard extends StatelessWidget {
  const ActiveTripCard({
    super.key,
    required this.trip,
    required this.onViewOrRoute,
    required this.onEnd,
  });

  /// The active trip from [TripStore].
  final ActiveTrip trip;

  /// Called when the user taps "View Plan" (upcoming) or "Route" (inProgress).
  /// The caller should navigate to [trip.relevantActivity.dayIndex].
  final VoidCallback onViewOrRoute;

  /// Called when the user taps "Cancel" (upcoming), "End Trip" (inProgress),
  /// or "Dismiss" (completed).
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final status = trip.status;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StatusHeader(trip: trip),
          const SizedBox(height: 12),
          switch (status) {
            TripStatus.upcoming => _UpcomingBody(trip: trip),
            TripStatus.inProgress => _InProgressBody(trip: trip),
            TripStatus.completed => _CompletedBody(trip: trip),
          },
          const SizedBox(height: 12),
          _ActionRow(
            status: status,
            onViewOrRoute: onViewOrRoute,
            onEnd: onEnd,
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(TripStatus status) {
  final Color accent = switch (status) {
    TripStatus.upcoming => _kAmber,
    TripStatus.inProgress => _kGreen,
    TripStatus.completed => _kBlue,
  };
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppConstants.cardRadius),
    border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.5),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: accent.withValues(alpha: 0.08),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

// ── Header ────────────────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.trip});

  final ActiveTrip trip;

  @override
  Widget build(BuildContext context) {
    return switch (trip.status) {
      TripStatus.upcoming => _buildUpcomingHeader(),
      TripStatus.inProgress => _buildInProgressHeader(),
      TripStatus.completed => _buildCompletedHeader(),
    };
  }

  Widget _buildUpcomingHeader() => Row(
    children: <Widget>[
      const Icon(Icons.access_time_rounded, size: 14, color: _kAmber),
      const SizedBox(width: 5),
      const Text(
        'Upcoming Trip',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _kAmber,
        ),
      ),
      const Spacer(),
      Text(
        trip.startsSummary,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _kAmber,
        ),
      ),
    ],
  );

  Widget _buildInProgressHeader() {
    final ref = trip.relevantActivity;
    final totalDays = trip.days.length;
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: _kGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Active Trip',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kGreen,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Day ${ref.dayIndex + 1} of $totalDays',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedHeader() => Row(
    children: <Widget>[
      const Icon(Icons.check_circle_rounded, size: 15, color: _kBlue),
      const SizedBox(width: 5),
      const Text(
        'Trip Completed',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _kBlue,
        ),
      ),
      const Spacer(),
      Text(
        '${trip.days.length} days done',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _kBlue,
        ),
      ),
    ],
  );
}

// ── Body variants ─────────────────────────────────────────────────────────────

/// Upcoming: no map, shows first stop name + start time as a preview.
class _UpcomingBody extends StatelessWidget {
  const _UpcomingBody({required this.trip});

  final ActiveTrip trip;

  @override
  Widget build(BuildContext context) {
    final first = trip.relevantActivity.activity;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Calendar icon placeholder (no map needed — trip hasn't started)
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _kAmber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAmber.withValues(alpha: 0.18)),
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            color: _kAmber,
            size: 32,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                trip.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'First stop',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _kAmber,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                first.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${first.time} · ${first.slot}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// In-progress: place image + next stop details.
class _InProgressBody extends StatelessWidget {
  const _InProgressBody({required this.trip});

  final ActiveTrip trip;

  @override
  Widget build(BuildContext context) {
    final ref = trip.relevantActivity;
    final activity = ref.activity;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 115,
            height: 105,
            child: activity.imageUrl != null
                ? Image.network(
                    activity.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        _ImageFallback(),
                  )
                : _ImageFallback(),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                trip.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Next stop',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _kGreen,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                activity.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${activity.time} · ${activity.slot}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Completed: simple summary, no map.
class _CompletedBody extends StatelessWidget {
  const _CompletedBody({required this.trip});

  final ActiveTrip trip;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.celebration_rounded, color: _kBlue, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                trip.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${trip.totalActivities} activities completed · ${trip.days.length} days',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.status,
    required this.onViewOrRoute,
    required this.onEnd,
  });

  final TripStatus status;
  final VoidCallback onViewOrRoute;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      TripStatus.upcoming => Row(
        children: <Widget>[
          const Spacer(),
          _GhostButton(label: 'Cancel', onTap: onEnd),
          const SizedBox(width: 8),
          _PrimaryButton(label: 'View Plan', onTap: onViewOrRoute),
        ],
      ),
      TripStatus.inProgress => Row(
        children: <Widget>[
          const Spacer(),
          _GhostButton(label: 'End Trip', onTap: onEnd),
          const SizedBox(width: 8),
          _PrimaryButton(
            label: 'Details',
            onTap: onViewOrRoute,
            trailingIcon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
      TripStatus.completed => Row(
        children: <Widget>[
          const Spacer(),
          _GhostButton(label: 'Dismiss', onTap: onEnd),
        ],
      ),
    };
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.textSecondary,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF10C4E8), Color(0xFF4E98F7)],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x2510C4E8),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (trailingIcon != null) ...<Widget>[
                const SizedBox(width: 4),
                Icon(trailingIcon, color: Colors.white, size: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Image fallback ────────────────────────────────────────────────────────────

class _ImageFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFF8FF),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFFAEC6D4),
          size: 28,
        ),
      ),
    );
  }
}
