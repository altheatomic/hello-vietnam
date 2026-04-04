import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/features/admin/domain/admin_dashboard_models.dart';
import 'package:hellovietnam/features/admin/domain/admin_dashboard_repository.dart';

class MockAdminDashboardRepository implements AdminDashboardRepository {
  const MockAdminDashboardRepository();

  @override
  Future<AdminDashboardSnapshot> fetchDashboardSnapshot() async {
    return const AdminDashboardSnapshot(
      generatedAtLabel: 'Synced 04 Apr 2026 • 09:30 ICT',
      hero: DashboardHero(
        headline: 'Platform Pulse',
        summary:
            'Explore and recommend journeys are driving the most demand today, while moderation and feedback need quick attention before the weekend travel spike.',
        primaryCtaLabel: 'Open Reports',
        primaryCtaRoute: AppRoutes.adminReports,
        secondaryCtaLabel: 'Review Feedback',
        secondaryCtaRoute: AppRoutes.adminFeedback,
        highlightStats: <DashboardHeroStat>[
          DashboardHeroStat(
            label: 'Active Users',
            value: '1,284',
            helper: '+11.8% vs last week',
          ),
          DashboardHeroStat(
            label: 'Trip Plans Started',
            value: '386',
            helper: '74 completed itineraries today',
          ),
          DashboardHeroStat(
            label: 'Items Needing Review',
            value: '19',
            helper: 'reports + unresolved feedback',
          ),
        ],
      ),
      metrics: <DashboardMetric>[
        DashboardMetric(
          id: 'users_total',
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
          id: 'reports_open',
          title: 'Open Reports',
          value: '12',
          helper: '5 need action in the next 2 hours',
          changeLabel: '+3 since yesterday',
          changeDirection: DashboardChangeDirection.down,
          progress: 0.41,
          kind: DashboardMetricKind.moderation,
          route: AppRoutes.adminReports,
        ),
        DashboardMetric(
          id: 'feedback_new',
          title: 'New Feedback',
          value: '37',
          helper: '9 mention search quality or UI friction',
          changeLabel: '+14.2% submissions',
          changeDirection: DashboardChangeDirection.up,
          progress: 0.63,
          kind: DashboardMetricKind.feedback,
          route: AppRoutes.adminFeedback,
        ),
        DashboardMetric(
          id: 'food_content',
          title: 'Food Entries',
          value: '128',
          helper: '11 are trending inside destination detail flows',
          changeLabel: '+6 updated this week',
          changeDirection: DashboardChangeDirection.up,
          progress: 0.58,
          kind: DashboardMetricKind.content,
          route: AppRoutes.adminFood,
        ),
        DashboardMetric(
          id: 'planner_completion',
          title: 'Planner Completion',
          value: '68%',
          helper: 'from location step to itinerary result',
          changeLabel: '+5.1 pts',
          changeDirection: DashboardChangeDirection.up,
          progress: 0.68,
          kind: DashboardMetricKind.planning,
        ),
        DashboardMetric(
          id: 'search_zero_result',
          title: 'Zero-result Searches',
          value: '7.9%',
          helper: 'mostly destination spelling variants',
          changeLabel: '-2.4 pts',
          changeDirection: DashboardChangeDirection.up,
          progress: 0.22,
          kind: DashboardMetricKind.search,
        ),
      ],
      usageTrend: DashboardTrendPanel(
        title: 'Usage Pulse',
        summary:
            'Search demand rose sharply from Thursday onward, and planner starts are following close behind active usage.',
        xLabels: <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        series: <DashboardTrendSeries>[
          DashboardTrendSeries(
            label: 'Active users',
            values: <double>[420, 480, 510, 690, 840, 910, 870],
            summaryValue: '4.7k weekly',
          ),
          DashboardTrendSeries(
            label: 'Search sessions',
            values: <double>[380, 430, 455, 640, 790, 860, 825],
            summaryValue: '4.4k searches',
          ),
          DashboardTrendSeries(
            label: 'Planner starts',
            values: <double>[120, 150, 190, 255, 310, 342, 328],
            summaryValue: '1.7k starts',
          ),
        ],
      ),
      featureUsage: <DashboardFeatureUsage>[
        DashboardFeatureUsage(
          feature: 'Explore',
          sessions: 1680,
          share: 0.24,
          helper: 'Strong lift from destination browsing',
        ),
        DashboardFeatureUsage(
          feature: 'Trip Planner',
          sessions: 1412,
          share: 0.20,
          helper: 'High downstream intent and longer sessions',
        ),
        DashboardFeatureUsage(
          feature: 'Recommend',
          sessions: 1265,
          share: 0.18,
          helper: 'Where + When flow is converting well',
        ),
        DashboardFeatureUsage(
          feature: 'AI Search',
          sessions: 980,
          share: 0.14,
          helper: 'Popular for first-time travelers',
        ),
        DashboardFeatureUsage(
          feature: 'Forum',
          sessions: 905,
          share: 0.13,
          helper: 'Useful engagement but moderation-heavy',
          route: AppRoutes.adminReports,
        ),
        DashboardFeatureUsage(
          feature: 'Popular Apps',
          sessions: 756,
          share: 0.11,
          helper: 'Grab and MoMo dominate interest',
          route: AppRoutes.adminPopularApps,
        ),
      ],
      searchInsights: <DashboardSearchInsight>[
        DashboardSearchInsight(
          query: 'Da Lat cafes',
          searches: 214,
          resultRate: 0.97,
          conversionRate: 0.48,
          statusLabel: 'Healthy',
        ),
        DashboardSearchInsight(
          query: 'Nha Trang island hopping',
          searches: 192,
          resultRate: 0.95,
          conversionRate: 0.44,
          statusLabel: 'Healthy',
        ),
        DashboardSearchInsight(
          query: 'Hanoi autumn weather',
          searches: 168,
          resultRate: 0.89,
          conversionRate: 0.38,
          statusLabel: 'Watch',
        ),
        DashboardSearchInsight(
          query: 'Hue vegetarian food',
          searches: 121,
          resultRate: 0.72,
          conversionRate: 0.21,
          statusLabel: 'Needs content',
          route: AppRoutes.adminFood,
        ),
        DashboardSearchInsight(
          query: 'Vietnam train booking app',
          searches: 116,
          resultRate: 0.61,
          conversionRate: 0.19,
          statusLabel: 'Guide gap',
          route: AppRoutes.adminPopularApps,
        ),
      ],
      priorityQueue: <DashboardQueueItem>[
        DashboardQueueItem(
          title: 'Forum reports waiting for moderation',
          subtitle: '3 posts mention unsafe taxi advice and spam links.',
          countLabel: '7 open cases',
          ageLabel: 'Oldest: 1h 24m',
          severity: DashboardQueueSeverity.critical,
          route: AppRoutes.adminReports,
        ),
        DashboardQueueItem(
          title: 'Feedback mentioning search frustration',
          subtitle:
              'Users report difficulty finding destination-specific foods.',
          countLabel: '5 fresh submissions',
          ageLabel: 'Newest: 18m ago',
          severity: DashboardQueueSeverity.high,
          route: AppRoutes.adminFeedback,
        ),
        DashboardQueueItem(
          title: 'Popular app guides that need refresh',
          subtitle: 'Grab and Be screenshots are older than the current flow.',
          countLabel: '4 guides flagged',
          ageLabel: 'Due this week',
          severity: DashboardQueueSeverity.medium,
          route: AppRoutes.adminPopularApps,
        ),
        DashboardQueueItem(
          title: 'User review needed for suspicious accounts',
          subtitle: 'Repeated link posting from recently created profiles.',
          countLabel: '3 profiles',
          ageLabel: 'Detected overnight',
          severity: DashboardQueueSeverity.medium,
          route: AppRoutes.adminUsers,
        ),
      ],
      contentSpotlights: <DashboardContentSpotlight>[
        DashboardContentSpotlight(
          title: 'Nha Trang',
          typeLabel: 'City detail',
          viewsLabel: '8.4k views',
          saveRateLabel: '31% wishlisted',
          qualityLabel: 'Best-time content is resonating',
        ),
        DashboardContentSpotlight(
          title: 'Bun Bo Hue',
          typeLabel: 'Food detail',
          viewsLabel: '5.1k views',
          saveRateLabel: '27% click-through',
          qualityLabel: 'High organic demand from search',
          route: AppRoutes.adminFood,
        ),
        DashboardContentSpotlight(
          title: 'Grab',
          typeLabel: 'Popular app guide',
          viewsLabel: '4.3k views',
          saveRateLabel: '22% completion',
          qualityLabel: 'Strong utility, needs screenshot refresh',
          route: AppRoutes.adminPopularApps,
        ),
        DashboardContentSpotlight(
          title: 'Da Lat city detail',
          typeLabel: 'Recommend / Where',
          viewsLabel: '3.7k views',
          saveRateLabel: '29% planner handoff',
          qualityLabel: 'Excellent conversion into trip planning',
        ),
      ],
      healthChecks: <DashboardHealthCheck>[
        DashboardHealthCheck(
          title: 'Search coverage for long-tail queries',
          statusLabel: '82% matched',
          helper: 'Vegetarian food and train-app queries are the biggest gaps.',
          severity: DashboardQueueSeverity.medium,
        ),
        DashboardHealthCheck(
          title: 'Moderation turnaround time',
          statusLabel: '1h 42m avg',
          helper: 'Good, but trending slower during evening spikes.',
          severity: DashboardQueueSeverity.low,
          route: AppRoutes.adminReports,
        ),
        DashboardHealthCheck(
          title: 'Feedback response readiness',
          statusLabel: '11 unanswered',
          helper: 'Travel-planning UX feedback should be addressed first.',
          severity: DashboardQueueSeverity.high,
          route: AppRoutes.adminFeedback,
        ),
        DashboardHealthCheck(
          title: 'Guide freshness',
          statusLabel: '4 outdated entries',
          helper: 'Transport and wallet app guides need current screenshots.',
          severity: DashboardQueueSeverity.medium,
          route: AppRoutes.adminPopularApps,
        ),
      ],
      quickActions: <DashboardQuickAction>[
        DashboardQuickAction(
          title: 'Review flagged content',
          subtitle: 'Go straight to open moderation cases.',
          route: AppRoutes.adminReports,
        ),
        DashboardQuickAction(
          title: 'Reply to fresh feedback',
          subtitle: 'Prioritize unresolved UX and search comments.',
          route: AppRoutes.adminFeedback,
        ),
        DashboardQuickAction(
          title: 'Audit user accounts',
          subtitle: 'Inspect recent suspicious sign-ups and bans.',
          route: AppRoutes.adminUsers,
        ),
        DashboardQuickAction(
          title: 'Refresh app guides',
          subtitle: 'Update the most-viewed support guides first.',
          route: AppRoutes.adminPopularApps,
        ),
        DashboardQuickAction(
          title: 'Tune food content',
          subtitle: 'Close top search gaps with more food detail entries.',
          route: AppRoutes.adminFood,
        ),
        DashboardQuickAction(
          title: 'Update canned replies',
          subtitle: 'Prepare standard responses for report and feedback flows.',
          route: AppRoutes.adminCannedReplies,
        ),
      ],
    );
  }
}
