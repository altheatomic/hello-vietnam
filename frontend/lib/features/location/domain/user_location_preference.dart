enum LocationSource {
  gps,
  manual,
  mapPin;

  String get dbValue {
    switch (this) {
      case LocationSource.gps:
        return 'gps';
      case LocationSource.manual:
        return 'manual';
      case LocationSource.mapPin:
        return 'map_pin';
    }
  }
}

class UserLocationPreference {
  const UserLocationPreference({
    required this.locationSource,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.approxAddress,
    this.provinceCity,
  });

  final double? latitude;
  final double? longitude;
  final String? approxAddress;
  final String? provinceCity;
  final LocationSource locationSource;
  final DateTime updatedAt;

  Map<String, dynamic> toRequestJson() {
    return <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'approxAddress': approxAddress,
      'provinceCity': provinceCity,
      'locationSource': locationSource.dbValue,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

