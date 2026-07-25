import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/admin/domain/admin_dashboard_models.dart';
import 'package:hellovietnam/features/admin/domain/admin_dashboard_repository.dart';

class MockAdminDashboardRepository implements AdminDashboardRepository {
  const MockAdminDashboardRepository();

  @override
  Future<AdminDashboardSnapshot> fetchDashboardSnapshot({
    bool forceRefresh = false,
  }) async {
    return const AdminDashboardSnapshot(
      generatedAtLabel: 'Synced 21 Apr 2026 • 16:45 ICT',
      hero: DashboardHero(
        headline: 'Admin Dashboard',
        summary:
            'Dashboard is now split into business operations and system operations so admins can track growth signals, user demand, pending work, reports, and feature adoption from one place.',
        primaryCtaLabel: 'Review Reports',
        primaryCtaRoute: AppRoutes.adminReports,
        secondaryCtaLabel: 'Manage Users',
        secondaryCtaRoute: AppRoutes.adminUsers,
        highlightStats: <DashboardHeroStat>[
          DashboardHeroStat(
            label: 'New Places',
            value: '42',
            helper: 'Added in the last 30 days',
          ),
          DashboardHeroStat(
            label: 'Hot Destinations',
            value: '9',
            helper: 'High search and save momentum',
          ),
          DashboardHeroStat(
            label: 'Pending Admin Work',
            value: '47',
            helper: 'Requests, reports, and review tasks',
          ),
        ],
      ),
      businessMetrics: <DashboardMetric>[
        DashboardMetric(
          id: 'new_places',
          title: 'New Places',
          value: '42',
          helper: '12 restaurants, 18 attractions, 8 cafes, 4 local services',
          changeLabel: '+18% vs last month',
          changeDirection: DashboardChangeDirection.up,
          progress: 0.72,
          kind: DashboardMetricKind.places,
        ),
        DashboardMetric(
          id: 'hot_places',
          title: 'Places Getting Hot',
          value: '9',
          helper: 'Nha Trang, Da Lat, and Ha Giang are leading demand',
          changeLabel: '+3 trend spikes',
          changeDirection: DashboardChangeDirection.up,
          progress: 0.82,
          kind: DashboardMetricKind.hotPlaces,
        ),
        DashboardMetric(
          id: 'traveler_demand',
          title: 'Traveler Demand',
          value: '31.8k',
          helper: 'Searches, detail views, and saved places this month',
          changeLabel: '+12.6% demand',
          changeDirection: DashboardChangeDirection.up,
          progress: 0.79,
          kind: DashboardMetricKind.search,
        ),
        DashboardMetric(
          id: 'growth_opportunities',
          title: 'Growth Opportunities',
          value: '6',
          helper: 'Demand clusters where more content can lift conversion',
          changeLabel: '4 high priority',
          changeDirection: DashboardChangeDirection.neutral,
          progress: 0.64,
          kind: DashboardMetricKind.revenue,
        ),
      ],
      systemMetrics: <DashboardMetric>[
        DashboardMetric(
          id: 'pending_requests',
          title: 'Pending Requests / Tasks',
          value: '33',
          helper: '13 failed syncs, 9 content requests, 11 admin tasks',
          changeLabel: '+7 today',
          changeDirection: DashboardChangeDirection.down,
          progress: 0.66,
          kind: DashboardMetricKind.requests,
          route: AppRoutes.adminFeedback,
        ),
        DashboardMetric(
          id: 'open_reports',
          title: 'Open Reports',
          value: '14',
          helper: '5 critical cases need admin action in 2 hours',
          changeLabel: '+4 reports',
          changeDirection: DashboardChangeDirection.down,
          progress: 0.46,
          kind: DashboardMetricKind.reports,
          route: AppRoutes.adminReports,
        ),
        DashboardMetric(
          id: 'registered_users',
          title: 'Registered Users',
          value: '24,860',
          helper: '1,642 monthly active travelers',
          changeLabel: '+8.4% growth',
          changeDirection: DashboardChangeDirection.up,
          progress: 0.76,
          kind: DashboardMetricKind.users,
          route: AppRoutes.adminUsers,
        ),
        DashboardMetric(
          id: 'feature_adoption_score',
          title: 'Feature Adoption',
          value: '72%',
          helper: 'Average adoption across Explore, Recommend, and Planner',
          changeLabel: '+5.2 pts',
          changeDirection: DashboardChangeDirection.up,
          progress: 0.72,
          kind: DashboardMetricKind.adoption,
        ),
      ],
      customerDemandTrend: DashboardTrendPanel(
        title: 'Customer Demand Trend',
        summary:
            'Demand is moving toward beach trips, cool-weather cities, and motorbike-loop planning. These signals should guide content and promotion priorities.',
        xLabels: <String>['W1', 'W2', 'W3', 'W4'],
        series: <DashboardTrendSeries>[
          DashboardTrendSeries(
            label: 'Destination searches',
            values: <double>[4200, 4680, 5320, 6100],
            summaryValue: '20.3k searches',
          ),
          DashboardTrendSeries(
            label: 'Place detail views',
            values: <double>[3600, 4120, 4890, 5520],
            summaryValue: '18.1k views',
          ),
          DashboardTrendSeries(
            label: 'Saves to trip plan',
            values: <double>[820, 960, 1240, 1480],
            summaryValue: '4.5k saves',
          ),
        ],
      ),
      newPlacesTrend: DashboardTrendPanel(
        title: 'New Place Pipeline',
        summary:
            'Tracks how many new places are added and whether users are actually discovering them after publish.',
        xLabels: <String>['W1', 'W2', 'W3', 'W4'],
        series: <DashboardTrendSeries>[
          DashboardTrendSeries(
            label: 'New places',
            values: <double>[7, 9, 11, 15],
            summaryValue: '42 added',
          ),
          DashboardTrendSeries(
            label: 'New place views',
            values: <double>[920, 1160, 1440, 1880],
            summaryValue: '5.4k views',
          ),
          DashboardTrendSeries(
            label: 'Planner handoffs',
            values: <double>[120, 148, 190, 264],
            summaryValue: '722 handoffs',
          ),
        ],
      ),
      trendingPlaces: <DashboardContentSpotlight>[
        DashboardContentSpotlight(
          title: 'Nha Trang',
          typeLabel: 'Beach destination',
          viewsLabel: '8.4k views',
          saveRateLabel: '31% saved',
          qualityLabel:
              'Users are clustering around island hopping, seafood, and short family trips.',
        ),
        DashboardContentSpotlight(
          title: 'Da Lat',
          typeLabel: 'Cool-weather city',
          viewsLabel: '7.1k views',
          saveRateLabel: '34% planner handoff',
          qualityLabel:
              'Cafe, flower garden, and weekend escape content should be expanded.',
        ),
        DashboardContentSpotlight(
          title: 'Ha Giang Loop',
          typeLabel: 'Adventure route',
          viewsLabel: '5.8k views',
          saveRateLabel: '29% saved',
          qualityLabel:
              'High intent from international users, but guide coverage is still thin.',
        ),
        DashboardContentSpotlight(
          title: 'Phu Quoc',
          typeLabel: 'Island destination',
          viewsLabel: '4.9k views',
          saveRateLabel: '24% planner handoff',
          qualityLabel:
              'Search growth suggests demand for beach clubs, local transport, and weather tips.',
        ),
      ],
      growthOpportunities: <DashboardSearchInsight>[
        DashboardSearchInsight(
          query: 'Hue vegetarian food',
          searches: 1210,
          resultRate: 0.72,
          conversionRate: 0.21,
          statusLabel: 'Need food content',
          route: AppRoutes.adminFood,
        ),
        DashboardSearchInsight(
          query: 'Vietnam train booking app',
          searches: 1160,
          resultRate: 0.61,
          conversionRate: 0.19,
          statusLabel: 'Need guide',
          route: AppRoutes.adminPopularApps,
        ),
        DashboardSearchInsight(
          query: 'Da Nang rainy day activities',
          searches: 980,
          resultRate: 0.76,
          conversionRate: 0.27,
          statusLabel: 'Build itinerary',
        ),
        DashboardSearchInsight(
          query: 'Nha Trang family trip',
          searches: 910,
          resultRate: 0.84,
          conversionRate: 0.36,
          statusLabel: 'Promote package',
        ),
      ],
      requestBreakdown: DashboardBreakdownPanel(
        title: 'Request / Task Status',
        summary:
            'Shows exactly what is stuck or waiting, without mixing it with report volume or user growth.',
        totalLabel: '33 pending',
        items: <DashboardBreakdownItem>[
          DashboardBreakdownItem(
            label: 'Failed sync requests',
            valueLabel: '13',
            count: 13,
            share: 0.39,
            helper: 'Content writes waiting for retry after API timeout.',
            severity: DashboardQueueSeverity.critical,
            route: AppRoutes.adminFeedback,
          ),
          DashboardBreakdownItem(
            label: 'Content update requests',
            valueLabel: '9',
            count: 9,
            share: 0.27,
            helper: 'New place and food edits waiting for admin review.',
            severity: DashboardQueueSeverity.high,
            route: AppRoutes.adminFood,
          ),
          DashboardBreakdownItem(
            label: 'Account review tasks',
            valueLabel: '6',
            count: 6,
            share: 0.18,
            helper: 'Suspicious user accounts need manual checking.',
            severity: DashboardQueueSeverity.medium,
            route: AppRoutes.adminUsers,
          ),
          DashboardBreakdownItem(
            label: 'Guide refresh tasks',
            valueLabel: '5',
            count: 5,
            share: 0.16,
            helper: 'Transport and wallet guides need current screenshots.',
            severity: DashboardQueueSeverity.medium,
            route: AppRoutes.adminPopularApps,
          ),
        ],
      ),
      reportBreakdown: DashboardBreakdownPanel(
        title: 'Report Breakdown',
        summary:
            'Report volume grouped by issue type so moderators can focus on the highest-risk cases first.',
        totalLabel: '14 reports',
        items: <DashboardBreakdownItem>[
          DashboardBreakdownItem(
            label: 'Spam links',
            valueLabel: '6',
            count: 6,
            share: 0.43,
            helper: 'Mostly newly created forum profiles.',
            severity: DashboardQueueSeverity.high,
            route: AppRoutes.adminReports,
          ),
          DashboardBreakdownItem(
            label: 'Unsafe travel advice',
            valueLabel: '5',
            count: 5,
            share: 0.36,
            helper: 'Taxi and border-crossing advice need quick review.',
            severity: DashboardQueueSeverity.critical,
            route: AppRoutes.adminReports,
          ),
          DashboardBreakdownItem(
            label: 'Abusive language',
            valueLabel: '3',
            count: 3,
            share: 0.21,
            helper: 'Low volume, but still visible in comment threads.',
            severity: DashboardQueueSeverity.medium,
            route: AppRoutes.adminReports,
          ),
        ],
      ),
      userGrowthTrend: DashboardTrendPanel(
        title: 'User Growth Trend',
        summary:
            'User-focused chart only: sign-ups, verified accounts, and returning active users over the last 7 days.',
        xLabels: <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        series: <DashboardTrendSeries>[
          DashboardTrendSeries(
            label: 'New sign-ups',
            values: <double>[48, 52, 60, 66, 74, 82, 70],
            summaryValue: '452 new',
          ),
          DashboardTrendSeries(
            label: 'Verified users',
            values: <double>[39, 43, 51, 58, 61, 69, 62],
            summaryValue: '383 verified',
          ),
          DashboardTrendSeries(
            label: 'Returning active users',
            values: <double>[920, 980, 1040, 1110, 1180, 1260, 1210],
            summaryValue: '7.7k active',
          ),
        ],
      ),
      priorityQueue: <DashboardQueueItem>[
        DashboardQueueItem(
          title: 'Failed content sync requests',
          subtitle:
              'Destination and food updates are queued after Supabase timeout retries.',
          countLabel: '13 requests',
          ageLabel: 'Oldest: 2h 10m',
          severity: DashboardQueueSeverity.critical,
          route: AppRoutes.adminFeedback,
        ),
        DashboardQueueItem(
          title: 'Forum reports waiting for moderation',
          subtitle: 'Spam links and unsafe taxi advice are the main issues.',
          countLabel: '14 reports',
          ageLabel: 'Oldest: 1h 24m',
          severity: DashboardQueueSeverity.high,
          route: AppRoutes.adminReports,
        ),
        DashboardQueueItem(
          title: 'User accounts needing review',
          subtitle: 'Repeated link posting from newly created profiles.',
          countLabel: '6 accounts',
          ageLabel: 'Detected today',
          severity: DashboardQueueSeverity.medium,
          route: AppRoutes.adminUsers,
        ),
        DashboardQueueItem(
          title: 'Guide refresh tasks',
          subtitle: 'Transport and wallet app screenshots are outdated.',
          countLabel: '5 tasks',
          ageLabel: 'Due this week',
          severity: DashboardQueueSeverity.medium,
          route: AppRoutes.adminPopularApps,
        ),
      ],
      reportInsights: <DashboardHealthCheck>[
        DashboardHealthCheck(
          title: 'Report volume',
          statusLabel: '14 open',
          helper: '5 critical, 6 medium, 3 low-priority cases.',
          severity: DashboardQueueSeverity.high,
          route: AppRoutes.adminReports,
        ),
        DashboardHealthCheck(
          title: 'Request health',
          statusLabel: '13 failed',
          helper: 'Most failures are write retries from content updates.',
          severity: DashboardQueueSeverity.critical,
          route: AppRoutes.adminFeedback,
        ),
        DashboardHealthCheck(
          title: 'User growth',
          statusLabel: '+452/week',
          helper: 'Growth is healthy, with the biggest lift from Explore.',
          severity: DashboardQueueSeverity.low,
          route: AppRoutes.adminUsers,
        ),
        DashboardHealthCheck(
          title: 'Moderation turnaround',
          statusLabel: '1h 42m avg',
          helper: 'Still acceptable, but evening spikes need attention.',
          severity: DashboardQueueSeverity.medium,
          route: AppRoutes.adminReports,
        ),
      ],
      featureUsagePeriods: <DashboardFeatureUsagePeriod>[
        DashboardFeatureUsagePeriod(
          range: DashboardFeatureUsageRange.month,
          label: '1 Month',
          helper:
              'Monthly adoption shows which product areas are moving current user behavior.',
          totalLabel: '34.2k sessions',
          items: <DashboardFeatureUsage>[
            DashboardFeatureUsage(
              feature: 'Explore',
              sessions: 8892,
              share: 0.26,
              helper: 'Main entry point for destination discovery',
            ),
            DashboardFeatureUsage(
              feature: 'Recommend',
              sessions: 7182,
              share: 0.21,
              helper: 'Strong fit for where-and-when decisions',
            ),
            DashboardFeatureUsage(
              feature: 'Trip Planner',
              sessions: 6156,
              share: 0.18,
              helper: 'High intent, especially after place saves',
            ),
            DashboardFeatureUsage(
              feature: 'AI Search',
              sessions: 4788,
              share: 0.14,
              helper: 'Useful for first-time travelers',
            ),
            DashboardFeatureUsage(
              feature: 'Food Detail',
              sessions: 3762,
              share: 0.11,
              helper: 'Growing from destination detail pages',
              route: AppRoutes.adminFood,
            ),
            DashboardFeatureUsage(
              feature: 'Popular Apps',
              sessions: 3420,
              share: 0.10,
              helper: 'Utility guides still drive repeat visits',
              route: AppRoutes.adminPopularApps,
            ),
          ],
        ),
        DashboardFeatureUsagePeriod(
          range: DashboardFeatureUsageRange.quarter,
          label: '1 Quarter',
          helper:
              'Quarterly adoption smooths short-term spikes and reveals which features are becoming habits.',
          totalLabel: '112.8k sessions',
          items: <DashboardFeatureUsage>[
            DashboardFeatureUsage(
              feature: 'Explore',
              sessions: 25944,
              share: 0.23,
              helper: 'Largest sustained discovery surface',
            ),
            DashboardFeatureUsage(
              feature: 'Recommend',
              sessions: 22560,
              share: 0.20,
              helper: 'Consistent conversion into planned trips',
            ),
            DashboardFeatureUsage(
              feature: 'Trip Planner',
              sessions: 21432,
              share: 0.19,
              helper: 'Best indicator of high-intent travelers',
            ),
            DashboardFeatureUsage(
              feature: 'AI Search',
              sessions: 16920,
              share: 0.15,
              helper: 'Strong adoption for long-tail travel questions',
            ),
            DashboardFeatureUsage(
              feature: 'Forum',
              sessions: 13536,
              share: 0.12,
              helper: 'Engaging, but moderation cost is higher',
              route: AppRoutes.adminReports,
            ),
            DashboardFeatureUsage(
              feature: 'Popular Apps',
              sessions: 12408,
              share: 0.11,
              helper: 'Reliable utility content for returning users',
              route: AppRoutes.adminPopularApps,
            ),
          ],
        ),
      ],
      quickActions: <DashboardQuickAction>[
        DashboardQuickAction(
          title: 'Resolve reports',
          subtitle: 'Open moderation cases with highest user impact.',
          route: AppRoutes.adminReports,
        ),
        DashboardQuickAction(
          title: 'Review failed requests',
          subtitle: 'Check fresh feedback and operational issues.',
          route: AppRoutes.adminFeedback,
        ),
        DashboardQuickAction(
          title: 'Audit users',
          subtitle: 'Inspect suspicious sign-ups and banned accounts.',
          route: AppRoutes.adminUsers,
        ),
        DashboardQuickAction(
          title: 'Add food content',
          subtitle: 'Close demand gaps from high-volume searches.',
          route: AppRoutes.adminFood,
        ),
        DashboardQuickAction(
          title: 'Refresh app guides',
          subtitle: 'Update current screenshots and transport instructions.',
          route: AppRoutes.adminPopularApps,
        ),
      ],
    );
  }
}
