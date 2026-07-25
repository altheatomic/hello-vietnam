import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/network/supabase_function_client.dart';
import 'package:hellovietnam/features/admin/domain/admin_dashboard_models.dart';
import 'package:hellovietnam/features/admin/domain/admin_dashboard_repository.dart';

class AdminDashboardRepositoryImpl implements AdminDashboardRepository {
  AdminDashboardRepositoryImpl({SupabaseFunctionClient? functionClient})
    : _functionClient = functionClient ?? SupabaseFunctionClient();

  final SupabaseFunctionClient _functionClient;

  @override
  Future<AdminDashboardSnapshot> fetchDashboardSnapshot({
    bool forceRefresh = false,
  }) async {
    final Map<String, dynamic> response = await _functionClient.invokeJson(
      'admin-dashboard',
      body: <String, Object?>{'forceRefresh': forceRefresh},
      requireAuth: true,
      timeout: const Duration(seconds: 20),
    );
    return _AdminDashboardMapper.fromJson(_map(response['snapshot']));
  }
}

class _AdminDashboardMapper {
  const _AdminDashboardMapper._();

  static AdminDashboardSnapshot fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> users = _map(json['users']);
    final Map<String, dynamic> content = _map(json['content']);
    final Map<String, dynamic> reports = _map(json['reports']);
    final Map<String, dynamic> engagement = _map(json['engagement']);
    final Map<String, dynamic> subscriptions = _map(json['subscriptions']);

    final int totalUsers = _integer(users['total']);
    final int newUsers = _integer(users['new_30d']);
    final int previousUsers = _integer(users['previous_30d']);
    final int totalContent = _integer(content['total']);
    final int newPlaces = _integer(content['places_new_30d']);
    final int previousPlaces = _integer(content['places_previous_30d']);
    final int openReports = _integer(reports['open']);
    final int newReportsToday = _integer(reports['new_today']);
    final int plans = _integer(engagement['plans_30d']);
    final int forumPosts = _integer(engagement['forum_posts_30d']);
    final int favorites = _integer(engagement['favorites_30d']);
    final int activeSubscriptions = _integer(subscriptions['active']);
    final List<Map<String, dynamic>> statusRows = _mapList(
      reports['by_status'],
    );
    final List<Map<String, dynamic>> categoryRows = _mapList(
      reports['by_category'],
    );
    final int pendingReports = _countFor(statusRows, 'pending');
    final int reviewingReports = _countFor(statusRows, 'reviewing');

