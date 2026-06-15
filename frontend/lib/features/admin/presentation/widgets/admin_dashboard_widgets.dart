import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/features/admin/domain/admin_dashboard_models.dart';
import 'package:hellovietnam/features/admin/presentation/widgets/admin_section_header.dart';

class AdminDashboardOverview extends StatelessWidget {
  const AdminDashboardOverview({
    super.key,
    required this.snapshot,
    required this.onRefresh,
    this.isRefreshing = false,
  });

  final AdminDashboardSnapshot snapshot;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 240 - 48;
    final compact = width < 920;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AdminSectionHeader(
          title: 'Dashboard',
          subtitle:
              'Business growth signals and system operations are separated so each admin role can focus on the right decisions.',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _StatusChip(
                icon: Icons.schedule_rounded,
                label: snapshot.generatedAtLabel,
              ),
              FilledButton.icon(
                onPressed: isRefreshing ? null : onRefresh,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.buttonRadius,
                    ),
                  ),
                ),
                icon: isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isRefreshing ? 'Refreshing' : 'Refresh'),
              ),
            ],
          ),
        ),
        _HeroPanel(hero: snapshot.hero),
        const SizedBox(height: 28),
        const _AdminAreaHeader(
          icon: Icons.business_center_rounded,
          title: 'Admin - Business Operations',
          subtitle:
              'Track new places, trending destinations, user demand, and growth signals that should guide system development priorities.',
        ),
        const SizedBox(height: 16),
        _MetricsGrid(metrics: snapshot.businessMetrics),
        const SizedBox(height: 22),
        _ResponsivePair(
          leftFlex: 8,
          rightFlex: 7,
          compact: compact,
          left: _UsageTrendCard(panel: snapshot.customerDemandTrend),
          right: _UsageTrendCard(panel: snapshot.newPlacesTrend),
        ),
        const SizedBox(height: 22),
        _ResponsivePair(
          leftFlex: 8,
          rightFlex: 7,
          compact: compact,
          left: _ContentSpotlightCard(
            title: 'Hot And Trending Places',
            subtitle:
                'Places where users are concentrating attention through searches, views, saves, and planner handoffs.',
            items: snapshot.trendingPlaces,
          ),
          right: _SearchInsightsCard(
            title: 'Growth Opportunity Signals',
            subtitle:
                'Demand clusters where adding content, guides, or promotion can lift customer acquisition and conversion.',
            items: snapshot.growthOpportunities,
          ),
        ),
        const SizedBox(height: 30),
        const _AdminAreaHeader(
          icon: Icons.settings_suggest_rounded,
          title: 'Admin - System Management',
          subtitle:
              'Monitor pending requests and tasks, reports, user volume, operational health, and feature adoption across the system.',
        ),
        const SizedBox(height: 16),
        _MetricsGrid(metrics: snapshot.systemMetrics),
        const SizedBox(height: 22),
        _ResponsivePair(
          leftFlex: 7,
          rightFlex: 7,
          compact: compact,
          left: _BreakdownChartCard(panel: snapshot.requestBreakdown),
          right: _BreakdownChartCard(panel: snapshot.reportBreakdown),
        ),
        const SizedBox(height: 22),
        _ResponsivePair(
          leftFlex: 8,
          rightFlex: 5,
          compact: compact,
          left: _UsageTrendCard(panel: snapshot.userGrowthTrend),
          right: _FeatureUsageCard(periods: snapshot.featureUsagePeriods),
        ),
        const SizedBox(height: 22),
        _ResponsivePair(
          leftFlex: 8,
          rightFlex: 5,
          compact: compact,
          left: _PriorityQueueCard(items: snapshot.priorityQueue),
          right: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _HealthChecksCard(
                title: 'Reports And System Signals',
                subtitle:
                    'Current report volume, request issues, user growth, and response-time health.',
                items: snapshot.reportInsights,
              ),
              const SizedBox(height: 24),
              _QuickActionsCard(items: snapshot.quickActions),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminAreaHeader extends StatelessWidget {
  const _AdminAreaHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.left,
    required this.right,
    required this.compact,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final Widget left;
  final Widget right;
  final bool compact;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: <Widget>[left, const SizedBox(height: 24), right],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: leftFlex, child: left),
        const SizedBox(width: 24),
        Expanded(flex: rightFlex, child: right),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppColors.surface : null,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.18),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.hero});

  final DashboardHero hero;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF102A43),
          Color(0xFF163A63),
          Color(0xFF1B6CA8),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final statWidgets = hero.highlightStats
              .map((stat) => Expanded(child: _HeroStatTile(stat: stat)))
              .toList();

          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Today\'s Control Center',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hero.headline,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                hero.summary,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.white.withValues(alpha: 0.86),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _HeroActionButton(
                    label: hero.primaryCtaLabel,
                    route: hero.primaryCtaRoute,
                    filled: true,
                  ),
                  _HeroActionButton(
                    label: hero.secondaryCtaLabel,
                    route: hero.secondaryCtaRoute,
                    filled: false,
                  ),
                ],
              ),
            ],
          );

          final stats = Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: compact
                ? Column(
                    children: hero.highlightStats
                        .map(
                          (stat) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _HeroStatTile(stat: stat),
                          ),
                        )
                        .toList(),
                  )
                : Row(children: statWidgets),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[info, const SizedBox(height: 20), stats],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 7, child: info),
              const SizedBox(width: 20),
              Expanded(flex: 6, child: stats),
            ],
          );
        },
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.label,
    required this.route,
    required this.filled,
  });

  final String label;
  final String? route;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_rounded, size: 16),
      ],
    );

    if (filled) {
      return FilledButton(
        onPressed: route == null ? null : () => context.go(route!),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF163A63),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          ),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: route == null ? null : () => context.go(route!),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        ),
      ),
      child: child,
    );
  }
}

