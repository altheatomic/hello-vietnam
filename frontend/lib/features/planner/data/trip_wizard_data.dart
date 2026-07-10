class TripWizardData {
  const TripWizardData({
    this.idProvince,
    this.provinceName,
    this.startDate,
    this.nDays,
    this.tripType,
    this.targetLat,
    this.targetLng,
    this.businessAddress,
  });

  final String? idProvince;
  final String? provinceName;
  final String? startDate; // 'YYYY-MM-DD'
  final int? nDays;
  /// 'leisure' or 'business'
  final String? tripType;
  final double? targetLat;
  final double? targetLng;
  final String? businessAddress;

  TripWizardData copyWith({
    String? idProvince,
    String? provinceName,
    String? startDate,
    int? nDays,
    String? tripType,
    double? targetLat,
    double? targetLng,
    String? businessAddress,
  }) =>
      TripWizardData(
        idProvince:      idProvince      ?? this.idProvince,
        provinceName:    provinceName    ?? this.provinceName,
        startDate:       startDate       ?? this.startDate,
        nDays:           nDays           ?? this.nDays,
        tripType:        tripType        ?? this.tripType,
        targetLat:       targetLat       ?? this.targetLat,
        targetLng:       targetLng       ?? this.targetLng,
        businessAddress: businessAddress ?? this.businessAddress,
      );
}
