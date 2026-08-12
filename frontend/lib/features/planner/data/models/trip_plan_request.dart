class TripPlanRequest {
  const TripPlanRequest({
    this.idProvince,
    required this.nDays,
    this.startDate,
    this.saRuns = 5,
    this.savePlan = true,
    this.interestOptionIds,
    this.targetLat,
    this.targetLng,
    this.includeLunchBreak = true,
  });

  final String? idProvince;
  final int nDays;
  final String? startDate; // 'YYYY-MM-DD'
  final int saRuns;
  final bool savePlan;
  final List<String>? interestOptionIds;
  final double? targetLat;
  final double? targetLng;
  /// Step 5 choice: whether the schedule should reserve a lunch break.
  /// Defaults to true — a request that doesn't set this keeps the original
  /// behaviour (backend also defaults to true independently).
  final bool includeLunchBreak;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (idProvince != null) 'id_province': idProvince,
        'n_days':    nDays,
        if (startDate != null) 'start_date': startDate,
        'sa_runs':   saRuns,
        'save_plan': savePlan,
        if (interestOptionIds != null && interestOptionIds!.isNotEmpty)
          'interest_option_ids': interestOptionIds,
        if (targetLat != null) 'target_lat': targetLat,
        if (targetLng != null) 'target_lng': targetLng,
        'include_lunch_break': includeLunchBreak,
      };
}