class _HeroStatTile extends StatelessWidget {
  const _HeroStatTile({required this.stat});

  final DashboardHeroStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            stat.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            stat.value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stat.helper,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 18,
      children: metrics
          .map(
            (metric) =>
                SizedBox(width: 250, child: _MetricCard(metric: metric)),
          )
          .toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final palette = _metricPalette(metric.kind);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: metric.route == null ? null : () => context.go(metric.route!),
        borderRadius: BorderRadius.circular(24),
        child: _DashboardCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.$1.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(palette.$3, color: palette.$1, size: 22),
                  ),
                  const Spacer(),
                  _ChangeBadge(
                    label: metric.changeLabel,
                    direction: metric.changeDirection,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                metric.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                metric.value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                metric.helper,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: metric.progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: palette.$2,
                  valueColor: AlwaysStoppedAnimation<Color>(palette.$1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.label, required this.direction});

  final String label;
  final DashboardChangeDirection direction;

  @override
  Widget build(BuildContext context) {
    final color = switch (direction) {
      DashboardChangeDirection.up => const Color(0xFF1F9D72),
      DashboardChangeDirection.down => const Color(0xFFD64545),
      DashboardChangeDirection.neutral => const Color(0xFF6B7280),
    };
    final icon = switch (direction) {
      DashboardChangeDirection.up => Icons.trending_up_rounded,
      DashboardChangeDirection.down => Icons.trending_down_rounded,
      DashboardChangeDirection.neutral => Icons.remove_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageTrendCard extends StatelessWidget {
  const _UsageTrendCard({required this.panel});

  final DashboardTrendPanel panel;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHead(title: panel.title, subtitle: panel.summary),
          const SizedBox(height: 16),
          SizedBox(height: 280, child: _MultiSeriesTrendChart(panel: panel)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List<Widget>.generate(panel.series.length, (int index) {
              final palette = _chartPalette[index % _chartPalette.length];
              final series = panel.series[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: palette,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      series.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      series.summaryValue,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BreakdownChartCard extends StatelessWidget {
  const _BreakdownChartCard({required this.panel});

  final DashboardBreakdownPanel panel;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHead(title: panel.title, subtitle: panel.summary),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CustomPaint(
                  size: const Size.square(190),
                  painter: _BreakdownDonutChartPainter(items: panel.items),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      panel.totalLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...List<Widget>.generate(panel.items.length, (int index) {
            final item = panel.items[index];
            final color = item.severity == null
                ? _chartPalette[index % _chartPalette.length]
                : _severityTone(item.severity!).$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BreakdownRow(item: item, color: color),
            );
          }),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.item, required this.color});

  final DashboardBreakdownItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.valueLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: item.share.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: color.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(item.share * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            item.helper,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );

    if (item.route == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route!),
        borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.all(6), child: content),
      ),
    );
  }
}

class _FeatureUsageCard extends StatefulWidget {
  const _FeatureUsageCard({required this.periods});

  final List<DashboardFeatureUsagePeriod> periods;

  @override
  State<_FeatureUsageCard> createState() => _FeatureUsageCardState();
}

class _FeatureUsageCardState extends State<_FeatureUsageCard> {
  DashboardFeatureUsageRange _selectedRange = DashboardFeatureUsageRange.month;

  DashboardFeatureUsagePeriod get _selectedPeriod {
    if (widget.periods.isEmpty) {
      return const DashboardFeatureUsagePeriod(
        range: DashboardFeatureUsageRange.month,
        label: '1 Month',
        helper: 'No feature adoption data is available.',
        totalLabel: '0 sessions',
        items: <DashboardFeatureUsage>[],
      );
    }

    return widget.periods.firstWhere(
      (period) => period.range == _selectedRange,
      orElse: () => widget.periods.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = _selectedPeriod;
    final items = period.items;
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionHead(
            title: 'Feature Adoption',
            subtitle:
                'Switch between monthly and quarterly adoption to understand what users keep coming back to.',
          ),
          const SizedBox(height: 14),
          SegmentedButton<DashboardFeatureUsageRange>(
            showSelectedIcon: false,
            segments: widget.periods
                .map(
                  (period) => ButtonSegment<DashboardFeatureUsageRange>(
                    value: period.range,
                    label: Text(period.label),
                  ),
                )
                .toList(),
            selected: <DashboardFeatureUsageRange>{period.range},
            onSelectionChanged: (ranges) {
              setState(() => _selectedRange = ranges.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            period.helper,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CustomPaint(
                  size: const Size.square(220),
                  painter: _DonutChartPainter(items: items),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      period.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      period.totalLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...List<Widget>.generate(items.length, (int index) {
            final item = items[index];
            final color = _chartPalette[index % _chartPalette.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FeatureUsageRow(item: item, color: color),
            );
          }),
        ],
      ),
    );
  }
}

class _FeatureUsageRow extends StatelessWidget {
  const _FeatureUsageRow({required this.item, required this.color});

  final DashboardFeatureUsage item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.feature,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${(item.share * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: item.share,
                  minHeight: 8,
                  backgroundColor: color.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              item.sessions.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            item.helper,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );

    if (item.route == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route!),
        borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.all(6), child: content),
      ),
    );
  }
}

