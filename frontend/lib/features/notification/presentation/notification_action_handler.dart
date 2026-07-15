import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/city_detail/domain/city_detail_models.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/item_detail/domain/item_detail_models.dart';
import 'package:hellovietnam/features/notification/domain/app_notification.dart';

class NotificationActionHandler {
  NotificationActionHandler._();

  static Future<void> open(
    BuildContext context,
    AppNotification notification,
  ) async {
    final NotificationTarget target = notification.target;

    switch (target.kind) {
      case NotificationTargetKind.cityDetail:
        context.push(
          AppRoutes.cityDetail,
          extra: CityDetailRequest(
            id: target.entityId ?? notification.id,
            name: target.entityName ?? notification.title,
            fallbackImagePath: target.imagePath,
            fallbackImages: target.imagePath == null
                ? const <String>[]
                : <String>[target.imagePath!],
            fallbackRating: target.rating,
          ),
        );
        return;
      case NotificationTargetKind.itemDetail:
        final DetailCategory category =
            target.detailCategory ?? DetailCategory.activities;
        context.push(
          AppRoutes.detailPathForCategory(category),
          extra: ItemDetailRequest(
            id: target.entityId ?? notification.id,
            name: target.entityName ?? notification.title,
            category: category,
            fallbackImagePath: target.imagePath,
            fallbackImages: target.imagePath == null
                ? const <String>[]
                : <String>[target.imagePath!],
          ),
        );
        return;
      case NotificationTargetKind.forumPost:
        context.push(AppRoutes.forumPostPath(target.entityId ?? ''));
        return;
      case NotificationTargetKind.recommendPage:
        context.push(AppRoutes.recommendWhereSearch);
        return;
      case NotificationTargetKind.recommendWhenResults:
        final DateTime startDate = target.startDate ?? DateTime.now();
        final DateTime endDate =
            target.endDate ?? startDate.add(const Duration(days: 2));
        context.push(
          AppRoutes.recommendWhenResults,
          extra: DateTimeRange(start: startDate, end: endDate),
        );
        return;
      case NotificationTargetKind.tripPlannerResult:
        context.go(AppRoutes.tripPlannerResult);
        return;
      case NotificationTargetKind.tripPlannerSaved:
        context.go(AppRoutes.tripPlannerSaved);
        return;
      case NotificationTargetKind.tripPlannerDayDetail:
        context.go(AppRoutes.tripPlannerDayDetailPath(target.dayIndex ?? 0));
        return;
      case NotificationTargetKind.voucherCenter:
        context.push(AppRoutes.voucher);
        return;
      case NotificationTargetKind.upgradeAccount:
        context.push(AppRoutes.upgradeAccount);
        return;
      case NotificationTargetKind.rankBenefits:
        context.push(AppRoutes.rankBenefits);
        return;
      case NotificationTargetKind.loyaltyRewards:
        context.push(AppRoutes.loyalty);
        return;
    }
  }
}
