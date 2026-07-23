enum NotificationPreferenceType { all, loyalty, forum, voucher, trip, account }

class NotificationPreference {
  const NotificationPreference({
    required this.type,
    required this.pushEnabled,
    required this.inAppEnabled,
  });

  final NotificationPreferenceType type;
  final bool pushEnabled;
  final bool inAppEnabled;

  bool effectivePushEnabled(NotificationPreference master) {
    if (type == NotificationPreferenceType.all) return pushEnabled;
    return master.pushEnabled && pushEnabled;
  }

  NotificationPreference copyWith({bool? pushEnabled, bool? inAppEnabled}) {
    return NotificationPreference(
      type: type,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
    );
  }

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    final String rawType = (json['notification_type'] ?? 'all').toString();
    final NotificationPreferenceType type = NotificationPreferenceType.values
        .firstWhere(
          (NotificationPreferenceType item) => item.name == rawType,
          orElse: () => NotificationPreferenceType.all,
        );
    return NotificationPreference(
      type: type,
      pushEnabled: json['push_enabled'] as bool? ?? true,
      inAppEnabled: json['in_app_enabled'] as bool? ?? true,
    );
  }
}