    return AdminDashboardSnapshot(
      generatedAtLabel: _generatedAtLabel(json['generated_at']),
      hero: DashboardHero(
        headline: 'Admin Dashboard',
        summary:
            'Live operational data aggregated by PostgreSQL for a fast, consistent view of users, content, engagement, subscriptions, and reports.',
        primaryCtaLabel: 'Review Reports',
        primaryCtaRoute: AppRoutes.adminReports,
        secondaryCtaLabel: 'Manage Users',
        secondaryCtaRoute: AppRoutes.adminUsers,
        highlightStats: <DashboardHeroStat>[
          DashboardHeroStat(
            label: 'New Places',
            value: _formatInteger(newPlaces),
            helper: 'Added in the last 30 days',
          ),
          DashboardHeroStat(
            label: 'Open Reports',
            value: _formatInteger(openReports),
            helper: '$newReportsToday received today',
          ),
          DashboardHeroStat(
            label: 'Registered Users',
            value: _formatInteger(totalUsers),
            helper: '$newUsers joined in the last 30 days',
          ),
        ],
      ),
      businessMetrics: <DashboardMetric>[
        _metric(
          id: 'new_places',
          title: 'New Places',
          value: newPlaces,
          previous: previousPlaces,
          helper: 'Places added in the last 30 days',
          kind: DashboardMetricKind.places,
          route: AppRoutes.adminPlaces,
        ),
        DashboardMetric(
          id: 'content_inventory',
          title: 'Content Inventory',
          value: _formatInteger(totalContent),
          helper:
              'Places, food, provinces, activities, culture, and local products',
          changeLabel: 'Live database total',
          changeDirection: DashboardChangeDirection.neutral,
          progress: _ratio(totalContent, totalContent),
          kind: DashboardMetricKind.content,
        ),
        DashboardMetric(
          id: 'trip_plans',
          title: 'Trip Plans',
          value: _formatInteger(plans),
          helper: 'Plans created in the last 30 days',
          changeLabel: 'Current 30-day window',
          changeDirection: DashboardChangeDirection.neutral,
          progress: _relativeProgress(plans),
          kind: DashboardMetricKind.planning,
        ),
        DashboardMetric(
          id: 'wishlist_saves',
          title: 'Wishlist Saves',
          value: _formatInteger(favorites),
          helper: 'Favorites added across all content types in 30 days',
          changeLabel: 'Current 30-day window',
          changeDirection: DashboardChangeDirection.neutral,
          progress: _relativeProgress(favorites),
          kind: DashboardMetricKind.hotPlaces,
        ),
      ],
      systemMetrics: <DashboardMetric>[
        DashboardMetric(
          id: 'open_reports',
          title: 'Open Reports',
          value: _formatInteger(openReports),
          helper: '$pendingReports pending and $reviewingReports reviewing',
          changeLabel: '$newReportsToday received today',
          changeDirection: openReports > 0
              ? DashboardChangeDirection.down
              : DashboardChangeDirection.neutral,
          progress: _relativeProgress(openReports),
          kind: DashboardMetricKind.reports,
          route: AppRoutes.adminReports,
        ),
        DashboardMetric(
          id: 'pending_reports',
          title: 'Pending Review',
          value: _formatInteger(pendingReports),
          helper: 'Reports that have not entered review yet',
          changeLabel: 'Requires admin triage',
          changeDirection: pendingReports > 0
              ? DashboardChangeDirection.down
              : DashboardChangeDirection.neutral,
          progress: _ratio(pendingReports, openReports),
          kind: DashboardMetricKind.moderation,
          route: AppRoutes.adminReports,
        ),
        _metric(
          id: 'registered_users',
          title: 'Registered Users',
          value: totalUsers,
          previous: (totalUsers - newUsers).clamp(0, totalUsers),
          helper: '$newUsers new users in the last 30 days',
          kind: DashboardMetricKind.users,
          route: AppRoutes.adminUsers,
        ),
        DashboardMetric(
          id: 'active_subscriptions',
          title: 'Active Premium',
          value: _formatInteger(activeSubscriptions),
          helper: 'Premium subscriptions currently marked active',
          changeLabel: 'Live subscription state',
          changeDirection: DashboardChangeDirection.neutral,
          progress: _ratio(activeSubscriptions, totalUsers),
          kind: DashboardMetricKind.revenue,
        ),
      ],
      customerDemandTrend: _engagementTrend(
        _mapList(engagement['weekly_4']),
        forumPosts: forumPosts,
        plans: plans,
        favorites: favorites,
      ),
      newPlacesTrend: _newPlacesTrend(
        _mapList(content['weekly_places_4']),
        total: newPlaces,
      ),
      trendingPlaces: _trendingPlaces(json['trending_places']),
      growthOpportunities: _inventorySignals(
        _mapList(content['inventory']),
        totalContent,
      ),
      requestBreakdown: _contentBreakdown(
        _mapList(content['inventory']),
        totalContent,
      ),
      reportBreakdown: _reportBreakdown(categoryRows),
      userGrowthTrend: _userGrowthTrend(_mapList(users['daily_7d']), newUsers),
      priorityQueue: _priorityQueue(statusRows),
      reportInsights: <DashboardHealthCheck>[
        DashboardHealthCheck(
          title: 'Open report workload',
          statusLabel: '$openReports open',
          helper: '$pendingReports pending and $reviewingReports reviewing.',
          severity: openReports == 0
              ? DashboardQueueSeverity.low
              : DashboardQueueSeverity.high,
          route: AppRoutes.adminReports,
        ),
        DashboardHealthCheck(
          title: 'User growth',
          statusLabel: '$newUsers new',
          helper: 'Compared with $previousUsers in the previous 30-day window.',
          severity: newUsers >= previousUsers
              ? DashboardQueueSeverity.low
              : DashboardQueueSeverity.medium,
          route: AppRoutes.adminUsers,
        ),
        DashboardHealthCheck(
          title: 'Content inventory',
          statusLabel: _formatInteger(totalContent),
          helper: '$newPlaces new places were added in the current window.',
          severity: DashboardQueueSeverity.low,
          route: AppRoutes.adminPlaces,
        ),
        DashboardHealthCheck(
          title: 'Active Premium',
          statusLabel: _formatInteger(activeSubscriptions),
          helper: 'Current active subscription records.',
          severity: DashboardQueueSeverity.low,
        ),
      ],
      featureUsagePeriods: <DashboardFeatureUsagePeriod>[
        _featureUsagePeriod(
          DashboardFeatureUsageRange.month,
          '1 Month',
          _mapList(engagement['feature_30d']),
        ),
        _featureUsagePeriod(
          DashboardFeatureUsageRange.quarter,
          '3 Months',
          _mapList(engagement['feature_90d']),
        ),
      ],
      quickActions: const <DashboardQuickAction>[
        DashboardQuickAction(
          title: 'Review reports',
          subtitle: 'Triage pending and reviewing reports',
          route: AppRoutes.adminReports,
        ),
        DashboardQuickAction(
          title: 'Manage users',
          subtitle: 'Inspect user accounts and roles',
          route: AppRoutes.adminUsers,
        ),
        DashboardQuickAction(
          title: 'Add content',
          subtitle: 'Create or update destination content',
          route: AppRoutes.adminPlaces,
        ),
      ],
    );
  }

  static DashboardMetric _metric({
    required String id,
    required String title,
    required int value,
    required int previous,
    required String helper,
    required DashboardMetricKind kind,
    String? route,
  }) {
    final double change = previous <= 0
        ? (value > 0 ? 1 : 0)
        : (value - previous) / previous;
    return DashboardMetric(
      id: id,
      title: title,
      value: _formatInteger(value),
      helper: helper,
      changeLabel: previous <= 0
          ? (value > 0 ? 'New activity' : 'No change')
          : '${change >= 0 ? '+' : ''}${(change * 100).toStringAsFixed(0)}% vs previous period',
      changeDirection: change > 0
          ? DashboardChangeDirection.up
          : change < 0
          ? DashboardChangeDirection.down
          : DashboardChangeDirection.neutral,
      progress: _relativeProgress(value),
      kind: kind,
      route: route,
    );
  }

  static DashboardTrendPanel _engagementTrend(
    List<Map<String, dynamic>> rows, {
    required int forumPosts,
    required int plans,
    required int favorites,
  }) {
    return DashboardTrendPanel(
      title: 'Customer Activity Trend',
      summary:
          'Weekly forum, planning, and wishlist activity from the live database.',
      xLabels: rows.map((row) => _text(row['label'], '-')).toList(),
      series: <DashboardTrendSeries>[
        DashboardTrendSeries(
          label: 'Forum posts',
          values: rows
              .map((row) => _integer(row['forum_posts']).toDouble())
              .toList(),
          summaryValue: '$forumPosts posts',
        ),
        DashboardTrendSeries(
          label: 'Trip plans',
          values: rows.map((row) => _integer(row['plans']).toDouble()).toList(),
          summaryValue: '$plans plans',
        ),
        DashboardTrendSeries(
          label: 'Wishlist saves',
          values: rows
              .map((row) => _integer(row['favorites']).toDouble())
              .toList(),
          summaryValue: '$favorites saves',
        ),
      ],
    );
  }

  static DashboardTrendPanel _newPlacesTrend(
    List<Map<String, dynamic>> rows, {
    required int total,
  }) {
    return DashboardTrendPanel(
      title: 'New Place Pipeline',
      summary: 'Places created in each of the last four calendar weeks.',
      xLabels: rows.map((row) => _text(row['label'], '-')).toList(),
      series: <DashboardTrendSeries>[
        DashboardTrendSeries(
          label: 'New places',
          values: rows.map((row) => _integer(row['count']).toDouble()).toList(),
          summaryValue: '$total added',
        ),
      ],
    );
  }

  static DashboardTrendPanel _userGrowthTrend(
    List<Map<String, dynamic>> rows,
    int total,
  ) {
    return DashboardTrendPanel(
      title: 'New User Trend',
      summary: 'Daily account registrations over the last seven days.',
      xLabels: rows.map((row) => _text(row['label'], '-')).toList(),
      series: <DashboardTrendSeries>[
        DashboardTrendSeries(
          label: 'New users',
          values: rows.map((row) => _integer(row['count']).toDouble()).toList(),
          summaryValue: '$total in 30 days',
        ),
      ],
    );
  }

  static List<DashboardContentSpotlight> _trendingPlaces(Object? value) {
    return _mapList(value).map((row) {
      final int views = _integer(row['views']);
      final int saves = _integer(row['saves']);
      final double rating = _decimal(row['rating']);
      return DashboardContentSpotlight(
        title: _text(row['name'], 'Unnamed place'),
        typeLabel: 'Place',
        viewsLabel: '${_formatInteger(views)} views',
        saveRateLabel: '${_formatInteger(saves)} saves',
        qualityLabel: rating > 0
            ? 'Average rating ${rating.toStringAsFixed(1)} / 5.'
            : 'No rating data is available yet.',
        route: AppRoutes.adminPlaces,
      );
    }).toList();
  }

  static List<DashboardSearchInsight> _inventorySignals(
    List<Map<String, dynamic>> rows,
    int total,
  ) {
    return rows.take(5).map((row) {
      final int count = _integer(row['count']);
      final int added = _integer(row['new_30d']);
      return DashboardSearchInsight(
        query: _text(row['label'], 'Content'),
        searches: count,
        resultRate: _ratio(count, total),
        conversionRate: _ratio(added, count),
        statusLabel: '$added new',
        volumeLabel: 'records',
        resultRateLabel: 'inventory share',
        conversionRateLabel: 'added this month',
        route: _routeForContent(_text(row['key'], '')),
      );
    }).toList();
  }

  static DashboardBreakdownPanel _contentBreakdown(
    List<Map<String, dynamic>> rows,
    int total,
  ) {
    return DashboardBreakdownPanel(
      title: 'Content Inventory',
      summary: 'Current records grouped by managed content type.',
      totalLabel: '${_formatInteger(total)} records',
      items: rows.map((row) {
        final int count = _integer(row['count']);
        final int added = _integer(row['new_30d']);
        return DashboardBreakdownItem(
          label: _text(row['label'], 'Content'),
          valueLabel: _formatInteger(count),
          count: count,
          share: _ratio(count, total),
          helper: '$added added in the last 30 days',
          route: _routeForContent(_text(row['key'], '')),
        );
      }).toList(),
    );
  }

  static DashboardBreakdownPanel _reportBreakdown(
    List<Map<String, dynamic>> rows,
  ) {
    final int total = rows.fold<int>(
      0,
      (sum, row) => sum + _integer(row['count']),
    );
    return DashboardBreakdownPanel(
      title: 'Reports By Category',
      summary: 'All submitted reports grouped by their database category.',
      totalLabel: '${_formatInteger(total)} reports',
      items: rows.map((row) {
        final int count = _integer(row['count']);
        return DashboardBreakdownItem(
          label: _humanize(_text(row['label'], 'other')),
          valueLabel: _formatInteger(count),
          count: count,
          share: _ratio(count, total),
          helper: 'Live report category count',
          route: AppRoutes.adminReports,
        );
      }).toList(),
    );
  }

  static List<DashboardQueueItem> _priorityQueue(
    List<Map<String, dynamic>> rows,
  ) {
    final List<DashboardQueueItem> items = rows
        .where((row) {
          final String status = _text(row['label'], '');
          return _integer(row['count']) > 0 &&
              (status == 'pending' || status == 'reviewing');
        })
        .map((row) {
          final String status = _text(row['label'], '');
          final int count = _integer(row['count']);
          return DashboardQueueItem(
            title: '${_humanize(status)} reports',
            subtitle: status == 'pending'
                ? 'Waiting for initial admin triage'
                : 'Already under admin review',
            countLabel: '$count reports',
            ageLabel: 'Live queue',
            severity: status == 'pending'
                ? DashboardQueueSeverity.high
                : DashboardQueueSeverity.medium,
            route: AppRoutes.adminReports,
          );
        })
        .toList();
    if (items.isNotEmpty) return items;
    return const <DashboardQueueItem>[
      DashboardQueueItem(
        title: 'Report queue is clear',
        subtitle: 'There are no pending or reviewing reports.',
        countLabel: '0 reports',
        ageLabel: 'Up to date',
        severity: DashboardQueueSeverity.low,
        route: AppRoutes.adminReports,
      ),
    ];
  }

  static DashboardFeatureUsagePeriod _featureUsagePeriod(
    DashboardFeatureUsageRange range,
    String label,
    List<Map<String, dynamic>> rows,
  ) {
    final int total = rows.fold<int>(
      0,
      (sum, row) => sum + _integer(row['count']),
    );
    return DashboardFeatureUsagePeriod(
      range: range,
      label: label,
      helper: 'Event counts from forum posts, trip plans, and wishlist saves.',
      totalLabel: '${_formatInteger(total)} events',
      items: rows.map((row) {
        final int count = _integer(row['count']);
        final String feature = _text(row['feature'], 'Feature');
        return DashboardFeatureUsage(
          feature: feature,
          sessions: count,
          share: _ratio(count, total),
          helper: '$count recorded events',
          route: _featureRoute(feature),
        );
      }).toList(),
    );
  }

  static String? _routeForContent(String key) {
    return switch (key) {
      'place' => AppRoutes.adminPlaces,
      'food' => AppRoutes.adminFood,
      'province' => AppRoutes.adminProvinces,
      'activity' => AppRoutes.adminActivities,
      'culture' => AppRoutes.adminCultures,
      'local_product' => AppRoutes.adminLocalProducts,
      _ => null,
    };
  }

  static String? _featureRoute(String feature) {
    return switch (feature.toLowerCase()) {
      'forum' => null,
      'trip planner' => null,
      'wishlist' => null,
      _ => null,
    };
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (Object? key, Object? item) => MapEntry(key.toString(), item),
    );
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value.map(_map).toList();
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _decimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _text(Object? value, String fallback) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _countFor(List<Map<String, dynamic>> rows, String label) {
  for (final Map<String, dynamic> row in rows) {
    if (_text(row['label'], '') == label) return _integer(row['count']);
  }
  return 0;
}

double _ratio(int value, int total) {
  if (total <= 0) return 0;
  return (value / total).clamp(0.0, 1.0);
}

double _relativeProgress(int value) {
  if (value <= 0) return 0;
  return (value / (value + 20)).clamp(0.0, 1.0);
}

String _formatInteger(int value) {
  final String digits = value.abs().toString();
  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

String _generatedAtLabel(Object? value) {
  final DateTime? parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return 'Live database snapshot';
  final DateTime local = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return 'Synced ${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _humanize(String value) {
  if (value.isEmpty) return 'Other';
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
