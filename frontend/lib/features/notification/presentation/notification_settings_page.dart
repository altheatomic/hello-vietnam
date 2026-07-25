import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/notification/application/notification_preferences_controller.dart';
import 'package:hellovietnam/features/notification/application/push_notification_service.dart';
import 'package:hellovietnam/features/notification/domain/notification_preference.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, this.controller});

  final NotificationPreferencesController? controller;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  late final NotificationPreferencesController _controller =
      widget.controller ?? NotificationPreferencesController.instance;

  static const List<_NotificationCategory> _categories =
      <_NotificationCategory>[
        _NotificationCategory(
          type: NotificationPreferenceType.loyalty,
          title: 'Loyalty rewards',
          subtitle: 'Points, tiers, and reward activity',
          icon: Icons.stars_rounded,
        ),
        _NotificationCategory(
          type: NotificationPreferenceType.forum,
          title: 'Forum activity',
          subtitle: 'Replies, comments, likes, and follows',
          icon: Icons.forum_outlined,
        ),
        _NotificationCategory(
          type: NotificationPreferenceType.voucher,
          title: 'Vouchers',
          subtitle: 'New vouchers and expiry reminders',
          icon: Icons.confirmation_number_outlined,
        ),
        _NotificationCategory(
          type: NotificationPreferenceType.trip,
          title: 'Trips',
          subtitle: 'Itinerary and trip-planning updates',
          icon: Icons.calendar_month_outlined,
        ),
        _NotificationCategory(
          type: NotificationPreferenceType.account,
          title: 'Account',
          subtitle: 'Payments, subscriptions, and account security',
          icon: Icons.manage_accounts_outlined,
        ),
      ];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _controller.load();
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _setPreference(
    NotificationPreferenceType type,
    bool value,
  ) async {
    try {
      await _controller.setPushEnabled(type, value);
      if (type == NotificationPreferenceType.all && value) {
        await PushNotificationService.instance.syncCurrentDevice();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.ui('Could not update notification settings.'),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.ui('Notification settings')),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, Widget? child) {
          if (_controller.isLoading && !_controller.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!_controller.isLoaded && _controller.errorMessage != null) {
            return _NotificationSettingsError(onRetry: _load);
          }

          final NotificationPreference master = _controller.preference(
            NotificationPreferenceType.all,
          );
          return RefreshIndicator(
            onRefresh: () => _controller.load(force: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: <Widget>[
                _PreferenceTile(
                  type: NotificationPreferenceType.all,
                  icon: Icons.notifications_active_outlined,
                  title: context.l10n.ui('Android notifications'),
                  subtitle: context.l10n.ui(
                    'Turn native push notifications on or off. Your in-app history is kept.',
                  ),
                  value: master.pushEnabled,
                  saving: _controller.isSaving(NotificationPreferenceType.all),
                  onChanged: (bool value) =>
                      _setPreference(NotificationPreferenceType.all, value),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                  child: Text(
                    context.l10n.ui('Notification types'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ..._categories.map((_NotificationCategory category) {
                  final NotificationPreference preference = _controller
                      .preference(category.type);
                  return _PreferenceTile(
                    type: category.type,
                    icon: category.icon,
                    title: context.l10n.ui(category.title),
                    subtitle: context.l10n.ui(category.subtitle),
                    value: preference.pushEnabled,
                    saving: _controller.isSaving(category.type),
                    onChanged: (bool value) =>
                        _setPreference(category.type, value),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.saving,
    required this.onChanged,
  });

  final NotificationPreferenceType type;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: saving
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(
                key: ValueKey<String>('notification-switch-${type.name}'),
                value: value,
                onChanged: onChanged,
              ),
      ),
    );
  }
}

class _NotificationSettingsError extends StatelessWidget {
  const _NotificationSettingsError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text(context.l10n.ui('Could not load notification settings.')),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.l10n.ui('Retry')),
          ),
        ],
      ),
    );
  }
}

class _NotificationCategory {
  const _NotificationCategory({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final NotificationPreferenceType type;
  final String title;
  final String subtitle;
  final IconData icon;
}
