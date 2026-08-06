import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../data/models/trip_plan_response.dart';
import '../data/models/trip_share_link.dart';
import '../data/trip_repository.dart';

class SharedTripPage extends StatefulWidget {
  const SharedTripPage({super.key, required this.token, this.repository});

  final String token;
  final TripRepository? repository;

  @override
  State<SharedTripPage> createState() => _SharedTripPageState();
}

class _SharedTripPageState extends State<SharedTripPage> {
  late final TripRepository _repository;
  late Future<PublicSharedTrip> _trip;
  bool _copying = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? TripRepository();
    _trip = _repository.getPublicSharedPlan(widget.token);
  }

  void _retry() {
    setState(() => _trip = _repository.getPublicSharedPlan(widget.token));
  }

  Future<void> _copy(PublicSharedTrip trip) async {
    if (!trip.allowCopy) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      context.go(
        Uri(
          path: AppRoutes.login,
          queryParameters: <String, String>{
            'returnTo': AppRoutes.sharedTripPath(widget.token),
          },
        ).toString(),
      );
      return;
    }

    setState(() => _copying = true);
    try {
      final String idPlan = await _repository.copySharedPlan(widget.token);
      if (mounted) context.go(AppRoutes.tripPlannerResultPath(idPlan: idPlan));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not copy this trip. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shared itinerary')),
      body: FutureBuilder<PublicSharedTrip>(
        future: _trip,
        builder:
            (BuildContext context, AsyncSnapshot<PublicSharedTrip> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _SharedTripError(onRetry: _retry);
              }
              final PublicSharedTrip trip = snapshot.data!;
              return _SharedTripContent(
                trip: trip,
                copying: _copying,
                onCopy: () => _copy(trip),
              );
            },
      ),
    );
  }
}

class _SharedTripContent extends StatelessWidget {
  const _SharedTripContent({
    required this.trip,
    required this.copying,
    required this.onCopy,
  });

  final PublicSharedTrip trip;
  final bool copying;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        Text(
          trip.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '${trip.plan.days.length} day itinerary · Link expires ${_date(trip.expiresAt)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (trip.allowCopy)
          FilledButton.icon(
            onPressed: copying ? null : onCopy,
            icon: copying
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.content_copy_rounded),
            label: const Text('Copy to my trips'),
          )
        else
          const Card(
            child: ListTile(
              leading: Icon(Icons.visibility_outlined),
              title: Text('View-only itinerary'),
              subtitle: Text('The owner disabled copying for this link.'),
            ),
          ),
        const SizedBox(height: 16),
        ...trip.plan.days.map(
          (TripPlanDay day) => Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              initiallyExpanded: day.day == 1,
              title: Text(
                'Day ${day.day}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: day.date.isEmpty ? null : Text(day.date),
              children: day.places
                  .map((TripPlanPlace place) => _SharedPlaceTile(place: place))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  static String _date(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _SharedPlaceTile extends StatelessWidget {
  const _SharedPlaceTile({required this.place});

  final TripPlanPlace place;

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = place.representativeImageUrl;
    final bool hasCoordinates =
        place.latitude != null && place.longitude != null;
    return ListTile(
      leading: imageUrl == null
          ? const CircleAvatar(child: Icon(Icons.place_outlined))
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.square(
                      dimension: 54,
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
              ),
            ),
      title: Text(place.name.isEmpty ? 'Scheduled stop' : place.name),
      subtitle: Text(_timeLabel(place)),
      trailing: hasCoordinates
          ? IconButton(
              tooltip: 'Open map',
              icon: const Icon(Icons.map_outlined),
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://www.openstreetmap.org/?mlat=${place.latitude}'
                  '&mlon=${place.longitude}#map=16/${place.latitude}/${place.longitude}',
                ),
                mode: LaunchMode.externalApplication,
              ),
            )
          : null,
    );
  }

  String _timeLabel(TripPlanPlace place) {
    if (place.startTime != null && place.endTime != null) {
      return '${place.startTime} – ${place.endTime}';
    }
    return place.slot ?? 'Flexible time';
  }
}

class _SharedTripError extends StatelessWidget {
  const _SharedTripError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.link_off_rounded, size: 54),
            const SizedBox(height: 12),
            const Text(
              'This shared itinerary is unavailable.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'The link may have expired or been revoked by its owner.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
