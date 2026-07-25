import 'admin_dashboard_models.dart';

abstract class AdminDashboardRepository {
  Future<AdminDashboardSnapshot> fetchDashboardSnapshot({
    bool forceRefresh = false,
  });
}
