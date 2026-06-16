import 'package:flutter/foundation.dart';
import 'package:hellovietnam/features/notification/data/notification_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'loyalty_models.dart';
import 'loyalty_repository.dart';

class LoyaltyAwardService {
  LoyaltyAwardService._({LoyaltyRepository? repository})
    : _repository = repository ?? LoyaltyRepository();

  static final LoyaltyAwardService instance = LoyaltyAwardService._();

  static const String _notificationPreferenceKey =
      'loyalty_rewards_notifications_enabled';

  final LoyaltyRepository _repository;

  Future<LoyaltyTransaction?> award({
    required String actionType,
    String? referenceTable,
    String? referenceId,
    String? description,
    Map<String, dynamic>? metadata,
    bool notify = true,
  }) async {
    try {
      final LoyaltyTransaction transaction = await _repository.earnPoints(
        actionType: actionType,
        referenceTable: referenceTable,
        referenceId: referenceId,
        description: description,
        metadata: metadata,
      );

      if (notify &&
          transaction.status == 'approved' &&
          transaction.pointChange > 0 &&
          await _notificationsEnabled()) {
        MockNotificationRepository.instance.addLoyaltyPointsNotification(
          points: transaction.pointChange,
          actionLabel: transaction.description ?? description ?? actionType,
        );
      }

      return transaction;
    } catch (error) {
      debugPrint('Loyalty award skipped for $actionType: $error');
      return null;
    }
  }

  Future<bool> _notificationsEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationPreferenceKey) ?? true;
  }
}
