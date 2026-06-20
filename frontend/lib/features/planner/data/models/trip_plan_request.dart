class TripPlanRequest {
  const TripPlanRequest({
    required this.idProvince,
    required this.nDays,
    this.startDate,
    this.saRuns = 5,
    this.savePlan = true,
  });

  final String idProvince;
  final int nDays;
  final String? startDate; // 'YYYY-MM-DD'
  final int saRuns;
  final bool savePlan;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id_province': idProvince,
        'n_days':      nDays,
        if (startDate != null) 'start_date': startDate,
        'sa_runs':     saRuns,
        'save_plan':   savePlan,
      };
}
