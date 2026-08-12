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

  CfRetrainSchedule? _schedule;
  TimeOfDay? _selectedUtc;
  bool _scheduleLoading = true;
  bool _scheduleSaving = false;
  String? _scheduleMessage;
  bool _scheduleSuccess = false;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    setState(() {
      _scheduleLoading = true;
      _scheduleMessage = null;
    });
    try {
      final schedule = await _repository.getCfRetrainSchedule();
      if (!mounted) return;
      setState(() {
        _schedule = schedule;
        _selectedUtc = TimeOfDay(
          hour: schedule.hourUtc,
          minute: schedule.minuteUtc,
        );
        _scheduleLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scheduleLoading = false;
        _scheduleSuccess = false;
        _scheduleMessage = e.toString();
      });
    }
  }

  Future<void> _pickScheduleTime() async {
    final initial = _selectedUtc ?? const TimeOfDay(hour: 19, minute: 0);
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'SELECT DAILY RETRAIN TIME (UTC)',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedUtc = selected;
      _scheduleMessage = null;
    });
  }

  Future<void> _saveSchedule() async {
    final selected = _selectedUtc;
    if (selected == null) return;
    setState(() {
      _scheduleSaving = true;
      _scheduleMessage = null;
    });
    try {
      final schedule = await _repository.updateCfRetrainSchedule(
        hourUtc: selected.hour,
        minuteUtc: selected.minute,
      );
      if (!mounted) return;
      setState(() {
        _schedule = schedule;
        _selectedUtc = TimeOfDay(
          hour: schedule.hourUtc,
          minute: schedule.minuteUtc,
        );
        _scheduleSaving = false;
        _scheduleSuccess = true;
        _scheduleMessage = 'Daily retrain schedule updated successfully.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scheduleSaving = false;
        _scheduleSuccess = false;
        _scheduleMessage = e.toString();
      });
    }
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

        _ScheduleCard(
          schedule: _schedule,
          selectedUtc: _selectedUtc,
          loading: _scheduleLoading,
          saving: _scheduleSaving,
          message: _scheduleMessage,
          success: _scheduleSuccess,
          onPickTime: _pickScheduleTime,
          onSave: _saveSchedule,
          onRetry: _fetchSchedule,
        ),
        const SizedBox(height: 24),

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

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.selectedUtc,
    required this.loading,
    required this.saving,
    required this.message,
    required this.success,
    required this.onPickTime,
    required this.onSave,
    required this.onRetry,
  });

  final CfRetrainSchedule? schedule;
  final TimeOfDay? selectedUtc;
  final bool loading;
  final bool saving;
  final String? message;
  final bool success;
  final VoidCallback onPickTime;
  final VoidCallback onSave;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : schedule == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Retrain Schedule'),
                const SizedBox(height: 12),
                _BannerMessage(
                  message: message ?? 'Could not load the schedule.',
                  success: false,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            )
          : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final chosen =
        selectedUtc ??
        TimeOfDay(hour: schedule!.hourUtc, minute: schedule!.minuteUtc);
    final vietnam = DateTime.utc(
      2000,
      1,
      1,
      chosen.hour,
      chosen.minute,
    ).add(const Duration(hours: 7));
    final dayNote = vietnam.day == 1 ? '' : ' (next day)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              'Daily Retrain Schedule',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Choose the daily run time in UTC. Vietnam time is shown for reference.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: saving ? null : onPickTime,
              icon: const Icon(Icons.access_time_rounded),
              label: Text('${_pad(chosen.hour)}:${_pad(chosen.minute)} UTC'),
            ),
            Text(
              '${_pad(vietnam.hour)}:${_pad(vietnam.minute)} Vietnam (UTC+7)$dayNote',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(saving ? 'Saving…' : 'Save schedule'),
            ),
          ],
        ),
        if (schedule!.nextRunAtUtc != null) ...[
          const SizedBox(height: 14),
          Text(
            _formatNextRun(schedule!.nextRunAtUtc!),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (message != null) ...[
          const SizedBox(height: 14),
          _BannerMessage(message: message!, success: success),
        ],
      ],
    );
  }

  String _formatNextRun(String iso) {
    try {
      final utc = DateTime.parse(iso).toUtc();
      final vn = utc.add(const Duration(hours: 7));
      return 'Next run: ${_dateTime(utc)} UTC · ${_dateTime(vn)} Vietnam';
    } catch (_) {
      return 'Next run: $iso';
    }
  }

  String _dateTime(DateTime value) =>
      '${value.year}-${_pad(value.month)}-${_pad(value.day)} '
      '${_pad(value.hour)}:${_pad(value.minute)}';

  String _pad(int value) => value.toString().padLeft(2, '0');
}

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
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
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
  const _LogsBody({
    required this.logs,
    required this.loading,
    required this.error,
  });

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
