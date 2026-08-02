import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';
import 'package:hellovietnam/features/planner/data/trip_store.dart';
import 'package:hellovietnam/features/planner/data/trip_wizard_data.dart';
import 'package:hellovietnam/features/planner/presentation/trip_planner_mock_data.dart';
import 'package:hellovietnam/features/planner/presentation/widgets/trip_share_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripResultPage extends StatefulWidget {
  const TripResultPage({super.key, required this.plan, this.wizard});

  final TripPlanResponse plan;
  final TripWizardData? wizard;

  @override
  State<TripResultPage> createState() => _TripResultPageState();
}

class _TripResultPageState extends State<TripResultPage> {
  bool _isSaving = false;
  bool _isSharing = false;

  Future<void> _handleSave() async {
    final idPlan = widget.plan.idPlan;
    if (idPlan == null) {
      _showSnackBar(context.l10n.ui('No plan ID — please generate again.'));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await TripRepository().savePlan(idPlan);
      if (!mounted) return;
      _showSnackBar(context.l10n.ui('Trip saved!'));
      context.push(AppRoutes.tripPlannerSaved);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(context.l10n.ui('Could not save trip. Please try again.'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleShare() async {
    final plan = widget.plan;
    if (plan.idPlan == null) {
      _showSnackBar(context.l10n.ui('Save the trip first before sharing.'));
      return;
    }
    await showTripShareSheet(
      context,
      idPlan: plan.idPlan!,
      onShareToForum: _shareToForum,
    );
  }

  Future<void> _shareToForum() async {
    final plan = widget.plan;
    if (plan.idPlan == null) return;

    setState(() => _isSharing = true);
    try {
      final sharedItem = <String, dynamic>{
        'type': 'trip_plan',
        'plan_id': plan.idPlan,
        'n_days': plan.days.length,
        'province_name': widget.wizard?.provinceName ?? 'Vietnam',
        'place_count': plan.days.fold<int>(
          0,
          (sum, d) =>
              sum + d.places.where((p) => p.type != 'lunch_break').length,
        ),
        'days': plan.days
            .map(
              (d) => <String, dynamic>{
                'day': d.day,
                'places': d.places
                    .where((p) => p.type != 'lunch_break')
                    .map((p) => p.name)
                    .toList(),
              },
            )
            .toList(),
      };

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar(context.l10n.ui('Please sign in to share.'));
        return;
      }

      await Supabase.instance.client
          .from('forum_post')
          .insert(<String, dynamic>{
            'id_author_user': userId,
            'content':
                'I created a ${plan.days.length}-day trip plan! '
                'Check it out and save it to your trips.',
            'status': 'active',
            'shared_item': sharedItem,
          });
      await ForumStore.instance.refresh(notifyLoading: false);

      if (!mounted) return;
      _showSnackBar(context.l10n.ui('Shared to Forum!'));
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(context.l10n.ui('Could not share. Please try again.'));
    } finally {
      if (mounted) setState(() => _isSharing = false);
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
    final days = _convertPlan(widget.plan);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<Color> pageColors = isDark
        ? const <Color>[Color(0xFF020B10), Color(0xFF0B1A22), Color(0xFF0B2426)]
        : const <Color>[
            Color(0xFFF1F6FE),
            Color(0xFFDFF5FF),
            Color(0xFFCCF6F1),
          ];

    final totalActivities = days.fold<int>(
      0,
      (sum, d) => sum + d.activities.length,
    );
    final String dateRange = _tripDateRange(widget.plan.days);

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
                color: isDark
                    ? const Color(0x332BC3FF)
                    : const Color(0x662BC3FF),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -40,
              child: _DecorativeOrb(
                size: 180,
                color: isDark
                    ? const Color(0x2256E2D5)
                    : const Color(0x5556E2D5),
              ),
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
                    Text(
                      context.l10n.ui('Your Vietnam Adventure'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (dateRange.isNotEmpty) ...<Widget>[
                      Text(
                        dateRange,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      '${days.length} ${context.l10n.ui(days.length == 1 ? 'day' : 'days')} • $totalActivities ${context.l10n.ui('Activities').toLowerCase()}',
                      style: TextStyle(
                        fontSize: 14.5,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _ActionButton(
                            label: context.l10n.ui(
                              _isSaving ? 'Saving…' : 'Save',
                            ),
                            onTap: _isSaving ? null : _handleSave,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _IconActionButton(
                          icon: _isSharing
                              ? Icons.hourglass_top_rounded
                              : Icons.share_outlined,
                          onTap: _isSharing ? () {} : _handleShare,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StartTripButton(
                      onTap: () {
                        TripStore.instance.startTrip(
                          title: 'Your Vietnam Adventure',
                          days: days,
                          idPlan: widget.plan.idPlan,
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
                            label: context.l10n.ui('Days'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.location_on_outlined,
                            value: '$totalActivities',
                            label: context.l10n.ui('Activities'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.access_time_rounded,
                            value: context.l10n.ui('Full'),
                            label: context.l10n.ui('Schedule'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    Text(
                      context.l10n.ui('Your Itinerary'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
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
      if (p.isLunchBreak) {
        return TripPlannerActivityData(
          title: 'Lunch Break',
          time: p.startTime ?? '12:00',
          slot: 'Afternoon',
          tag: 'lunch_break',
          description: 'Time to rest and eat.',
          distanceLabel: p.endTime != null ? 'Until ${p.endTime}' : '',
          tips: const <String>[],
          nearbyPlaces: const <TripPlannerNearbyPlace>[],
        );
      }
      final String? imageUrl = p.representativeImageUrl;
      debugPrint(
        '[TripResultPage._convertPlan] place=${p.name} imageUrl=$imageUrl',
      );
      return TripPlannerActivityData(
        title: p.name.isEmpty ? 'Place ${p.order}' : p.name,
        time: p.startTime ?? _slotToTime(p.slot),
        slot: _capitalizeSlot(p.slot),
        tag: 'culture',
        description: '',
        distanceLabel: p.estimatedTravelMinutes != null
            ? '~${p.estimatedTravelMinutes} min travel'
            : '',
        tips: const <String>[],
        nearbyPlaces: const <TripPlannerNearbyPlace>[],
        lat: p.latitude ?? 0.0,
        lng: p.longitude ?? 0.0,
        imageUrl: imageUrl,
      );
    }).toList();

    final count = activities.length;
    final shown = count > 3 ? 3 : count;

    return TripPlannerDayData(
      dayLabel: 'Day ${day.day}',
      date: _formatIsoDate(day.date),
      activityCountLabel:
          '$count ${count == 1 ? 'activity' : 'activities'} planned',
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
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = int.tryParse(parts[1]) ?? 0;
  final day = int.tryParse(parts[2]) ?? 0;
  if (month < 1 || month > 12) return iso;
  return '${months[month - 1]} $day, ${parts[0]}';
}

String _tripDateRange(List<TripPlanDay> days) {
  if (days.isEmpty) return '';
  final String startDate = days.first.date;
  final String endDate = days.last.date;
  if (startDate.isEmpty && endDate.isEmpty) return '';
  if (endDate.isEmpty || endDate == startDate) return _formatIsoDate(startDate);
  if (startDate.isEmpty) return _formatIsoDate(endDate);
  return '${_formatIsoDate(startDate)} - ${_formatIsoDate(endDate)}';
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? theme.colorScheme.outline
                  : const Color(0xFFD5F4FF),
              width: isDark ? 1.0 : 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.16)
                    : const Color(0x260F2C4F),
                blurRadius: isDark ? 14 : 24,
                offset: Offset(0, isDark ? 6 : 12),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? theme.colorScheme.outline
                  : const Color(0xFFD5F4FF),
              width: isDark ? 1.0 : 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.16)
                    : const Color(0x260F2C4F),
                blurRadius: isDark ? 14 : 24,
                offset: Offset(0, isDark ? 6 : 12),
              ),
            ],
          ),
          child: Icon(icon, color: theme.colorScheme.onSurface, size: 22),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.ui('Start Trip'),
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? theme.colorScheme.outline : const Color(0xFFD5F4FF),
          width: isDark ? 1.0 : 1.4,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.16)
                : const Color(0x260F2C4F),
            blurRadius: isDark ? 14 : 24,
            offset: Offset(0, isDark ? 6 : 12),
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
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<Color> cardColors = isDark
        ? const <Color>[Color(0xFF0B1A22), Color(0xFF122832), Color(0xFF0B2426)]
        : data.gradientColors
              .map(
                (Color color) => Color.alphaBlend(
                  Colors.white.withValues(alpha: 0.3),
                  color,
                ),
              )
              .toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardColors,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? theme.colorScheme.outline : const Color(0xFF78DFFF),
          width: isDark ? 1.2 : 2.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : const Color(0x280F2C4F),
            blurRadius: isDark ? 18 : 28,
            offset: Offset(0, isDark ? 8 : 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? theme.colorScheme.outline
                    : const Color(0xFF2C374C),
                width: isDark ? 1 : 2,
              ),
            ),
            child: Text(
              context.l10n.ui(data.dayLabel),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.date,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.ui(data.activityCountLabel),
            style: TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          ...data.activities
              .where((a) => a.tag != 'lunch_break')
              .take(3)
              .map(
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
                  style: TextStyle(
                    fontSize: 14.5,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
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
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      boxShadow: const <BoxShadow>[
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
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? theme.colorScheme.outline : const Color(0xFF90E9FF),
          width: isDark ? 1 : 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.16)
                : const Color(0x260F2C4F),
            blurRadius: isDark ? 12 : 20,
            offset: Offset(0, isDark ? 6 : 12),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 42,
              height: 42,
              child: activity.imageUrl != null
                  ? Builder(
                      builder: (BuildContext context) {
                        debugPrint(
                          '[TripResultPage.Image.network] imageUrl='
                          '${activity.imageUrl}',
                        );
                        return Image.network(
                          activity.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) {
                            debugPrint(
                              '[TripResultPage.Image.network] load failed '
                              'imageUrl=${activity.imageUrl} error=$error',
                            );
                            return _ActivityPlaceholderIcon();
                          },
                        );
                      },
                    )
                  : _ActivityPlaceholderIcon(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.ui(activity.title),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${activity.time} • ${activity.slot}',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
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

class _ActivityPlaceholderIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF22B7F1),
      child: const Center(
        child: Icon(Icons.location_on_outlined, color: Colors.white, size: 22),
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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.74),
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
            width: 48,
            height: 48,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 24,
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
