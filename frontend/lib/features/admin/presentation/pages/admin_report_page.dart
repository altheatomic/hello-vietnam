import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';

import '../widgets/admin_section_header.dart';

class AdminReportPage extends StatefulWidget {
  const AdminReportPage({super.key});

  @override
  State<AdminReportPage> createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  late final List<_ReportItem> _reports = _seedReports.map((e) => e).toList();
  final TextEditingController _searchController = TextEditingController();

  _IssueType? _issueFilter;
  _ReportStatus? _statusFilter;
  int _currentPage = 1;

  static const int _pageSize = 8;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ReportItem> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    return _reports.where((r) {
      final matchQuery =
          q.isEmpty ||
          r.id.toLowerCase().contains(q) ||
          r.reporterName.toLowerCase().contains(q) ||
          r.reporterEmail.toLowerCase().contains(q) ||
          r.target.toLowerCase().contains(q);
      final matchIssue = _issueFilter == null || r.issue == _issueFilter;
      final matchStatus = _statusFilter == null || r.status == _statusFilter;
      return matchQuery && matchIssue && matchStatus;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<_ReportItem> get _paged {
    final all = _filtered;
    final start = (_currentPage - 1) * _pageSize;
    final end = min(start + _pageSize, all.length);
    if (start >= all.length) return [];
    return all.sublist(start, end);
  }

  int get _totalPages =>
      (_filtered.length / _pageSize).ceil().clamp(1, 9999).toInt();

  int _count(_ReportStatus status) =>
      _reports.where((e) => e.status == status).length;

  void _onSearchChanged(String _) => setState(() => _currentPage = 1);

  void _onIssueChanged(_IssueType? value) => setState(() {
    _issueFilter = value;
    _currentPage = 1;
  });

  void _onStatusChanged(_ReportStatus? value) => setState(() {
    _statusFilter = value;
    _currentPage = 1;
  });

  Future<void> _onReview(_ReportItem item) async {
    final action = await showDialog<_ReviewAction>(
      context: context,
      barrierColor: const Color(0x80152B43),
      builder: (_) => _ReportReviewDialog(item: item),
    );
    if (action == null || !mounted) return;

    final nextStatus = switch (action) {
      _ReviewAction.dismiss => _ReportStatus.dismissed,
      _ReviewAction.resolve => _ReportStatus.resolved,
      _ReviewAction.inProgress => _ReportStatus.inProgress,
      _ReviewAction.forward => _ReportStatus.inProgress,
      _ReviewAction.requestInfo => _ReportStatus.inProgress,
      _ReviewAction.hideContent => _ReportStatus.resolved,
      _ReviewAction.deleteContent => _ReportStatus.resolved,
    };

    setState(() {
      final idx = _reports.indexWhere((e) => e.id == item.id);
      if (idx != -1) _reports[idx] = _reports[idx].copyWith(status: nextStatus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final paged = _paged;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminSectionHeader(
                title: 'Report Management',
                subtitle: 'Review and manage user-submitted issues.',
              ),
              _ReportStats(
                total: _reports.length,
                pending: _count(_ReportStatus.pending),
                inProgress: _count(_ReportStatus.inProgress),
                resolved: _count(_ReportStatus.resolved),
                dismissed: _count(_ReportStatus.dismissed),
              ),
              const SizedBox(height: 14),
              _ReportContentCard(
                filterBar: _ReportFilterBar(
                  controller: _searchController,
                  issueFilter: _issueFilter,
                  statusFilter: _statusFilter,
                  onSearchChanged: _onSearchChanged,
                  onIssueChanged: _onIssueChanged,
                  onStatusChanged: _onStatusChanged,
                ),
                child: filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: EmptyState(
                          icon: Icons.flag_outlined,
                          message: 'No reports match your search.',
                        ),
                      )
                    : Column(
                        children: [
                          _ReportTable(reports: paged, onReview: _onReview),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            child: _TableFooter(
                              currentPage: _currentPage,
                              totalPages: _totalPages,
                              totalItems: filtered.length,
                              pageSize: _pageSize,
                              onPageChanged: (p) =>
                                  setState(() => _currentPage = p),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportContentCard extends StatelessWidget {
  const _ReportContentCard({required this.filterBar, required this.child});

  final Widget filterBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: filterBar,
          ),
          Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.9)),
          child,
        ],
      ),
    );
  }
}

class _ReportFilterBar extends StatelessWidget {
  const _ReportFilterBar({
    required this.controller,
    required this.issueFilter,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onIssueChanged,
    required this.onStatusChanged,
  });

  final TextEditingController controller;
  final _IssueType? issueFilter;
  final _ReportStatus? statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_IssueType?> onIssueChanged;
  final ValueChanged<_ReportStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1080;

        final search = _SearchPill(
          controller: controller,
          onChanged: onSearchChanged,
          width: compact ? constraints.maxWidth : 360,
        );

        final issue = _DropdownPill<_IssueType>(
          width: compact ? constraints.maxWidth : 180,
          allLabel: 'All Issue Types',
          selected: issueFilter,
          values: _IssueType.values,
          labelOf: (v) => v.label,
          onChanged: onIssueChanged,
          leadingIcon: Icons.filter_list_rounded,
        );

        final status = _DropdownPill<_ReportStatus>(
          width: compact ? constraints.maxWidth : 170,
          allLabel: 'All Statuses',
          selected: statusFilter,
          values: _ReportStatus.values,
          labelOf: (v) => v.label,
          onChanged: onStatusChanged,
        );

        if (compact) {
          return Column(
            children: [
              search,
              const SizedBox(height: 10),
              issue,
              const SizedBox(height: 10),
              status,
            ],
          );
        }

        return Row(
          children: [
            search,
            const Spacer(),
            issue,
            const SizedBox(width: 10),
            status,
          ],
        );
      },
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({
    required this.controller,
    required this.onChanged,
    required this.width,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(45),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search reports by ID, Name...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 19,
            color: AppColors.textSecondary,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
        ),
      ),
    );
  }
}

