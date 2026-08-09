import 'package:flutter/material.dart';
import 'package:hellovietnam/core/utils/maps_launcher.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';

typedef AccommodationMapUrlOpener = Future<bool> Function(Uri uri);
typedef AccommodationHotelOpener = Future<bool> Function({
  required double lat,
  required double lng,
});
typedef AccommodationZoneOpener = Future<bool> Function(
  AccommodationZone zone,
);

class AccommodationRecommendationCard extends StatelessWidget {
  const AccommodationRecommendationCard({
    super.key,
    required this.recommendation,
    this.openUrl,
    this.openHotels,
  });

  final AccommodationRecommendation recommendation;
  final AccommodationMapUrlOpener? openUrl;
  final AccommodationHotelOpener? openHotels;

  Future<bool> _openZone(AccommodationZone zone) {
    if (openHotels != null) {
      return openHotels!(lat: zone.latitude, lng: zone.longitude);
    }
    if (openUrl != null) {
      return openUrl!(buildGoogleMapsNearbyHotelsUri(
        lat: zone.latitude,
        lng: zone.longitude,
      ));
    }
    return openGoogleMapsNearbyHotels(
      lat: zone.latitude,
      lng: zone.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isMultiZone = recommendation.strategy == 'multi_zone';
    final double reduction = recommendation.evaluation.reductionRatio * 100;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Accommodation area recommendation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isMultiZone
                  ? 'The itinerary is divided into ${recommendation.zones.length} convenient areas. Estimated travel distance is reduced by ${reduction.toStringAsFixed(0)}%.'
                  : 'One accommodation area is recommended for the whole itinerary.',
            ),
            const SizedBox(height: 12),
            ...recommendation.zones.map(
              (zone) => _AccommodationZoneTile(
                zone: zone,
                openZone: _openZone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccommodationZoneTile extends StatelessWidget {
  const _AccommodationZoneTile({
    required this.zone,
    required this.openZone,
  });

  final AccommodationZone zone;
  final AccommodationZoneOpener openZone;

  @override
  Widget build(BuildContext context) {
    final bool validCoordinates = hasValidMapCoordinates(
      lat: zone.latitude,
      lng: zone.longitude,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            zone.dayFrom == zone.dayTo
                ? 'Days ${zone.dayFrom}'
                : 'Days ${zone.dayFrom}–${zone.dayTo}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Near ${zone.latitude.toStringAsFixed(4)}, ${zone.longitude.toStringAsFixed(4)}',
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: validCoordinates ? () => openZone(zone) : null,
            icon: const Icon(Icons.hotel_outlined),
            label: const Text('Find hotels on Google Maps'),
          ),
        ],
      ),
    );
  }
}
