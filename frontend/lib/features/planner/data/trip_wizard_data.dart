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
    this.includeLunchBreak = true,
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
  /// Step 5 choice: whether the itinerary should reserve a lunch break.
  /// Defaults to true so requests that never touched this step (or state
  /// restored before this field existed) keep the original behaviour.
  final bool includeLunchBreak;

  factory TripWizardData.fromJson(Map<String, dynamic> json) => TripWizardData(
        idProvince: json['idProvince'] as String?,
        provinceName: json['provinceName'] as String?,
        startDate: json['startDate'] as String?,
        nDays: json['nDays'] as int?,
        tripType: json['tripType'] as String?,
        targetLat: (json['targetLat'] as num?)?.toDouble(),
        targetLng: (json['targetLng'] as num?)?.toDouble(),
        businessAddress: json['businessAddress'] as String?,
        includeLunchBreak: json['includeLunchBreak'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'idProvince': idProvince,
        'provinceName': provinceName,
        'startDate': startDate,
        'nDays': nDays,
        'tripType': tripType,
        'targetLat': targetLat,
        'targetLng': targetLng,
        'businessAddress': businessAddress,
        'includeLunchBreak': includeLunchBreak,
      };

  TripWizardData copyWith({
    String? idProvince,
    String? provinceName,
    String? startDate,
    int? nDays,
    String? tripType,
    double? targetLat,
    double? targetLng,
    String? businessAddress,
    bool? includeLunchBreak,
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
        includeLunchBreak: includeLunchBreak ?? this.includeLunchBreak,
      );
}
