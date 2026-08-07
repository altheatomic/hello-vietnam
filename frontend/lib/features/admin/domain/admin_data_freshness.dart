enum AdminFreshnessDecision { approved, rejected }

extension AdminFreshnessDecisionApi on AdminFreshnessDecision {
  String get apiValue => name;
}

class AdminFreshnessOverview {
  const AdminFreshnessOverview({
    this.due = 0,
    this.pending = 0,
    this.autoExpiredToday = 0,
    this.failedRuns = 0,
  });

  final int due;
  final int pending;
  final int autoExpiredToday;
  final int failedRuns;

  factory AdminFreshnessOverview.fromJson(Map<String, dynamic> json) {
    int integer(Object? value) =>
        value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return AdminFreshnessOverview(
      due: integer(json['due']),
      pending: integer(json['pending']),
      autoExpiredToday: integer(
        json['autoExpiredToday'] ?? json['auto_expired_today'],
      ),
      failedRuns: integer(json['failedRuns'] ?? json['failed_runs']),
    );
  }
}

class AdminFreshnessProposal {
  const AdminFreshnessProposal({
    required this.id,
    this.freshnessId,
    this.contentType,
    this.contentId,
    this.sourceType,
    this.sourceUrl,
    this.freshnessStatus,
    this.changeType,
    this.beforeData = const <String, dynamic>{},
    this.proposedData = const <String, dynamic>{},
    this.changedFields = const <String>[],
    this.reason = '',
    this.confidence,
    this.decision = 'pending',
    this.detectedAt,
  });

  final String id;
  final String? freshnessId;
  final String? contentType;
  final String? contentId;
  final String? sourceType;
  final String? sourceUrl;
  final String? freshnessStatus;
  final String? changeType;
  final Map<String, dynamic> beforeData;
  final Map<String, dynamic> proposedData;
  final List<String> changedFields;
  final String reason;
  final double? confidence;
  final String decision;
  final DateTime? detectedAt;

  factory AdminFreshnessProposal.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> nested = _map(json['content_freshness']);
    return AdminFreshnessProposal(
      id: _string(json['id']) ?? '',
      freshnessId: _string(json['freshness_id']),
      contentType: _string(json['content_type'] ?? nested['content_type']),
      contentId: _string(json['content_id'] ?? nested['content_id']),
      sourceType: _string(json['source_type'] ?? nested['source_type']),
      sourceUrl: _string(json['source_url'] ?? nested['source_url']),
      freshnessStatus: _string(
        json['freshness_status'] ?? nested['freshness_status'],
      ),
      changeType: _string(json['change_type']),
      beforeData: _map(json['before_data']),
      proposedData: _map(json['proposed_data']),
      changedFields: _list(json['changed_fields']),
      reason: _string(json['reason']) ?? '',
      confidence: _double(json['confidence']),
      decision: _string(json['decision']) ?? 'pending',
      detectedAt: _date(json['detected_at']),
    );
  }
}

class AdminFreshnessReport {
  const AdminFreshnessReport({
    required this.id,
    this.reporterUserId,
    this.reporterName,
    this.reporterEmail,
    this.contentType,
    this.contentId,
    this.reason = '',
    this.note,
    this.status = 'pending',
    this.createdAt,
  });

  final String id;
  final String? reporterUserId;
  final String? reporterName;
  final String? reporterEmail;
  final String? contentType;
  final String? contentId;
  final String reason;
  final String? note;
  final String status;
  final DateTime? createdAt;

  AdminFreshnessReport copyWith({String? status}) => AdminFreshnessReport(
    id: id,
    reporterUserId: reporterUserId,
    reporterName: reporterName,
    reporterEmail: reporterEmail,
    contentType: contentType,
    contentId: contentId,
    reason: reason,
    note: note,
    status: status ?? this.status,
    createdAt: createdAt,
  );

