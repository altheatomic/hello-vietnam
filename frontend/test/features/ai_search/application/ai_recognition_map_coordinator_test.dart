import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hellovietnam/features/ai_search/application/ai_recognition_map_coordinator.dart';

void main() {
  late _FakeLocationGateway location;
  late _FakeMapGateway maps;
  late DefaultAiRecognitionMapCoordinator coordinator;

  setUp(() {
    location = _FakeLocationGateway();
    maps = _FakeMapGateway();
    coordinator = DefaultAiRecognitionMapCoordinator(
      location: location,
      maps: maps,
    );
  });

  test(
    'denied permission requests once then prepares no-origin search',
    () async {
      location.permission = LocationPermission.denied;
      location.requestResult = LocationPermission.denied;

      final AiRecognitionMapPreparation result = await coordinator.prepare();

      expect(result, isA<AiRecognitionMapWithoutOrigin>());
      expect(location.requestPermissionCalls, 1);
    },
  );

  test('permanently denied permission requires app settings', () async {
    location.permission = LocationPermission.deniedForever;

    final AiRecognitionMapPreparation result = await coordinator.prepare();

    expect(result, isA<AiRecognitionMapNeedsSettings>());
    expect(
      (result as AiRecognitionMapNeedsSettings).target,
      AiRecognitionMapSettingsTarget.app,
    );
  });

  test('disabled location service requires location settings choice', () async {
    location.permission = LocationPermission.whileInUse;
    location.serviceEnabled = false;

    final AiRecognitionMapPreparation result = await coordinator.prepare();

    expect(result, isA<AiRecognitionMapNeedsSettings>());
    expect(
      (result as AiRecognitionMapNeedsSettings).target,
      AiRecognitionMapSettingsTarget.location,
    );
  });

  test('granted permission returns the current map origin', () async {
    location.permission = LocationPermission.whileInUse;
    location.origin = (latitude: 10.7769, longitude: 106.7009);

    final AiRecognitionMapPreparation result = await coordinator.prepare();

    expect(result, isA<AiRecognitionMapReady>());
    expect((result as AiRecognitionMapReady).origin, location.origin);
  });

  test('GPS failure falls back to no-origin search', () async {
    location.permission = LocationPermission.whileInUse;
    location.currentOriginError = StateError('GPS unavailable');

    final AiRecognitionMapPreparation result = await coordinator.prepare();

    expect(result, isA<AiRecognitionMapWithoutOrigin>());
    expect((result as AiRecognitionMapWithoutOrigin).reason, 'gps_unavailable');
  });

  test('launch uses directions only when an origin is available', () async {
    final AiRecognitionMapOrigin origin = (latitude: 10.7, longitude: 106.7);

    expect(
      await coordinator.launch('Ben Thanh Market', origin: origin),
      isTrue,
    );
    expect(maps.directionsQueries, <String>['Ben Thanh Market']);
    expect(maps.searchQueries, isEmpty);

    expect(await coordinator.launch('Nguyen Hue Street'), isTrue);
    expect(maps.searchQueries, <String>['Nguyen Hue Street']);
  });

  test('openSettings delegates to the selected target', () async {
    expect(
      await coordinator.openSettings(AiRecognitionMapSettingsTarget.app),
      isTrue,
    );
    expect(
      await coordinator.openSettings(AiRecognitionMapSettingsTarget.location),
      isTrue,
    );
    expect(location.openAppSettingsCalls, 1);
    expect(location.openLocationSettingsCalls, 1);
  });
}

class _FakeLocationGateway implements AiRecognitionLocationGateway {
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestResult = LocationPermission.whileInUse;
  bool serviceEnabled = true;
  AiRecognitionMapOrigin origin = (latitude: 21.0278, longitude: 105.8342);
  Object? currentOriginError;
  int requestPermissionCalls = 0;
  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<AiRecognitionMapOrigin> currentOrigin() async {
    final Object? error = currentOriginError;
    if (error != null) throw error;
    return origin;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls += 1;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls += 1;
    return true;
  }
}

class _FakeMapGateway implements AiRecognitionMapGateway {
  final List<String> searchQueries = <String>[];
  final List<String> directionsQueries = <String>[];

  @override
  Future<bool> openSearch(String query) async {
    searchQueries.add(query);
    return true;
  }

  @override
  Future<bool> openDirections(
    String query, {
    required AiRecognitionMapOrigin origin,
  }) async {
    directionsQueries.add(query);
    return true;
  }
}
