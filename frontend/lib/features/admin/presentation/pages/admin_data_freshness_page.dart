import 'package:flutter/material.dart';
import 'package:hellovietnam/features/admin/data/admin_data_freshness_repository.dart';
import 'package:hellovietnam/features/admin/domain/admin_data_freshness.dart';

import '../widgets/admin_data_freshness_widgets.dart';

class AdminDataFreshnessPage extends StatefulWidget {
  const AdminDataFreshnessPage({super.key, this.repository});

  final AdminDataFreshnessRepository? repository;

  @override
  State<AdminDataFreshnessPage> createState() => _AdminDataFreshnessPageState();
}

class _AdminDataFreshnessPageState extends State<AdminDataFreshnessPage> {
  late final AdminDataFreshnessRepository _repository =
      widget.repository ?? AdminDataFreshnessRepository();
  AdminFreshnessOverview _overview = const AdminFreshnessOverview();
  AdminFreshnessPaged<AdminFreshnessProposal> _queue =
      const AdminFreshnessPaged<AdminFreshnessProposal>(
        items: <AdminFreshnessProposal>[],
        totalCount: 0,
      );
  AdminFreshnessPaged<AdminFreshnessReport> _reports =
      const AdminFreshnessPaged<AdminFreshnessReport>(
        items: <AdminFreshnessReport>[],
        totalCount: 0,
      );
  AdminFreshnessPaged<AdminFreshnessStale> _stale =
      const AdminFreshnessPaged<AdminFreshnessStale>(
        items: <AdminFreshnessStale>[],
        totalCount: 0,
      );
  AdminFreshnessPaged<AdminFreshnessRun> _runs =
      const AdminFreshnessPaged<AdminFreshnessRun>(
        items: <AdminFreshnessRun>[],
        totalCount: 0,
      );
  bool _loading = true;
  String? _error;
  int _tab = 0;
  String? _processingProposal;

  static const List<String> _tabs = <String>[
    'Chờ duyệt',
    'Báo sai',
    'Dữ liệu stale',
    'Lịch sử chạy',
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _repository.getOverview(),
        _repository.listQueue(page: 1, pageSize: 20),
        _repository.listStale(page: 1, pageSize: 20),
        _repository.listReports(page: 1, pageSize: 20),
        _repository.listRuns(page: 1, pageSize: 20),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as AdminFreshnessOverview;
        _queue = results[1] as AdminFreshnessPaged<AdminFreshnessProposal>;
        _stale = results[2] as AdminFreshnessPaged<AdminFreshnessStale>;
        _reports = results[3] as AdminFreshnessPaged<AdminFreshnessReport>;
        _runs = results[4] as AdminFreshnessPaged<AdminFreshnessRun>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Data Freshness',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.update_rounded),
                  label: const Text('Kiểm tra ngay'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AdminFreshnessOverviewCards(overview: _overview),
            const SizedBox(height: 22),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List<Widget>.generate(_tabs.length, (int index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_tabs[index]),
                      selected: _tab == index,
                      onSelected: (_) => setState(() => _tab = index),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _ErrorRetry(message: _error!, onRetry: _reload)
            else
              _buildTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case 1:
        return _reports.items.isEmpty
            ? const AdminFreshnessEmptyState(label: 'Chưa có báo sai đang mở.')
            : Column(
                children: _reports.items
                    .map(
                      (AdminFreshnessReport report) => AdminFreshnessReportCard(
                        report: report,
                        onOpenDetails: () => _showReportDetails(report),
                      ),
                    )
                    .toList(growable: false),
              );
      case 2:
        return _stale.items.isEmpty
            ? const AdminFreshnessEmptyState(
                label: 'Không có dữ liệu stale cần hiển thị.',
              )
            : Column(
                children: _stale.items
                    .map(
                      (AdminFreshnessStale stale) => AdminFreshnessStaleCard(
                        stale: stale,
                        onCheckAgain: () => _requestStaleCheck(stale),
                      ),
                    )
                    .toList(growable: false),
              );
      case 3:
        return _runs.items.isEmpty
            ? const AdminFreshnessEmptyState(label: 'Chưa có lịch sử chạy.')
            : Column(
                children: _runs.items
                    .map(
                      (AdminFreshnessRun run) =>
                          AdminFreshnessRunCard(run: run),
                    )
                    .toList(growable: false),
              );
      default:
        return _queue.items.isEmpty
            ? const AdminFreshnessEmptyState(
                label: 'Không có đề xuất chờ duyệt.',
              )
            : Column(
                children: _queue.items
                    .map(
                      (AdminFreshnessProposal proposal) =>
                          _proposalCard(proposal),
                    )
                    .toList(growable: false),
              );
    }
  }

  Widget _proposalCard(AdminFreshnessProposal proposal) {
    final bool busy = _processingProposal == proposal.id;
    return AdminFreshnessProposalCard(
      proposal: proposal,
      busy: busy,
      onApprove: busy
          ? null
          : () => _review(proposal, AdminFreshnessDecision.approved),
      onReject: busy
          ? null
          : () => _review(proposal, AdminFreshnessDecision.rejected),
      onCheckAgain: busy ? null : () => _requestCheck(proposal),
    );
  }

  Future<void> _review(
    AdminFreshnessProposal proposal,
    AdminFreshnessDecision decision,
  ) async {
    if (_processingProposal != null) return;
    setState(() => _processingProposal = proposal.id);
    try {
      await _repository.reviewProposal(
        proposalId: proposal.id,
        decision: decision,
        appliedData: proposal.proposedData,
      );
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _processingProposal = null);
    }
  }

  Future<void> _requestCheck(AdminFreshnessProposal proposal) async {
    final String? type = proposal.contentType;
    final String? id = proposal.contentId;
    if (type == null || id == null) return;
    setState(() => _processingProposal = proposal.id);
    try {
      await _repository.requestCheck(contentType: type, contentId: id);
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _processingProposal = null);
    }
  }

  Future<void> _requestStaleCheck(AdminFreshnessStale stale) async {
    final String? type = stale.contentType;
    final String? id = stale.contentId;
    if (type == null || id == null || _processingProposal != null) return;
    setState(() => _processingProposal = stale.id);
    try {
      await _repository.requestCheck(contentType: type, contentId: id);
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _processingProposal = null);
    }
  }

  Future<void> _showReportDetails(AdminFreshnessReport report) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Chi tiết báo sai'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ReportDetailRow(
                label: 'Nội dung',
                value:
                    '${report.contentType ?? 'Không rõ'} · ${report.contentId ?? 'Không rõ'}',
              ),
              _ReportDetailRow(label: 'Lý do', value: report.reason),
              _ReportDetailRow(
                label: 'Ghi chú',
                value: report.note?.trim().isNotEmpty == true
                    ? report.note!.trim()
                    : 'Không có',
              ),
              _ReportDetailRow(label: 'Trạng thái', value: report.status),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

class _ReportDetailRow extends StatelessWidget {
  const _ReportDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        SelectableText(value),
      ],
    ),
  );
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(child: Text(message)),
      TextButton(onPressed: onRetry, child: const Text('Thử lại')),
    ],
  );
}