class _SearchInsightsCard extends StatelessWidget {
  const _SearchInsightsCard({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<DashboardSearchInsight> items;

  @override
  Widget build(BuildContext context) {
    final maxSearches = items.fold<int>(
      1,
      (maxValue, item) => math.max(maxValue, item.searches),
    );

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHead(title: title, subtitle: subtitle),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _SearchInsightRow(item: item, maxSearches: maxSearches),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchInsightRow extends StatelessWidget {
  const _SearchInsightRow({required this.item, required this.maxSearches});

  final DashboardSearchInsight item;
  final int maxSearches;

  @override
  Widget build(BuildContext context) {
    final barValue = item.searches / maxSearches;
    final resultColor = item.resultRate >= 0.9
        ? const Color(0xFF1F9D72)
        : item.resultRate >= 0.75
        ? const Color(0xFFDAA520)
        : const Color(0xFFD64545);

    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.query,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: <Widget>[
                      _MetaPill(label: '${item.searches} searches'),
                      _MetaPill(
                        label:
                            '${(item.resultRate * 100).toStringAsFixed(0)}% result rate',
                        color: resultColor,
                      ),
                      _MetaPill(
                        label:
                            '${(item.conversionRate * 100).toStringAsFixed(0)}% conversion',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _StatePill(label: item.statusLabel, color: resultColor),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: barValue,
            minHeight: 9,
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.16),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );

    if (item.route == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route!),
        borderRadius: BorderRadius.circular(18),
        child: Padding(padding: const EdgeInsets.all(8), child: card),
      ),
    );
  }
}

class _PriorityQueueCard extends StatelessWidget {
  const _PriorityQueueCard({required this.items});

  final List<DashboardQueueItem> items;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionHead(
            title: 'Request And Task Queue',
            subtitle:
                'Pending requests, reports, account reviews, and guide refresh tasks ordered by urgency.',
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _QueueItemTile(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueItemTile extends StatelessWidget {
  const _QueueItemTile({required this.item});

  final DashboardQueueItem item;

  @override
  Widget build(BuildContext context) {
    final tone = _severityTone(item.severity);
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.$2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.$1.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _StatePill(label: item.countLabel, color: tone.$1),
              const Spacer(),
              Text(
                item.ageLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    if (item.route == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route!),
        borderRadius: BorderRadius.circular(20),
        child: content,
      ),
    );
  }
}

class _ContentSpotlightCard extends StatelessWidget {
  const _ContentSpotlightCard({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<DashboardContentSpotlight> items;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHead(title: title, subtitle: subtitle),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ContentSpotlightRow(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentSpotlightRow extends StatelessWidget {
  const _ContentSpotlightRow({required this.item});

  final DashboardContentSpotlight item;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF7FD3F9), Color(0xFF52B8F4)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    _MetaPill(label: item.typeLabel),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: <Widget>[
                    _MetaPill(label: item.viewsLabel),
                    _MetaPill(label: item.saveRateLabel),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.qualityLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (item.route != null) ...<Widget>[
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => context.go(item.route!),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.16),
              ),
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ],
      ),
    );

    if (item.route == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route!),
        borderRadius: BorderRadius.circular(20),
        child: content,
      ),
    );
  }
}

class _HealthChecksCard extends StatelessWidget {
  const _HealthChecksCard({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<DashboardHealthCheck> items;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHead(title: title, subtitle: subtitle),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _HealthCheckRow(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthCheckRow extends StatelessWidget {
  const _HealthCheckRow({required this.item});

  final DashboardHealthCheck item;

  @override
  Widget build(BuildContext context) {
    final tone = _severityTone(item.severity);

    final row = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.$2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.$1.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_severityIcon(item.severity), color: tone.$1, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.helper,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatePill(label: item.statusLabel, color: tone.$1),
        ],
      ),
    );

    if (item.route == null) {
      return row;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(item.route!),
        borderRadius: BorderRadius.circular(18),
        child: row,
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.items});

  final List<DashboardQuickAction> items;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionHead(
            title: 'Quick Actions',
            subtitle:
                'Shortcuts into the admin flows most likely to matter after you read the dashboard.',
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                onPressed: () => context.go(item.route),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: AppColors.primaryLight.withValues(alpha: 0.22),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_outward_rounded,
                        color: AppColors.primaryDark,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.color = AppColors.primaryDark});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _MultiSeriesTrendChart extends StatelessWidget {
  const _MultiSeriesTrendChart({required this.panel});

  final DashboardTrendPanel panel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _MultiSeriesTrendPainter(panel: panel),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
                child: Column(
                  children: <Widget>[
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: panel.xLabels
                          .map(
                            (label) => Text(
                              label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MultiSeriesTrendPainter extends CustomPainter {
  const _MultiSeriesTrendPainter({required this.panel});

  final DashboardTrendPanel panel;

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPad = 10;
    const double rightPad = 10;
    const double topPad = 12;
    const double bottomPad = 34;
    final chartRect = Rect.fromLTWH(
      leftPad,
      topPad,
      size.width - leftPad - rightPad,
      size.height - topPad - bottomPad,
    );

    final gridPaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.18)
      ..strokeWidth = 1;

    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = chartRect.top + (chartRect.height / gridLines) * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final allValues = panel.series.expand((series) => series.values);
    final maxValue = allValues.reduce(math.max);
    final minValue = allValues.reduce(math.min);
    final valueSpan = math.max(1.0, maxValue - minValue);

    for (
      int seriesIndex = 0;
      seriesIndex < panel.series.length;
      seriesIndex++
    ) {
      final series = panel.series[seriesIndex];
      final color = _chartPalette[seriesIndex % _chartPalette.length];

      final points = <Offset>[];
      for (int i = 0; i < series.values.length; i++) {
        final x =
            chartRect.left + (chartRect.width / (series.values.length - 1)) * i;
        final normalized = (series.values[i] - minValue) / valueSpan;
        final y = chartRect.bottom - (normalized * chartRect.height);
        points.add(Offset(x, y));
      }

      if (seriesIndex == 0 && points.isNotEmpty) {
        final fillPath = Path()
          ..moveTo(points.first.dx, chartRect.bottom)
          ..lineTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          final previous = points[i - 1];
          final current = points[i];
          final control = Offset((previous.dx + current.dx) / 2, previous.dy);
          final control2 = Offset((previous.dx + current.dx) / 2, current.dy);
          fillPath.cubicTo(
            control.dx,
            control.dy,
            control2.dx,
            control2.dy,
            current.dx,
            current.dy,
          );
        }
        fillPath
          ..lineTo(points.last.dx, chartRect.bottom)
          ..close();

        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                color.withValues(alpha: 0.26),
                color.withValues(alpha: 0.02),
              ],
            ).createShader(chartRect),
        );
      }

      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final previous = points[i - 1];
        final current = points[i];
        final control = Offset((previous.dx + current.dx) / 2, previous.dy);
        final control2 = Offset((previous.dx + current.dx) / 2, current.dy);
        linePath.cubicTo(
          control.dx,
          control.dy,
          control2.dx,
          control2.dy,
          current.dx,
          current.dy,
        );
      }

      canvas.drawPath(
        linePath,
        Paint()
          ..color = color
          ..strokeWidth = seriesIndex == 0 ? 3.6 : 2.4
          ..style = PaintingStyle.stroke,
      );

      for (final point in points) {
        canvas.drawCircle(
          point,
          seriesIndex == 0 ? 4.2 : 3.2,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          point,
          seriesIndex == 0 ? 2.6 : 2.0,
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MultiSeriesTrendPainter oldDelegate) =>
      oldDelegate.panel != panel;
}

class _BreakdownDonutChartPainter extends CustomPainter {
  const _BreakdownDonutChartPainter({required this.items});

  final List<DashboardBreakdownItem> items;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2 - 16);
    const startAngle = -math.pi / 2;
    final total = items.fold<double>(0, (sum, item) => sum + item.share);

    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = AppColors.primaryLight.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 22,
      );
      canvas.drawCircle(
        center,
        size.width / 2 - 40,
        Paint()..color = Colors.white,
      );
      return;
    }

