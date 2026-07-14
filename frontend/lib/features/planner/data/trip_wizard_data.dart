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

  factory TripWizardData.fromJson(Map<String, dynamic> json) => TripWizardData(
        idProvince: json['idProvince'] as String?,
        provinceName: json['provinceName'] as String?,
        startDate: json['startDate'] as String?,
        nDays: json['nDays'] as int?,
        tripType: json['tripType'] as String?,
        targetLat: (json['targetLat'] as num?)?.toDouble(),
        targetLng: (json['targetLng'] as num?)?.toDouble(),
        businessAddress: json['businessAddress'] as String?,
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
