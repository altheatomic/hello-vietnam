import 'trip_plan_response.dart';

class TripShareLink {
  const TripShareLink({
    required this.idShare,
    required this.idPlan,
    required this.tokenPrefix,
    required this.allowCopy,
    required this.expiresAt,
    required this.revokedAt,
    required this.createdAt,
    this.title,
  });

  final String idShare;
  final String idPlan;
  final String tokenPrefix;
  final String? title;
  final bool allowCopy;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final DateTime createdAt;

  bool isActiveAt(DateTime now) => revokedAt == null && expiresAt.isAfter(now);

  factory TripShareLink.fromJson(Map<String, dynamic> json) {
    return TripShareLink(
      idShare: json['id_share'] as String? ?? '',
      idPlan: json['id_plan'] as String? ?? '',
      tokenPrefix: json['token_prefix'] as String? ?? '',
      title: json['title'] as String?,
      allowCopy: json['allow_copy'] as bool? ?? true,
      expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
      revokedAt: json['revoked_at'] == null
          ? null
          : DateTime.parse(json['revoked_at'] as String).toUtc(),
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    );
  }
}

class CreatedTripShare {
  const CreatedTripShare({required this.url, required this.link});

  final Uri url;
  final TripShareLink link;

  factory CreatedTripShare.fromJson(Map<String, dynamic> json) {
    return CreatedTripShare(
      url: Uri.parse(json['url'] as String),
      link: TripShareLink.fromJson(
        Map<String, dynamic>.from(json['link'] as Map),
      ),
    );
  }
}

class PublicSharedTrip {
  const PublicSharedTrip({
    required this.title,
    required this.allowCopy,
    required this.expiresAt,
    required this.plan,
  });

  final String title;
  final bool allowCopy;
  final DateTime expiresAt;
  final TripPlanResponse plan;

  factory PublicSharedTrip.fromJson(Map<String, dynamic> json) {
    return PublicSharedTrip(
      title: json['title'] as String? ?? 'Shared Vietnam itinerary',
      allowCopy: json['allow_copy'] as bool? ?? false,
      expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
      plan: TripPlanResponse.fromJson(json),
    );
  }
}