    var currentAngle = startAngle;
    for (int index = 0; index < items.length; index++) {
      final item = items[index];
      final sweep = (item.share / total) * (math.pi * 2);
      final color = item.severity == null
          ? _chartPalette[index % _chartPalette.length]
          : _severityTone(item.severity!).$1;

      canvas.drawArc(
        rect,
        currentAngle,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 22,
      );

      currentAngle += sweep + 0.03;
    }

    canvas.drawCircle(
      center,
      size.width / 2 - 40,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _BreakdownDonutChartPainter oldDelegate) =>
      oldDelegate.items != items;
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({required this.items});

  final List<DashboardFeatureUsage> items;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2 - 16);
    const startAngle = -math.pi / 2;
    final total = items.fold<double>(0, (sum, item) => sum + item.share);
    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = AppColors.primaryLight.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 24,
      );
      canvas.drawCircle(
        center,
        size.width / 2 - 42,
        Paint()..color = Colors.white,
      );
      return;
    }

    var currentAngle = startAngle;
    for (int index = 0; index < items.length; index++) {
      final item = items[index];
      final sweep = (item.share / total) * (math.pi * 2);
      final color = _chartPalette[index % _chartPalette.length];

      canvas.drawArc(
        rect,
        currentAngle,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 24,
      );

      currentAngle += sweep + 0.03;
    }

    canvas.drawCircle(
      center,
      size.width / 2 - 42,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.items != items;
}

