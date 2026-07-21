import 'package:flutter/material.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/config/app_constants.dart';
import 'package:hellovietnam/core/widgets/empty_state.dart';
import 'package:hellovietnam/features/planner/data/models/trip_plan_response.dart';
import 'package:hellovietnam/features/planner/data/trip_repository.dart';

import '../widgets/admin_section_header.dart';

class AdminCfRetrainPage extends StatefulWidget {
  const AdminCfRetrainPage({super.key, this.repository});

  final TripRepository? repository;

  @override
  State<AdminCfRetrainPage> createState() => _AdminCfRetrainPageState();
}

class _AdminCfRetrainPageState extends State<AdminCfRetrainPage> {
  late final TripRepository _repository = widget.repository ?? TripRepository();

  List<CfRetrainLog> _logs = <CfRetrainLog>[];
  bool _logsLoading = true;
  String? _logsError;

  bool _retrainLoading = false;
  String? _retrainBanner;
  bool _retrainSuccess = false;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _logsLoading = true;
      _logsError = null;
    });
    try {
      final logs = await _repository.getCfRetrainLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _logsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logsError = e.toString();
        _logsLoading = false;
      });
    }
  }

  Future<void> _triggerRetrain() async {
    setState(() {
      _retrainLoading = true;
      _retrainBanner = null;
    });
    try {
      await _repository.triggerCfRetrain();
      if (!mounted) return;
      setState(() {
        _retrainSuccess = true;
        _retrainBanner = 'CF retrain job queued successfully.';
        _retrainLoading = false;
      });
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      _fetchLogs();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _retrainSuccess = false;
        _retrainBanner = e.toString();
        _retrainLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminSectionHeader(
          title: 'CF Model Retrain',
          subtitle:
              'Trigger a WALS retraining job and view logs from cf_retrain_log.',
          trailing: _RetrainButton(
            loading: _retrainLoading,
            onPressed: _triggerRetrain,
          ),
        ),

        if (_retrainBanner != null) ...[
          _BannerMessage(message: _retrainBanner!, success: _retrainSuccess),
          const SizedBox(height: 16),
        ],

        _LogsSection(
          logs: _logs,
          loading: _logsLoading,
          error: _logsError,
          onRefresh: _fetchLogs,
        ),
      ],
    );
  }
}

// ── Retrain button ────────────────────────────────────────────────────────────

class _RetrainButton extends StatelessWidget {
  const _RetrainButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.model_training_rounded, size: 18),
      label: Text(loading ? 'Queueing…' : 'Run Retrain'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }
}

// ── Banner ────────────────────────────────────────────────────────────────────

class _BannerMessage extends StatelessWidget {
  const _BannerMessage({required this.message, required this.success});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
    final bg = success ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logs section ──────────────────────────────────────────────────────────────

class _LogsSection extends StatelessWidget {
  const _LogsSection({
    required this.logs,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final List<CfRetrainLog> logs;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'Retrain History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh logs',
              color: AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _LogsBody(logs: logs, loading: loading, error: error),
      ],
    );
  }
}

class _LogsBody extends StatelessWidget {
  const _LogsBody({required this.logs, required this.loading, required this.error});

  final List<CfRetrainLog> logs;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        message: 'Could not load retrain logs.\n$error',
      );
    }
    if (logs.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        message: 'No retrain logs yet.\nTrigger a retrain to see history here.',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _LogRow(log: logs[i]),
    );
  }
}

// ── Log row ───────────────────────────────────────────────────────────────────

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log});

  final CfRetrainLog log;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return const Color(0xFF2E7D32);
      case 'running':
        return AppColors.primary;
      case 'error':
      case 'failed':
        return const Color(0xFFD32F2F);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(log.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              log.status.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Triggered by: ${log.triggeredBy}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    if (log.rowsWritten != null) ...[
                      const SizedBox(width: 16),
                      Text(
                        '${log.rowsWritten} rows written',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Started: ${_formatTs(log.startedAt)}'
                  '${log.finishedAt != null ? '  •  Finished: ${_formatTs(log.finishedAt!)}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (log.errorMsg != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    log.errorMsg!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFD32F2F),
                          fontFamily: 'monospace',
                        ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTs(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
          '${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';
    } catch (_) {
      return iso;
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
