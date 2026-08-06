import 'package:geolocator/geolocator.dart';
import 'package:hellovietnam/core/utils/maps_launcher.dart';
import 'package:hellovietnam/features/location/data/device_location_service.dart';

typedef AiRecognitionMapOrigin = ({double latitude, double longitude});

abstract interface class AiRecognitionLocationGateway {
  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<bool> isServiceEnabled();

  Future<AiRecognitionMapOrigin> currentOrigin();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

abstract interface class AiRecognitionMapGateway {
  Future<bool> openSearch(String query);

  Future<bool> openDirections(
    String query, {
    required AiRecognitionMapOrigin origin,
  });
}

abstract interface class AiRecognitionMapCoordinator {
  Future<AiRecognitionMapPreparation> prepare();

  Future<bool> launch(String query, {AiRecognitionMapOrigin? origin});

  Future<bool> openSettings(AiRecognitionMapSettingsTarget target);
}

sealed class AiRecognitionMapPreparation {
  const AiRecognitionMapPreparation();
}

final class AiRecognitionMapReady extends AiRecognitionMapPreparation {
  const AiRecognitionMapReady(this.origin);

  final AiRecognitionMapOrigin origin;
}

final class AiRecognitionMapWithoutOrigin extends AiRecognitionMapPreparation {
  const AiRecognitionMapWithoutOrigin(this.reason);

  final String reason;
}

final class AiRecognitionMapNeedsSettings extends AiRecognitionMapPreparation {
  const AiRecognitionMapNeedsSettings(this.target);

  final AiRecognitionMapSettingsTarget target;
}

enum AiRecognitionMapSettingsTarget { app, location }

class DefaultAiRecognitionMapCoordinator
    implements AiRecognitionMapCoordinator {
  DefaultAiRecognitionMapCoordinator({
    AiRecognitionLocationGateway? location,
    AiRecognitionMapGateway? maps,
  }) : _location = location ?? _DeviceLocationGateway(),
       _maps = maps ?? const _UrlLauncherMapGateway();

  final AiRecognitionLocationGateway _location;
  final AiRecognitionMapGateway _maps;

  @override
  Future<AiRecognitionMapPreparation> prepare() async {
    LocationPermission permission = await _location.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return const AiRecognitionMapNeedsSettings(
        AiRecognitionMapSettingsTarget.app,
      );
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await _location.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return const AiRecognitionMapNeedsSettings(
        AiRecognitionMapSettingsTarget.app,
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      return const AiRecognitionMapWithoutOrigin('location_permission_denied');
    }

    if (!await _location.isServiceEnabled()) {
      return const AiRecognitionMapNeedsSettings(
        AiRecognitionMapSettingsTarget.location,
      );
    }

    try {
      return AiRecognitionMapReady(await _location.currentOrigin());
    } catch (_) {
      return const AiRecognitionMapWithoutOrigin('gps_unavailable');
    }
  }

  @override
  Future<bool> launch(String query, {AiRecognitionMapOrigin? origin}) async {
    if (query.trim().isEmpty) return false;
    if (origin != null) {
      return _maps.openDirections(query, origin: origin);
    }
    return _maps.openSearch(query);
  }

  @override
  Future<bool> openSettings(AiRecognitionMapSettingsTarget target) {
    return switch (target) {
      AiRecognitionMapSettingsTarget.app => _location.openAppSettings(),
      AiRecognitionMapSettingsTarget.location =>
        _location.openLocationSettings(),
    };
  }
}

class _DeviceLocationGateway implements AiRecognitionLocationGateway {
  _DeviceLocationGateway({DeviceLocationService? service})
    : _service = service ?? DeviceLocationService();

  final DeviceLocationService _service;

  @override
  Future<LocationPermission> checkPermission() => _service.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      _service.requestPermission();

  @override
  Future<bool> isServiceEnabled() => _service.isLocationServiceEnabled();

  @override
  Future<AiRecognitionMapOrigin> currentOrigin() async {
    final ResolvedLocationData location = await _service
        .getCurrentGpsLocation();
    return (latitude: location.latitude, longitude: location.longitude);
  }

  @override
  Future<bool> openAppSettings() => _service.openAppSettings();

  @override
  Future<bool> openLocationSettings() => _service.openLocationSettings();
}

class _UrlLauncherMapGateway implements AiRecognitionMapGateway {
  const _UrlLauncherMapGateway();

  @override
  Future<bool> openSearch(String query) => openGoogleMapsSearchQuery(query);

  @override
  Future<bool> openDirections(
    String query, {
    required AiRecognitionMapOrigin origin,
  }) {
    return openGoogleMapsDirectionsToQuery(
      query: query,
      originLat: origin.latitude,
      originLng: origin.longitude,
    );
  }
}
