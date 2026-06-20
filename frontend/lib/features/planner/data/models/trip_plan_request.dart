class TripPlanRequest {
  const TripPlanRequest({
    required this.idProvince,
    required this.nDays,
    this.startDate,
    this.saRuns = 5,
    this.savePlan = true,
    this.interestOptionIds,
  });

  final String idProvince;
  final int nDays;
  final String? startDate; // 'YYYY-MM-DD'
  final int saRuns;
  final bool savePlan;
  final List<String>? interestOptionIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id_province': idProvince,
        'n_days':      nDays,
        if (startDate != null) 'start_date': startDate,
        'sa_runs':     saRuns,
        'save_plan':   savePlan,
        if (interestOptionIds != null && interestOptionIds!.isNotEmpty)
          'interest_option_ids': interestOptionIds,
      };
}
