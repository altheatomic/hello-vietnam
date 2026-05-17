enum DashboardChangeDirection { up, down, neutral }

enum DashboardMetricKind {
  users,
  moderation,
  feedback,
  content,
  planning,
  search,
  places,
  hotPlaces,
  requests,
  reports,
  adoption,
  revenue,
}

enum DashboardQueueSeverity { critical, high, medium, low }

enum DashboardFeatureUsageRange { month, quarter }

class AdminDashboardSnapshot {
  const AdminDashboardSnapshot({
    required this.generatedAtLabel,
    required this.hero,
    required this.businessMetrics,
    required this.systemMetrics,
    required this.customerDemandTrend,
    required this.newPlacesTrend,
    required this.trendingPlaces,
    required this.growthOpportunities,
    required this.requestBreakdown,
    required this.reportBreakdown,
    required this.userGrowthTrend,
    required this.priorityQueue,
    required this.reportInsights,
    required this.featureUsagePeriods,
    required this.quickActions,
  });

  final String generatedAtLabel;
  final DashboardHero hero;
  final List<DashboardMetric> businessMetrics;
  final List<DashboardMetric> systemMetrics;
  final DashboardTrendPanel customerDemandTrend;
  final DashboardTrendPanel newPlacesTrend;
  final List<DashboardContentSpotlight> trendingPlaces;
  final List<DashboardSearchInsight> growthOpportunities;
  final DashboardBreakdownPanel requestBreakdown;
  final DashboardBreakdownPanel reportBreakdown;
  final DashboardTrendPanel userGrowthTrend;
  final List<DashboardQueueItem> priorityQueue;
  final List<DashboardHealthCheck> reportInsights;
  final List<DashboardFeatureUsagePeriod> featureUsagePeriods;
  final List<DashboardQuickAction> quickActions;
}

class DashboardHero {
  const DashboardHero({
    required this.headline,
    required this.summary,
    required this.primaryCtaLabel,
    this.primaryCtaRoute,
    required this.secondaryCtaLabel,
    this.secondaryCtaRoute,
    required this.highlightStats,
  });

  final String headline;
  final String summary;
  final String primaryCtaLabel;
  final String? primaryCtaRoute;
  final String secondaryCtaLabel;
  final String? secondaryCtaRoute;
  final List<DashboardHeroStat> highlightStats;
}

class DashboardHeroStat {
  const DashboardHeroStat({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;
}

class DashboardMetric {
  const DashboardMetric({
    required this.id,
    required this.title,
    required this.value,
    required this.helper,
    required this.changeLabel,
    required this.changeDirection,
    required this.progress,
    required this.kind,
    this.route,
  });

  final String id;
  final String title;
  final String value;
  final String helper;
  final String changeLabel;
  final DashboardChangeDirection changeDirection;
  final double progress;
  final DashboardMetricKind kind;
  final String? route;
}

class DashboardTrendPanel {
  const DashboardTrendPanel({
    required this.title,
    required this.summary,
    required this.xLabels,
    required this.series,
  });

  final String title;
  final String summary;
  final List<String> xLabels;
  final List<DashboardTrendSeries> series;
}

class DashboardTrendSeries {
  const DashboardTrendSeries({
    required this.label,
    required this.values,
    required this.summaryValue,
  });

  final String label;
  final List<double> values;
  final String summaryValue;
}

class DashboardBreakdownPanel {
  const DashboardBreakdownPanel({
    required this.title,
    required this.summary,
    required this.totalLabel,
    required this.items,
  });

  final String title;
  final String summary;
  final String totalLabel;
  final List<DashboardBreakdownItem> items;
}

class DashboardBreakdownItem {
  const DashboardBreakdownItem({
    required this.label,
    required this.valueLabel,
    required this.count,
    required this.share,
    required this.helper,
    this.severity,
    this.route,
  });

  final String label;
  final String valueLabel;
  final int count;
  final double share;
  final String helper;
  final DashboardQueueSeverity? severity;
  final String? route;
}

class DashboardFeatureUsage {
  const DashboardFeatureUsage({
    required this.feature,
    required this.sessions,
    required this.share,
    required this.helper,
    this.route,
  });

  final String feature;
  final int sessions;
  final double share;
  final String helper;
  final String? route;
}

class DashboardFeatureUsagePeriod {
  const DashboardFeatureUsagePeriod({
    required this.range,
    required this.label,
    required this.helper,
    required this.totalLabel,
    required this.items,
  });

  final DashboardFeatureUsageRange range;
  final String label;
  final String helper;
  final String totalLabel;
  final List<DashboardFeatureUsage> items;
}

class DashboardSearchInsight {
  const DashboardSearchInsight({
    required this.query,
    required this.searches,
    required this.resultRate,
    required this.conversionRate,
    required this.statusLabel,
    this.route,
  });

  final String query;
  final int searches;
  final double resultRate;
  final double conversionRate;
  final String statusLabel;
  final String? route;
}

class DashboardQueueItem {
  const DashboardQueueItem({
    required this.title,
    required this.subtitle,
    required this.countLabel,
    required this.ageLabel,
    required this.severity,
    this.route,
  });

  final String title;
  final String subtitle;
  final String countLabel;
  final String ageLabel;
  final DashboardQueueSeverity severity;
  final String? route;
}

class DashboardContentSpotlight {
  const DashboardContentSpotlight({
    required this.title,
    required this.typeLabel,
    required this.viewsLabel,
    required this.saveRateLabel,
    required this.qualityLabel,
    this.route,
  });

  final String title;
  final String typeLabel;
  final String viewsLabel;
  final String saveRateLabel;
  final String qualityLabel;
  final String? route;
}

class DashboardHealthCheck {
  const DashboardHealthCheck({
    required this.title,
    required this.statusLabel,
    required this.helper,
    required this.severity,
    this.route,
  });

  final String title;
  final String statusLabel;
  final String helper;
  final DashboardQueueSeverity severity;
  final String? route;
}

class DashboardQuickAction {
  const DashboardQuickAction({
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String route;
}