class _DropdownPill<T> extends StatelessWidget {
  const _DropdownPill({
    required this.width,
    required this.allLabel,
    required this.selected,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    this.leadingIcon,
  });

  final double width;
  final String allLabel;
  final T? selected;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    const dropdownTextColor = Color(0xFF374151);

    return Container(
      width: width,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: selected,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 4,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(
            fontSize: 14,
            color: dropdownTextColor,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
          items: [
            DropdownMenuItem<T?>(
              value: null,
              child: Row(
                children: [
                  if (leadingIcon != null)
                    Icon(leadingIcon, size: 16, color: AppColors.textSecondary),
                  if (leadingIcon != null) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      allLabel,
                      style: const TextStyle(
                        color: dropdownTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...values.map(
              (v) => DropdownMenuItem<T?>(
                value: v,
                child: Text(
                  labelOf(v),
                  style: const TextStyle(
                    color: dropdownTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
          onChanged: onChanged,
          selectedItemBuilder: (context) {
            return [
              Row(
                children: [
                  if (leadingIcon != null)
                    Icon(leadingIcon, size: 16, color: AppColors.textSecondary),
                  if (leadingIcon != null) const SizedBox(width: 8),
                  Text(
                    allLabel,
                    style: const TextStyle(
                      color: dropdownTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              ...values.map(
                (v) => Text(
                  labelOf(v),
                  style: const TextStyle(
                    color: dropdownTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ];
          },
        ),
      ),
    );
  }
}

class _ReportStats extends StatelessWidget {
  const _ReportStats({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.resolved,
    required this.dismissed,
  });

  final int total;
  final int pending;
  final int inProgress;
  final int resolved;
  final int dismissed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1280
            ? 5
            : width >= 980
            ? 3
            : width >= 620
            ? 2
            : 1;
        const spacing = 12.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _StatCard(
              width: cardWidth,
              title: 'Total Reports',
              value: total,
              icon: Icons.description_outlined,
              tint: const Color(0xFF4F46E5),
            ),
            _StatCard(
              width: cardWidth,
              title: 'Pending',
              value: pending,
              icon: Icons.warning_amber_rounded,
              tint: const Color(0xFFD97706),
            ),
            _StatCard(
              width: cardWidth,
              title: 'In Progress',
              value: inProgress,
              icon: Icons.schedule_rounded,
              tint: const Color(0xFF2563EB),
            ),
            _StatCard(
              width: cardWidth,
              title: 'Resolved',
              value: resolved,
              icon: Icons.check_circle_outline_rounded,
              tint: const Color(0xFF16A34A),
            ),
            _StatCard(
              width: cardWidth,
              title: 'Dismissed',
              value: dismissed,
              icon: Icons.highlight_off_rounded,
              tint: const Color(0xFF64748B),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final double width;
  final String title;
  final int value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 22, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1,
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

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.reports, required this.onReview});

  final List<_ReportItem> reports;
  final ValueChanged<_ReportItem> onReview;

  static const double _colGap = 12;
  static const double _gapTargetCategory = 8;
  static const double _gapCategoryDate = 8;
  static const double _gapStatusActions = 6;
  static const double _horizontalPadding = 24;
  static const double _minTableWidth = 980;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider.withValues(alpha: 0.9)),
          bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.9)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = max(constraints.maxWidth, _minTableWidth);
          final totalGapWidth =
              (_colGap * 4) +
              _gapTargetCategory +
              _gapCategoryDate +
              _gapStatusActions;
          final contentWidth =
              tableWidth - (_horizontalPadding * 2) - totalGapWidth;
          final colId = contentWidth * 0.09;
          final colReporter = contentWidth * 0.16;
          final colIssue = contentWidth * 0.16;
          final colTarget = contentWidth * 0.18;
          final colCategory = contentWidth * 0.10;
          final colDate = contentWidth * 0.10;
          final colStatus = contentWidth * 0.12;
          final colActions = contentWidth * 0.09;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    height: 46,
                    width: double.infinity,
                    color: AppColors.primaryLight.withValues(alpha: 0.13),
                    padding: const EdgeInsets.symmetric(
                      horizontal: _horizontalPadding,
                    ),
                    child: Row(
                      children: [
                        _Cell(
                          width: colId,
                          child: Text('Report ID', style: headerStyle),
                        ),
                        const SizedBox(width: _colGap),
                        _Cell(
                          width: colReporter,
                          child: Text('Reporter', style: headerStyle),
                        ),
                        const SizedBox(width: _colGap),
                        _Cell(
                          width: colIssue,
                          child: Text('Issue Type', style: headerStyle),
                        ),
                        const SizedBox(width: _colGap),
                        _Cell(
                          width: colTarget,
                          child: Text('Affected Item', style: headerStyle),
                        ),
                        const SizedBox(width: _gapTargetCategory),
                        _Cell(
                          width: colCategory,
                          child: Text('Category', style: headerStyle),
                        ),
                        const SizedBox(width: _gapCategoryDate),
                        _Cell(
                          width: colDate,
                          child: Text('Date', style: headerStyle),
                        ),
                        const SizedBox(width: _colGap),
                        _Cell(
                          width: colStatus,
                          child: Text('Status', style: headerStyle),
                        ),
                        const SizedBox(width: _gapStatusActions),
                        _Cell(
                          width: colActions,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text('Actions', style: headerStyle),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(
                    reports.length,
                    (index) => _ReportRow(
                      item: reports[index],
                      isLast: index == reports.length - 1,
                      colId: colId,
                      colReporter: colReporter,
                      colIssue: colIssue,
                      colTarget: colTarget,
                      colCategory: colCategory,
                      colDate: colDate,
                      colStatus: colStatus,
                      colActions: colActions,
                      colGap: _colGap,
                      horizontalPadding: _horizontalPadding,
                      onReview: () => onReview(reports[index]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportRow extends StatefulWidget {
  const _ReportRow({
    required this.item,
    required this.isLast,
    required this.colId,
    required this.colReporter,
    required this.colIssue,
    required this.colTarget,
    required this.colCategory,
    required this.colDate,
    required this.colStatus,
    required this.colActions,
    required this.colGap,
    required this.horizontalPadding,
    required this.onReview,
  });

  final _ReportItem item;
  final bool isLast;
  final double colId;
  final double colReporter;
  final double colIssue;
  final double colTarget;
  final double colCategory;
  final double colDate;
  final double colStatus;
  final double colActions;
  final double colGap;
  final double horizontalPadding;
  final VoidCallback onReview;

  @override
  State<_ReportRow> createState() => _ReportRowState();
}

class _ReportRowState extends State<_ReportRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.defaultAnimation,
        height: 62,
        padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.primaryLight.withValues(alpha: 0.06)
              : AppColors.surface,
          border: widget.isLast
              ? null
              : Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            _Cell(
              width: widget.colId,
              child: Text(
                item.id,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(width: widget.colGap),
            _Cell(
              width: widget.colReporter,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.reporterName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    item.reporterEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: widget.colGap),
            _Cell(
              width: widget.colIssue,
              child: Row(
                children: [
                  Icon(item.issue.icon, size: 16, color: item.issue.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.issue.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: widget.colGap),
            _Cell(
              width: widget.colTarget,
              child: Text(
                item.target,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: _ReportTable._gapTargetCategory),
            _Cell(
              width: widget.colCategory,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _CategoryBadge(category: item.category),
              ),
            ),
            const SizedBox(width: _ReportTable._gapCategoryDate),
            _Cell(
              width: widget.colDate,
              child: Text(
                _formatDate(item.createdAt),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(width: widget.colGap),
            _Cell(
              width: widget.colStatus,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TableStatusBadge(status: item.status),
              ),
            ),
            const SizedBox(width: _ReportTable._gapStatusActions),
            _Cell(
              width: widget.colActions,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.onReview,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    minimumSize: const Size(82, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Review'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final _Category category;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Align(
        alignment: Alignment.center,
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          category.label,
          textAlign: TextAlign.center,
          strutStyle: const StrutStyle(
            height: 1,
            leading: 0,
            forceStrutHeight: true,
          ),
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4F46E5),
            letterSpacing: 0.1,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _TableStatusBadge extends StatelessWidget {
  const _TableStatusBadge({required this.status});

  final _ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final style = status.style;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.border),
      ),
      child: Align(
        alignment: Alignment.center,
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          status.label,
          textAlign: TextAlign.center,
          strutStyle: const StrutStyle(
            height: 1,
            leading: 0,
            forceStrutHeight: true,
          ),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: style.foreground,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final style = status.style;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.border),
      ),
      alignment: Alignment.center,
      child: Text(
        status.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: style.foreground,
          height: 1,
        ),
      ),
    );
  }
}

class _TableFooter extends StatelessWidget {
  const _TableFooter({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final start = (currentPage - 1) * pageSize + 1;
    final end = min(currentPage * pageSize, totalItems);

    return Row(
      children: [
        Text(
          'Showing $start–$end of $totalItems items',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const Spacer(),
        _PageBtn(
          icon: Icons.chevron_left_rounded,
          enabled: currentPage > 1,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        const SizedBox(width: 4),
        ...List.generate(totalPages, (i) {
          final page = i + 1;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _PageBtn(
              label: '$page',
              isActive: page == currentPage,
              onTap: () => onPageChanged(page),
            ),
          );
        }),
        _PageBtn(
          icon: Icons.chevron_right_rounded,
          enabled: currentPage < totalPages,
          onTap: () => onPageChanged(currentPage + 1),
        ),
      ],
    );
  }
}

class _PageBtn extends StatelessWidget {
  const _PageBtn({
    this.label,
    this.icon,
    this.isActive = false,
    this.enabled = true,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final bool isActive;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: AppConstants.defaultAnimation,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  size: 18,
                  color: enabled
                      ? AppColors.textSecondary
                      : AppColors.textSecondary.withValues(alpha: 0.3),
                )
              : Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.white : AppColors.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ReportReviewDialog extends StatelessWidget {
  const _ReportReviewDialog({required this.item});

  final _ReportItem item;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    final preferredHeight = switch (item.issue) {
      _IssueType.appFunction => 840.0,
      _IssueType.inappropriateMedia => 820.0,
      _IssueType.mapAddressIssue => 800.0,
      _ => 700.0,
    };
    final dialogHeight = min(maxHeight, preferredHeight);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672),
        child: Container(
          height: dialogHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 50,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              _DialogHeader(item: item),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReporterBlock(item: item),
                      const SizedBox(height: 20),
                      _SectionLabel('ISSUE TYPE'),
                      const SizedBox(height: 8),
                      _IssueChip(issue: item.issue),
                      const SizedBox(height: 20),
                      const _SectionLabel('AFFECTED ITEM'),
                      const SizedBox(height: 8),
                      _AffectedItemBlock(item: item),
                      if (item.systemInfo != null) ...[
                        const SizedBox(height: 20),
                        const _SectionLabel('SYSTEM INFORMATION'),
                        const SizedBox(height: 8),
                        _SystemInfoBlock(systemInfo: item.systemInfo!),
                      ],
                      const SizedBox(height: 20),
                      const _SectionLabel('DESCRIPTION PROVIDED'),
                      const SizedBox(height: 8),
                      _DescriptionBlock(text: item.description),
                      if (item.attachments.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _AttachmentSection(url: item.attachments.first),
                      ],
                    ],
                  ),
                ),
              ),
              _DialogFooter(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.item});

  final _ReportItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          const Text(
            'Report Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172B),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '(${item.id})',
            style: const TextStyle(fontSize: 14, color: Color(0xFF62748E)),
          ),
          const Spacer(),
          IconButton(
            splashRadius: 18,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.close_rounded,
              size: 20,
              color: Color(0xFF90A1B9),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReporterBlock extends StatelessWidget {
  const _ReporterBlock({required this.item});

  final _ReportItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFFF1F5F9),
            child: Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reported by',
                  style: TextStyle(fontSize: 14, color: Color(0xFF62748E)),
                ),
                const SizedBox(height: 2),
                Text(
                  item.reporterName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.reporterEmail,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF62748E)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Status',
                style: TextStyle(fontSize: 14, color: Color(0xFF62748E)),
              ),
              const SizedBox(height: 4),
              _StatusBadge(status: item.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: Color(0xFF62748E),
      ),
    );
  }
}

class _IssueChip extends StatelessWidget {
  const _IssueChip({required this.issue});

  final _IssueType issue;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(issue.icon, size: 16, color: issue.color),
          const SizedBox(width: 8),
          Text(
            issue.label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172B),
            ),
          ),
        ],
      ),
    );
  }
}

class _AffectedItemBlock extends StatelessWidget {
  const _AffectedItemBlock({required this.item});

  final _ReportItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0x80EEF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.target,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172B),
              ),
            ),
          ),
          _DialogCategoryBadge(category: item.category),
        ],
      ),
    );
  }
}

class _DialogCategoryBadge extends StatelessWidget {
  const _DialogCategoryBadge({required this.category});

