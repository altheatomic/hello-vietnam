import 'package:flutter/foundation.dart';
import 'package:hellovietnam/features/forum/data/forum_mock_data.dart';
import 'package:hellovietnam/features/home/data/home_mock_data.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:hellovietnam/features/notification/domain/app_notification.dart';
import 'package:hellovietnam/features/recommend/data/recommend_mock_data.dart';

abstract interface class NotificationRepository {
  Future<List<AppNotification>> fetchNotifications();

  Future<List<AppNotification>> markAsRead(String id);

  Future<List<AppNotification>> clearAll();
}

class MockNotificationRepository extends ChangeNotifier
    implements NotificationRepository {
  MockNotificationRepository._();

  static final MockNotificationRepository instance =
      MockNotificationRepository._();

  static final String _dalatImage = mockRecommendDestinations
      .firstWhere((destination) => destination.id == 'dalat')
      .imagePath;

  static final String _banhMiImage = mockDishes
      .firstWhere((dish) => dish.name == 'Banh Mi')
      .imagePath;

  final List<AppNotification> _items = <AppNotification>[
    AppNotification(
      id: 'notif-dalat-festival',
      type: AppNotificationType.trip,
      icon: AppNotificationIcon.megaphone,
      title: "Da Lat's got new festival!",
      description: "Don't miss the chance to go to the Flower Festival.",
      timestampLabel: '9 days ago',
      target: NotificationTarget(
        kind: NotificationTargetKind.itemDetail,
        entityId: 'dalat-flower-festival',
        entityName: 'Da Lat Flower Festival',
        detailCategory: DetailCategory.activities,
        imagePath: _dalatImage,
        metadata: <String, String>{
          'cityId': 'dalat',
          'cityName': 'Da Lat',
          'source': 'seasonal_campaign',
        },
      ),
    ),
    AppNotification(
      id: 'notif-forum-reply',
      type: AppNotificationType.forum,
      icon: AppNotificationIcon.comment,
      title: 'You got new replies',
      description: 'Brandon has just commented on your post',
      timestampLabel: '13 days ago',
      target: NotificationTarget(
        kind: NotificationTargetKind.forumPost,
        entityId: 'post-bun-mam',
        metadata: <String, String>{
          'trigger': 'reply',
          'actorId': ForumMockData.foodieExplorer.id,
        },
      ),
    ),
    AppNotification(
      id: 'notif-new-dish',
      type: AppNotificationType.trip,
      icon: AppNotificationIcon.dining,
      title: 'Fresh Flavors Unveiled!',
      description: 'New menu items are in! What will you try next?',
      timestampLabel: '4 days ago',
      target: NotificationTarget(
        kind: NotificationTargetKind.itemDetail,
        entityId: 'food-special-banh-mi',
        entityName: 'Banh Mi',
        detailCategory: DetailCategory.food,
        imagePath: _banhMiImage,
        metadata: <String, String>{'campaign': 'seasonal_food'},
      ),
    ),
    AppNotification(
      id: 'notif-trip-review',
      type: AppNotificationType.trip,
      icon: AppNotificationIcon.star,
      title: 'How was your trips?',
      description:
          'Tell us how satisfied you are on your 3-days trips in Ho Chi Minh City!!',
      timestampLabel: '1 week ago',
      target: const NotificationTarget(
        kind: NotificationTargetKind.tripPlannerResult,
        metadata: <String, String>{
          'tripId': 'trip-review-hcmc',
          'intent': 'review_trip',
        },
      ),
    ),
    AppNotification(
      id: 'notif-voucher',
      type: AppNotificationType.voucher,
      icon: AppNotificationIcon.gift,
      title: 'You got a new voucher!!',
      description: 'Get 10% off on for your premium subscription',
      timestampLabel: '11 days ago',
      target: const NotificationTarget(
        kind: NotificationTargetKind.voucherCenter,
        metadata: <String, String>{'voucherCode': 'PREMIUM10'},
      ),
    ),
    AppNotification(
      id: 'notif-recommend-dates',
      type: AppNotificationType.trip,
      icon: AppNotificationIcon.calendar,
      title: 'Your April getaway is ready',
      description:
          'We found destination suggestions that fit your travel dates.',
      timestampLabel: '2 days ago',
      isRead: true,
      target: NotificationTarget(
        kind: NotificationTargetKind.recommendWhenResults,
        startDate: DateTime(2026, 4, 18),
        endDate: DateTime(2026, 4, 21),
        metadata: const <String, String>{'origin': 'recommend_when'},
      ),
    ),
    AppNotification(
      id: 'notif-rank-benefits',
      type: AppNotificationType.account,
      icon: AppNotificationIcon.badge,
      title: 'You are close to Silver rank',
      description:
          'Check your benefits to unlock more vouchers and travel perks.',
      timestampLabel: '6 hours ago',
      isRead: true,
      target: const NotificationTarget(
        kind: NotificationTargetKind.rankBenefits,
        metadata: <String, String>{'origin': 'loyalty_system'},
      ),
    ),
  ];

  int get unreadCount => _items.where((item) => !item.isRead).length;

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    return _cloneItems();
  }

  @override
  Future<List<AppNotification>> markAsRead(String id) async {
    final int index = _items.indexWhere((item) => item.id == id);
    if (index != -1 && !_items[index].isRead) {
      _items[index] = _items[index].copyWith(isRead: true);
      notifyListeners();
    }
    return _cloneItems();
  }

  @override
  Future<List<AppNotification>> clearAll() async {
    _items.clear();
    notifyListeners();
    return _cloneItems();
  }

  List<AppNotification> _cloneItems() {
    return _items
        .map(
          (item) => item.copyWith(
            target: item.target.copyWith(
              metadata: Map<String, String>.from(item.target.metadata),
            ),
            metadata: Map<String, String>.from(item.metadata),
          ),
        )
        .toList(growable: false);
  }
}
