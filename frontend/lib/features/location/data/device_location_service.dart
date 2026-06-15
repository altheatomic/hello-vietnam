import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class ResolvedLocationData {
  const ResolvedLocationData({
    required this.latitude,
    required this.longitude,
    required this.approxAddress,
    required this.provinceCity,
  });

  final double latitude;
  final double longitude;
  final String approxAddress;
  final String provinceCity;
}

class DeviceLocationService {
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  Future<ResolvedLocationData> getCurrentGpsLocation() async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    );

    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: locationSettings,
    );

    return resolveFromCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<ResolvedLocationData> resolveFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    String approxAddress = _latLngFallback(latitude, longitude);
    String provinceCity = 'Unknown area';

    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        approxAddress = _buildApproxAddress(place, latitude, longitude);
        provinceCity =
            _firstNonEmpty(<String?>[
              place.administrativeArea,
              place.subAdministrativeArea,
              place.locality,
            ]) ??
            provinceCity;
      }
    } catch (_) {
      // Keep fallback address/province if reverse geocoding fails.
    }

    return ResolvedLocationData(
      latitude: latitude,
      longitude: longitude,
      approxAddress: approxAddress,
      provinceCity: provinceCity,
    );
  }

  String _buildApproxAddress(
    Placemark place,
    double latitude,
    double longitude,
  ) {
    final String? name = _firstNonEmpty(<String?>[
      place.name,
      place.street,
      place.subLocality,
      place.locality,
    ]);
    final String? locality = _firstNonEmpty(<String?>[
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
    ]);

    if (name != null && locality != null) {
      return '$name, $locality';
    }
    if (name != null) {
      return name;
    }
    if (locality != null) {
      return locality;
    }
    return _latLngFallback(latitude, longitude);
  }

  String? _firstNonEmpty(List<String?> candidates) {
    for (final String? value in candidates) {
      final String trimmed = (value ?? '').trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  String _latLngFallback(double latitude, double longitude) {
    return 'Lat ${latitude.toStringAsFixed(6)}, Lng ${longitude.toStringAsFixed(6)}';
  }
}
