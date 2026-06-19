class TripPlanRequest {
  const TripPlanRequest({
    required this.idProvince,
    required this.nDays,
    this.startDate,
    this.topN = 40,
    this.saRuns = 5,
    this.savePlan = true,
  });

  final String idProvince;
  final int nDays;
  final String? startDate; // 'YYYY-MM-DD'
  final int topN;
  final int saRuns;
  final bool savePlan;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'action':     'planTrip',
        'idProvince': idProvince,
        'nDays':      nDays,
        if (startDate != null) 'startDate': startDate,
        'topN':       topN,
        'saRuns':     saRuns,
        'savePlan':   savePlan,
      };
}