  factory AdminFreshnessReport.fromJson(Map<String, dynamic> json) =>
      AdminFreshnessReport(
        id: _string(json['id']) ?? '',
        reporterUserId: _string(json['reporter_user_id']),
        reporterName: _string(json['reporter_name']),
        reporterEmail: _string(json['reporter_email']),
        contentType: _string(json['content_type']),
        contentId: _string(json['content_id']),
        reason: _string(json['reason']) ?? '',
        note: _string(json['note']),
        status: _string(json['status']) ?? 'pending',
        createdAt: _date(json['created_at']),
      );
}

class AdminFreshnessStale {
  const AdminFreshnessStale({
    required this.id,
    this.contentType,
    this.contentId,
    this.sourceType,
    this.sourceUrl,
    this.freshnessStatus,
    this.lastVerifiedAt,
    this.nextCheckAt,
    this.lastError,
    this.consecutiveMissingCount = 0,
  });

  final String id;
  final String? contentType;
  final String? contentId;
  final String? sourceType;
  final String? sourceUrl;
  final String? freshnessStatus;
  final DateTime? lastVerifiedAt;
  final DateTime? nextCheckAt;
  final String? lastError;
  final int consecutiveMissingCount;

  factory AdminFreshnessStale.fromJson(Map<String, dynamic> json) {
    final Object? missing = json['consecutive_missing_count'];
    return AdminFreshnessStale(
      id: _string(json['id']) ?? '',
      contentType: _string(json['content_type']),
      contentId: _string(json['content_id']),
      sourceType: _string(json['source_type']),
      sourceUrl: _string(json['source_url']),
      freshnessStatus: _string(json['freshness_status']),
      lastVerifiedAt: _date(json['last_verified_at']),
      nextCheckAt: _date(json['next_check_at']),
      lastError: _string(json['last_error']),
      consecutiveMissingCount: missing is num
          ? missing.toInt()
          : int.tryParse('$missing') ?? 0,
    );
  }
}

class AdminFreshnessRun {
  const AdminFreshnessRun({
    required this.id,
    this.triggerType,
    this.status,
    this.startedAt,
    this.finishedAt,
    this.selectedCount = 0,
    this.checkedCount = 0,
    this.unchangedCount = 0,
    this.proposalCount = 0,
    this.autoAppliedCount = 0,
    this.failedCount = 0,
    this.errorSummary,
  });

  final String id;
  final String? triggerType;
  final String? status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int selectedCount;
  final int checkedCount;
  final int unchangedCount;
  final int proposalCount;
  final int autoAppliedCount;
  final int failedCount;
  final String? errorSummary;

  factory AdminFreshnessRun.fromJson(Map<String, dynamic> json) {
    int integer(String key) => json[key] is num
        ? (json[key] as num).toInt()
        : int.tryParse('${json[key]}') ?? 0;
    return AdminFreshnessRun(
      id: _string(json['id']) ?? '',
      triggerType: _string(json['trigger_type']),
      status: _string(json['status']),
      startedAt: _date(json['started_at']),
      finishedAt: _date(json['finished_at']),
      selectedCount: integer('selected_count'),
      checkedCount: integer('checked_count'),
      unchangedCount: integer('unchanged_count'),
      proposalCount: integer('proposal_count'),
      autoAppliedCount: integer('auto_applied_count'),
      failedCount: integer('failed_count'),
      errorSummary: _string(json['error_summary']),
    );
  }
}

class AdminFreshnessPaged<T> {
  const AdminFreshnessPaged({required this.items, required this.totalCount});

  final List<T> items;
  final int totalCount;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((Object? k, Object? v) => MapEntry('$k', v));
  }
  return <String, dynamic>{};
}

List<String> _list(Object? value) => value is List
    ? value.map((Object? item) => '$item').toList(growable: false)
    : const <String>[];

String? _string(Object? value) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double? _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value');

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse('$value')?.toUtc();
