class TripWizardData {
  const TripWizardData({
    this.idProvince,
    this.provinceName,
    this.startDate,
    this.nDays,
  });

  final String? idProvince;
  final String? provinceName;
  final String? startDate; // 'YYYY-MM-DD'
  final int? nDays;

  TripWizardData copyWith({
    String? idProvince,
    String? provinceName,
    String? startDate,
    int? nDays,
  }) =>
      TripWizardData(
        idProvince: idProvince ?? this.idProvince,
        provinceName: provinceName ?? this.provinceName,
        startDate: startDate ?? this.startDate,
        nDays: nDays ?? this.nDays,
      );
}