(Color, Color, IconData) _metricPalette(DashboardMetricKind kind) {
  return switch (kind) {
    DashboardMetricKind.users => (
      const Color(0xFF2F80ED),
      const Color(0xFFEAF3FF),
      Icons.people_alt_rounded,
    ),
    DashboardMetricKind.moderation => (
      const Color(0xFFD64545),
      const Color(0xFFFFEFEF),
      Icons.flag_rounded,
    ),
    DashboardMetricKind.feedback => (
      const Color(0xFF8B5CF6),
      const Color(0xFFF3EEFF),
      Icons.mark_chat_unread_rounded,
    ),
    DashboardMetricKind.content => (
      const Color(0xFF0E9F6E),
      const Color(0xFFE8FBF4),
      Icons.restaurant_menu_rounded,
    ),
    DashboardMetricKind.planning => (
      const Color(0xFFF2994A),
      const Color(0xFFFFF3E8),
      Icons.map_rounded,
    ),
    DashboardMetricKind.search => (
      const Color(0xFF1C9AB7),
      const Color(0xFFE8F9FD),
      Icons.travel_explore_rounded,
    ),
    DashboardMetricKind.places => (
      const Color(0xFF0E9F6E),
      const Color(0xFFE8FBF4),
      Icons.add_location_alt_rounded,
    ),
    DashboardMetricKind.hotPlaces => (
      const Color(0xFFE11D48),
      const Color(0xFFFFEEF3),
      Icons.local_fire_department_rounded,
    ),
    DashboardMetricKind.requests => (
      const Color(0xFFF2994A),
      const Color(0xFFFFF3E8),
      Icons.pending_actions_rounded,
    ),
    DashboardMetricKind.reports => (
      const Color(0xFFD64545),
      const Color(0xFFFFEFEF),
      Icons.report_rounded,
    ),
    DashboardMetricKind.adoption => (
      const Color(0xFF8B5CF6),
      const Color(0xFFF3EEFF),
      Icons.insights_rounded,
    ),
    DashboardMetricKind.revenue => (
      const Color(0xFFB7791F),
      const Color(0xFFFFF8E7),
      Icons.trending_up_rounded,
    ),
  };
}

(Color, Color) _severityTone(DashboardQueueSeverity severity) {
  return switch (severity) {
    DashboardQueueSeverity.critical => (
      const Color(0xFFD64545),
      const Color(0xFFFFF1F1),
    ),
    DashboardQueueSeverity.high => (
      const Color(0xFFE67E22),
      const Color(0xFFFFF4EA),
    ),
    DashboardQueueSeverity.medium => (
      const Color(0xFFB7791F),
      const Color(0xFFFFF8E7),
    ),
    DashboardQueueSeverity.low => (
      const Color(0xFF1F9D72),
      const Color(0xFFEAFBF4),
    ),
  };
}

IconData _severityIcon(DashboardQueueSeverity severity) {
  return switch (severity) {
    DashboardQueueSeverity.critical => Icons.priority_high_rounded,
    DashboardQueueSeverity.high => Icons.report_gmailerrorred_rounded,
    DashboardQueueSeverity.medium => Icons.schedule_rounded,
    DashboardQueueSeverity.low => Icons.check_circle_outline_rounded,
  };
}

const List<Color> _chartPalette = <Color>[
  Color(0xFF3B82F6),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
  Color(0xFF14B8A6),
];
