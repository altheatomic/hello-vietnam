import 'package:flutter/material.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';

enum AppNotificationType { trip, forum, voucher, account }

extension AppNotificationTypeX on AppNotificationType {
  String get label {
    switch (this) {
      case AppNotificationType.trip:
        return 'TRIP';
      case AppNotificationType.forum:
        return 'FORUM';
      case AppNotificationType.voucher:
        return 'VOUCHER';
      case AppNotificationType.account:
        return 'ACCOUNT';
    }
  }

  Color get accentColor {
    switch (this) {
      case AppNotificationType.trip:
        return const Color(0xFFF4B63E);
      case AppNotificationType.forum:
        return const Color(0xFF87D4C0);
      case AppNotificationType.voucher:
        return const Color(0xFFFF6B7A);
      case AppNotificationType.account:
        return const Color(0xFF8B9BFF);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case AppNotificationType.trip:
        return const Color(0xFFFFF3DC);
      case AppNotificationType.forum:
        return const Color(0xFFE6FAF2);
      case AppNotificationType.voucher:
        return const Color(0xFFFFE8EC);
      case AppNotificationType.account:
        return const Color(0xFFEAEFFF);
    }
  }
}

enum AppNotificationIcon {
  megaphone,
  comment,
  dining,
  star,
  gift,
  badge,
  calendar,
}

extension AppNotificationIconX on AppNotificationIcon {
  IconData get iconData {
    switch (this) {
      case AppNotificationIcon.megaphone:
        return Icons.campaign_outlined;
      case AppNotificationIcon.comment:
        return Icons.mode_comment_outlined;
      case AppNotificationIcon.dining:
        return Icons.restaurant_outlined;
      case AppNotificationIcon.star:
        return Icons.star_border_rounded;
      case AppNotificationIcon.gift:
        return Icons.card_giftcard_rounded;
      case AppNotificationIcon.badge:
        return Icons.workspace_premium_outlined;
      case AppNotificationIcon.calendar:
        return Icons.calendar_month_outlined;
    }
  }
}

enum NotificationTargetKind {
  cityDetail,
  itemDetail,
  forumPost,
  recommendPage,
  recommendWhenResults,
  tripPlannerResult,
  tripPlannerSaved,
  tripPlannerDayDetail,
  voucherCenter,
  upgradeAccount,
  rankBenefits,
}

class NotificationTarget {
  const NotificationTarget({
    required this.kind,
    this.entityId,
    this.entityName,
    this.detailCategory,
    this.imagePath,
    this.rating,
    this.dayIndex,
    this.activityIndex,
    this.startDate,
    this.endDate,
    this.metadata = const <String, String>{},
  });

  final NotificationTargetKind kind;
  final String? entityId;
  final String? entityName;
  final DetailCategory? detailCategory;
  final String? imagePath;
  final double? rating;
  final int? dayIndex;
  final int? activityIndex;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, String> metadata;

  NotificationTarget copyWith({
    NotificationTargetKind? kind,
    String? entityId,
    String? entityName,
    DetailCategory? detailCategory,
    String? imagePath,
    double? rating,
    int? dayIndex,
    int? activityIndex,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, String>? metadata,
  }) {
    return NotificationTarget(
      kind: kind ?? this.kind,
      entityId: entityId ?? this.entityId,
      entityName: entityName ?? this.entityName,
      detailCategory: detailCategory ?? this.detailCategory,
      imagePath: imagePath ?? this.imagePath,
      rating: rating ?? this.rating,
      dayIndex: dayIndex ?? this.dayIndex,
      activityIndex: activityIndex ?? this.activityIndex,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'entityId': entityId,
      'entityName': entityName,
      'detailCategory': detailCategory?.name,
      'imagePath': imagePath,
      'rating': rating,
      'dayIndex': dayIndex,
      'activityIndex': activityIndex,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory NotificationTarget.fromJson(Map<String, dynamic> json) {
    final metadata = <String, String>{};
    final dynamic rawMetadata = json['metadata'];
    if (rawMetadata is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in rawMetadata.entries) {
        metadata[entry.key] = '${entry.value}';
      }
    }

    return NotificationTarget(
      kind: NotificationTargetKind.values.byName(
        json['kind'] as String? ?? NotificationTargetKind.recommendPage.name,
      ),
      entityId: json['entityId'] as String?,
      entityName: json['entityName'] as String?,
      detailCategory: _detailCategoryFromName(
        json['detailCategory'] as String?,
      ),
      imagePath: json['imagePath'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      dayIndex: json['dayIndex'] as int?,
      activityIndex: json['activityIndex'] as int?,
      startDate: _dateFromJson(json['startDate']),
      endDate: _dateFromJson(json['endDate']),
      metadata: metadata,
    );
  }

  static DetailCategory? _detailCategoryFromName(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final DetailCategory category in DetailCategory.values) {
      if (category.name == value) {
        return category;
      }
    }
    return null;
  }

  static DateTime? _dateFromJson(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.icon,
    required this.title,
    required this.description,
    required this.timestampLabel,
    required this.target,
    this.isRead = false,
    this.metadata = const <String, String>{},
  });

  final String id;
  final AppNotificationType type;
  final AppNotificationIcon icon;
  final String title;
  final String description;
  final String timestampLabel;
  final bool isRead;
  final NotificationTarget target;
  final Map<String, String> metadata;

  AppNotification copyWith({
    String? id,
    AppNotificationType? type,
    AppNotificationIcon? icon,
    String? title,
    String? description,
    String? timestampLabel,
    bool? isRead,
    NotificationTarget? target,
    Map<String, String>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      title: title ?? this.title,
      description: description ?? this.description,
      timestampLabel: timestampLabel ?? this.timestampLabel,
      isRead: isRead ?? this.isRead,
      target: target ?? this.target,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'icon': icon.name,
      'title': title,
      'description': description,
      'timestampLabel': timestampLabel,
      'isRead': isRead,
      'target': target.toJson(),
      'metadata': metadata,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final metadata = <String, String>{};
    final dynamic rawMetadata = json['metadata'];
    if (rawMetadata is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in rawMetadata.entries) {
        metadata[entry.key] = '${entry.value}';
      }
    }

    return AppNotification(
      id: json['id'] as String,
      type: AppNotificationType.values.byName(
        json['type'] as String? ?? AppNotificationType.trip.name,
      ),
      icon: AppNotificationIcon.values.byName(
        json['icon'] as String? ?? AppNotificationIcon.calendar.name,
      ),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timestampLabel: json['timestampLabel'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      target: NotificationTarget.fromJson(
        (json['target'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      metadata: metadata,
    );
  }
}

enum NotificationFilter { all, forum, voucher, account, trip }

extension NotificationFilterX on NotificationFilter {
  String get label {
    switch (this) {
      case NotificationFilter.all:
        return 'ALL';
      case NotificationFilter.forum:
        return 'FORUM';
      case NotificationFilter.voucher:
        return 'VOUCHER';
      case NotificationFilter.account:
        return 'ACCOUNT';
      case NotificationFilter.trip:
        return 'TRIP';
    }
  }

  bool matches(AppNotificationType type) {
    switch (this) {
      case NotificationFilter.all:
        return true;
      case NotificationFilter.forum:
        return type == AppNotificationType.forum;
      case NotificationFilter.voucher:
        return type == AppNotificationType.voucher;
      case NotificationFilter.account:
        return type == AppNotificationType.account;
      case NotificationFilter.trip:
        return type == AppNotificationType.trip;
    }
  }
}
