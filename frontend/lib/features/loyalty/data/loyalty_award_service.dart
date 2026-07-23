import 'package:flutter/foundation.dart';

import 'loyalty_models.dart';
import 'loyalty_repository.dart';

class LoyaltyAwardService {
  LoyaltyAwardService._({LoyaltyRepository? repository})
    : _repository = repository ?? LoyaltyRepository();

  static final LoyaltyAwardService instance = LoyaltyAwardService._();

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

      return transaction;
    } catch (error) {
      debugPrint('Loyalty award skipped for $actionType: $error');
      return null;
    }
  }
}
