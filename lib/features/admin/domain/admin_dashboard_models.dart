enum DashboardChangeDirection { up, down, neutral }

enum DashboardMetricKind {
  users,
  moderation,
  feedback,
  content,
  planning,
  search,
}

enum DashboardQueueSeverity { critical, high, medium, low }

class AdminDashboardSnapshot {
  const AdminDashboardSnapshot({
    required this.generatedAtLabel,
    required this.hero,
    required this.metrics,
    required this.usageTrend,
    required this.featureUsage,
    required this.searchInsights,
    required this.priorityQueue,
    required this.contentSpotlights,
    required this.healthChecks,
    required this.quickActions,
  });

  final String generatedAtLabel;
  final DashboardHero hero;
  final List<DashboardMetric> metrics;
  final DashboardTrendPanel usageTrend;
  final List<DashboardFeatureUsage> featureUsage;
  final List<DashboardSearchInsight> searchInsights;
  final List<DashboardQueueItem> priorityQueue;
  final List<DashboardContentSpotlight> contentSpotlights;
  final List<DashboardHealthCheck> healthChecks;
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