  final _Category category;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFC6D2FF)),
      ),
      alignment: Alignment.center,
      child: Text(
        category.label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF432DD7),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SystemInfoBlock extends StatelessWidget {
  const _SystemInfoBlock({required this.systemInfo});

  final _SystemInfo systemInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x80F0FDFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBFBF1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SystemField(
              label: 'Device',
              value: systemInfo.device,
              icon: Icons.smartphone_rounded,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _SystemField(label: 'App Version', value: systemInfo.appVersion),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _SystemField(label: 'OS Version', value: systemInfo.osVersion),
          ),
        ],
      ),
    );
  }
}

class _SystemField extends StatelessWidget {
  const _SystemField({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: const Color(0xFF14B8A6)),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF62748E)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DescriptionBlock extends StatelessWidget {
  const _DescriptionBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          height: 1.45,
          color: Color(0xFF314158),
        ),
      ),
    );
  }
}

class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.attach_file_rounded, size: 16, color: Color(0xFF64748B)),
            SizedBox(width: 6),
            Text(
              'ATTACHMENTS (1)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: Color(0xFF62748E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: 306,
          height: 194,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF1F5F9),
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported_outlined,
                color: Color(0xFF94A3B8),
                size: 32,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({required this.item});

  final _ReportItem item;

  List<_DialogActionConfig> _actionsFor() {
    switch (item.issue) {
      case _IssueType.appFunction:
        return [
          const _DialogActionConfig(
            label: 'Forward to Dev',
            icon: Icons.send_rounded,
            background: Color(0xFF9810FA),
            foreground: Colors.white,
            action: _ReviewAction.forward,
          ),
          const _DialogActionConfig(
            label: 'Request Info',
            icon: Icons.chat_bubble_outline_rounded,
            background: Color(0xFF155DFC),
            foreground: Colors.white,
            action: _ReviewAction.requestInfo,
          ),
          const _DialogActionConfig(
            label: 'Dismiss',
            icon: Icons.cancel_outlined,
            background: Colors.white,
            foreground: Color(0xFF314158),
            border: Color(0xFFCAD5E2),
            action: _ReviewAction.dismiss,
          ),
        ];
      case _IssueType.inappropriateMedia:
        return [
          const _DialogActionConfig(
            label: 'Edit Data',
            icon: Icons.edit_outlined,
            background: Color(0xFF155DFC),
            foreground: Colors.white,
          ),
          const _DialogActionConfig(
            label: 'Delete/Hide',
            icon: Icons.delete_outline_rounded,
            background: Color(0xFFE7000B),
            foreground: Colors.white,
            action: _ReviewAction.hideContent,
          ),
          const _DialogActionConfig(
            label: 'Mark as Resolved',
            icon: Icons.check_circle_outline_rounded,
            background: Color(0xFF00A63E),
            foreground: Colors.white,
            action: _ReviewAction.resolve,
          ),
          const _DialogActionConfig(
            label: 'Dismiss',
            icon: Icons.cancel_outlined,
            background: Colors.white,
            foreground: Color(0xFF314158),
            border: Color(0xFFCAD5E2),
            action: _ReviewAction.dismiss,
          ),
        ];
      case _IssueType.missingInformation:
        return [
          const _DialogActionConfig(
            label: 'Edit Data',
            icon: Icons.edit_outlined,
            background: Color(0xFF155DFC),
            foreground: Colors.white,
          ),
          const _DialogActionConfig(
            label: 'Dismiss',
            icon: Icons.cancel_outlined,
            background: Colors.white,
            foreground: Color(0xFF314158),
            border: Color(0xFFCAD5E2),
            action: _ReviewAction.dismiss,
          ),
        ];
      case _IssueType.other:
        return [
          const _DialogActionConfig(
            label: 'Edit Data',
            icon: Icons.edit_outlined,
            background: Color(0xFF155DFC),
            foreground: Colors.white,
          ),
          const _DialogActionConfig(
            label: 'Mark as Resolved',
            icon: Icons.check_circle_outline_rounded,
            background: Color(0xFF00A63E),
            foreground: Colors.white,
            action: _ReviewAction.resolve,
          ),
        ];
      case _IssueType.incorrectData:
      case _IssueType.mapAddressIssue:
        return [
          const _DialogActionConfig(
            label: 'Edit Data',
            icon: Icons.edit_outlined,
            background: Color(0xFF155DFC),
            foreground: Colors.white,
          ),
          const _DialogActionConfig(
            label: 'Mark as Resolved',
            icon: Icons.check_circle_outline_rounded,
            background: Color(0xFF00A63E),
            foreground: Colors.white,
            action: _ReviewAction.resolve,
          ),
          const _DialogActionConfig(
            label: 'Dismiss',
            icon: Icons.cancel_outlined,
            background: Colors.white,
            foreground: Color(0xFF314158),
            border: Color(0xFFCAD5E2),
            action: _ReviewAction.dismiss,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSystemIssue = item.issue == _IssueType.appFunction;
    final actions = _actionsFor();
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Reported on: ${_formatDate(item.createdAt)}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF62748E)),
          ),
          const SizedBox(height: 12),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isSystemIssue
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSystemIssue
                    ? const Color(0xFFFEE685)
                    : const Color(0xFFBEDBFF),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: isSystemIssue
                      ? const Color(0xFF973C00)
                      : const Color(0xFF193CB8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSystemIssue
                        ? 'System Issue: Verify the bug and forward to the development team.'
                        : 'Content Issue: Verify the information and update the database directly.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isSystemIssue
                          ? const Color(0xFF973C00)
                          : const Color(0xFF193CB8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: actions
                .map(
                  (config) => _DialogActionButton(
                    config: config,
                    onTap: () => Navigator.pop(context, config.action),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _DialogActionConfig {
  const _DialogActionConfig({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.border,
    this.action,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final _ReviewAction? action;
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({required this.config, required this.onTap});

  final _DialogActionConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Material(
        color: config.background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: config.border != null
                  ? Border.all(color: config.border!)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(config.icon, size: 15, color: config.foreground),
                const SizedBox(width: 6),
                Text(
                  config.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: config.foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ReviewAction {
  dismiss,
  requestInfo,
  forward,
  inProgress,
  hideContent,
  deleteContent,
  resolve,
}

enum _IssueType {
  incorrectData(
    'Incorrect data',
    Icons.error_outline_rounded,
    Color(0xFFEF4444),
  ),
  mapAddressIssue(
    'Map/address issue',
    Icons.location_on_outlined,
    Color(0xFF2563EB),
  ),
  inappropriateMedia(
    'Inappropriate image/video',
    Icons.image_not_supported_outlined,
    Color(0xFFA855F7),
  ),
  missingInformation(
    'Missing information',
    Icons.article_outlined,
    Color(0xFFF97316),
  ),
  appFunction('App function', Icons.build_outlined, Color(0xFF14B8A6)),
  other('Other', Icons.help_outline_rounded, Color(0xFF64748B));

  const _IssueType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

enum _Category {
  place('PLACE'),
  activity('ACTIVITY'),
  city('CITY'),
  food('FOOD'),
  item('ITEM'),
  system('SYSTEM');

  const _Category(this.label);
  final String label;
}

enum _ReportStatus {
  pending('Pending'),
  inProgress('In Progress'),
  resolved('Resolved'),
  dismissed('Dismissed');

  const _ReportStatus(this.label);
  final String label;
}

class _StatusStyle {
  const _StatusStyle(this.background, this.border, this.foreground);
  final Color background;
  final Color border;
  final Color foreground;
}

extension on _ReportStatus {
  _StatusStyle get style {
    switch (this) {
      case _ReportStatus.pending:
        return const _StatusStyle(
          Color(0xFFFEF3C7),
          Color(0xFFFCD34D),
          Color(0xFF92400E),
        );
      case _ReportStatus.inProgress:
        return const _StatusStyle(
          Color(0xFFDBEAFE),
          Color(0xFF93C5FD),
          Color(0xFF1D4ED8),
        );
      case _ReportStatus.resolved:
        return const _StatusStyle(
          Color(0xFFDCFCE7),
          Color(0xFF86EFAC),
          Color(0xFF166534),
        );
      case _ReportStatus.dismissed:
        return const _StatusStyle(
          Color(0xFFE5E7EB),
          Color(0xFFD1D5DB),
          Color(0xFF334155),
        );
    }
  }
}

class _ReportItem {
  const _ReportItem({
    required this.id,
    required this.reporterName,
    required this.reporterEmail,
    required this.issue,
    required this.target,
    required this.category,
    required this.createdAt,
    required this.status,
    required this.description,
    this.attachments = const [],
    this.systemInfo,
  });

  final String id;
  final String reporterName;
  final String reporterEmail;
  final _IssueType issue;
  final String target;
  final _Category category;
  final DateTime createdAt;
  final _ReportStatus status;
  final String description;
  final List<String> attachments;
  final _SystemInfo? systemInfo;

  _ReportItem copyWith({_ReportStatus? status}) => _ReportItem(
    id: id,
    reporterName: reporterName,
    reporterEmail: reporterEmail,
    issue: issue,
    target: target,
    category: category,
    createdAt: createdAt,
    status: status ?? this.status,
    description: description,
    attachments: attachments,
    systemInfo: systemInfo,
  );
}

class _SystemInfo {
  const _SystemInfo({
    required this.device,
    required this.appVersion,
    required this.osVersion,
  });

  final String device;
  final String appVersion;
  final String osVersion;
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

final List<_ReportItem> _seedReports = [
  _ReportItem(
    id: 'REP-1029',
    reporterName: 'Nguyen Van A',
    reporterEmail: 'nguyenvana@example.com',
    issue: _IssueType.incorrectData,
    target: 'Hoang Yen Buffet',
    category: _Category.place,
    createdAt: DateTime(2023, 10, 25),
    status: _ReportStatus.pending,
    description:
        'The phone number listed for "Hoang Yen Buffet" is incorrect. It should be 0987654321.',
  ),
  _ReportItem(
    id: 'REP-1030',
    reporterName: 'Tran Thi B',
    reporterEmail: 'tranthib@example.com',
    issue: _IssueType.mapAddressIssue,
    target: 'The Coffee House',
    category: _Category.place,
    createdAt: DateTime(2023, 10, 25),
    status: _ReportStatus.inProgress,
    description:
        'The pin for the coffee shop is located on the wrong side of the street. It is actually next to the bookstore.',
    attachments: ['https://picsum.photos/seed/report-map/612/388'],
  ),
  _ReportItem(
    id: 'REP-1031',
    reporterName: 'Le Minh C',
    reporterEmail: 'leminhc@example.com',
    issue: _IssueType.inappropriateMedia,
    target: 'Kayaking in Ha Long Bay',
    category: _Category.activity,
    createdAt: DateTime(2023, 10, 24),
    status: _ReportStatus.pending,
    description:
        'One of the photos uploaded by a user contains inappropriate content and should be removed.',
    attachments: ['https://picsum.photos/seed/report-media/612/388'],
  ),
  _ReportItem(
    id: 'REP-1032',
    reporterName: 'Pham Van D',
    reporterEmail: 'phamvand@example.com',
    issue: _IssueType.missingInformation,
    target: 'Phuc Long Tea & Coffee',
    category: _Category.place,
    createdAt: DateTime(2023, 10, 23),
    status: _ReportStatus.resolved,
    description: 'Opening hours for Sunday are not listed on the page.',
  ),
  _ReportItem(
    id: 'REP-1033',
    reporterName: 'Hoang E',
    reporterEmail: 'hoange@example.com',
    issue: _IssueType.other,
    target: 'Da Nang',
    category: _Category.city,
    createdAt: DateTime(2023, 10, 22),
    status: _ReportStatus.dismissed,
    description: 'The city overview paragraph is cut off in the middle of a sentence.',
  ),
  _ReportItem(
    id: 'REP-1034',
    reporterName: 'Bui Thi F',
    reporterEmail: 'buithif@example.com',
    issue: _IssueType.incorrectData,
    target: 'Pho Bo',
    category: _Category.food,
    createdAt: DateTime(2023, 10, 26),
    status: _ReportStatus.pending,
    description: 'Food details are incorrect.',
  ),
  _ReportItem(
    id: 'REP-1035',
    reporterName: 'Dao Van G',
    reporterEmail: 'daovang@example.com',
    issue: _IssueType.missingInformation,
    target: 'Travel Adapter',
    category: _Category.item,
    createdAt: DateTime(2023, 10, 26),
    status: _ReportStatus.inProgress,
    description: 'Item details are incomplete.',
  ),
  _ReportItem(
    id: 'REP-1036',
    reporterName: 'Vu Thi H',
    reporterEmail: 'vuthih@example.com',
    issue: _IssueType.appFunction,
    target: 'AI Search',
    category: _Category.system,
    createdAt: DateTime(2023, 10, 26),
    status: _ReportStatus.pending,
    description:
        'The app crashes when I try to search for restaurants. It happens every time I type more than 3 characters.',
    attachments: ['https://picsum.photos/seed/report-system/612/388'],
    systemInfo: _SystemInfo(
      device: 'iPhone 14 Pro',
      appVersion: '2.4.1',
      osVersion: 'iOS 17.1',
    ),
  ),
  _ReportItem(
    id: 'REP-1037',
    reporterName: 'Nguyen Minh I',
    reporterEmail: 'nguyenminhi@example.com',
    issue: _IssueType.appFunction,
    target: 'Forum',
    category: _Category.system,
    createdAt: DateTime(2023, 10, 27),
    status: _ReportStatus.inProgress,
    description: 'Forum feature has inconsistent behavior.',
  ),
];

