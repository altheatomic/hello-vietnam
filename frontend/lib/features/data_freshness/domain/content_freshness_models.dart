enum FreshnessContentType { place, activity, culture, food, localProduct }

extension FreshnessContentTypeApi on FreshnessContentType {
  String get apiValue => switch (this) {
    FreshnessContentType.place => 'place',
    FreshnessContentType.activity => 'activity',
    FreshnessContentType.culture => 'culture',
    FreshnessContentType.food => 'food',
    FreshnessContentType.localProduct => 'local_product',
  };
}

enum ContentReportReason {
  closed,
  wrongHours,
  wrongLocation,
  eventEnded,
  other,
}

extension ContentReportReasonApi on ContentReportReason {
  String get apiValue => switch (this) {
    ContentReportReason.closed => 'closed',
    ContentReportReason.wrongHours => 'wrong_hours',
    ContentReportReason.wrongLocation => 'wrong_location',
    ContentReportReason.eventEnded => 'event_ended',
    ContentReportReason.other => 'other',
  };
}

enum ContentFreshnessStatus { fresh, due, stale, needsReview, expired, unknown }

class ContentFreshnessInfo {
  const ContentFreshnessInfo({
    required this.status,
    this.lastVerifiedAt,
    this.warning,
  });

  final ContentFreshnessStatus status;
  final DateTime? lastVerifiedAt;
  final String? warning;

  bool get showsWarning =>
      status == ContentFreshnessStatus.stale ||
      status == ContentFreshnessStatus.needsReview ||
      warning != null;

  factory ContentFreshnessInfo.fromJson(Map<String, dynamic> json) {
    final String rawStatus =
        (json['freshnessStatus'] ?? json['freshness_status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final ContentFreshnessStatus status = switch (rawStatus) {
      'fresh' => ContentFreshnessStatus.fresh,
      'due' => ContentFreshnessStatus.due,
      'stale' => ContentFreshnessStatus.stale,
      'needs_review' || 'needsreview' => ContentFreshnessStatus.needsReview,
      'expired' => ContentFreshnessStatus.expired,
      _ => ContentFreshnessStatus.unknown,
    };
    final String? rawDate = (json['lastVerifiedAt'] ?? json['last_verified_at'])
        ?.toString()
        .trim();
    return ContentFreshnessInfo(
      status: status,
      lastVerifiedAt: rawDate == null || rawDate.isEmpty
          ? null
          : DateTime.tryParse(rawDate)?.toUtc(),
      warning: (json['freshnessWarning'] ?? json['freshness_warning'])
          ?.toString()
          .trim(),
    );
  }
}

class ContentFreshnessException implements Exception {
  const ContentFreshnessException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
