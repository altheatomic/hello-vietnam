import 'package:flutter/material.dart';
import 'package:hellovietnam/features/admin/domain/admin_data_freshness.dart';

class AdminFreshnessOverviewCards extends StatelessWidget {
  const AdminFreshnessOverviewCards({super.key, required this.overview});

  final AdminFreshnessOverview overview;

  @override
  Widget build(BuildContext context) {
    final cards = <(String, int, IconData)>[
      ('Due / stale', overview.due, Icons.schedule),
      ('Pending', overview.pending, Icons.rate_review_outlined),
      (
        'Tự hết hạn hôm nay',
        overview.autoExpiredToday,
        Icons.event_busy_outlined,
      ),
      ('Run lỗi', overview.failedRuns, Icons.error_outline),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map(
            (card) => SizedBox(
              width: 190,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(card.$3),
                      const SizedBox(height: 6),
                      Text(
                        '${card.$2}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(card.$1),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class AdminFreshnessProposalCard extends StatelessWidget {
  const AdminFreshnessProposalCard({
    super.key,
    required this.proposal,
    required this.busy,
    this.onApprove,
    this.onReject,
    this.onCheckAgain,
  });

  final AdminFreshnessProposal proposal;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onCheckAgain;

  @override
  Widget build(BuildContext context) {
    final String title = proposal.contentType == null
        ? proposal.id
        : '${proposal.contentType} · ${proposal.contentId ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(
              '${proposal.reason} · ${proposal.sourceType ?? 'unknown source'}',
            ),
            const SizedBox(height: 10),
            ...(<String>{
              ...proposal.changedFields,
              if (proposal.changedFields.isEmpty) ...proposal.beforeData.keys,
              if (proposal.changedFields.isEmpty) ...proposal.proposedData.keys,
            }).map(
              (String field) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: 110, child: Text(field)),
                  Expanded(child: Text('${proposal.beforeData[field] ?? '—'}')),
                  const Icon(Icons.arrow_forward, size: 16),
                  Expanded(
                    child: Text('${proposal.proposedData[field] ?? '—'}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: onApprove,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Xác nhận'),
                ),
                OutlinedButton(
                  onPressed: onReject,
                  child: const Text('Giữ hoạt động'),
                ),
                TextButton(
                  onPressed: onCheckAgain,
                  child: const Text('Kiểm tra lại'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AdminFreshnessReportCard extends StatelessWidget {
  const AdminFreshnessReportCard({
    super.key,
    required this.report,
    required this.onOpenDetails,
  });

  final AdminFreshnessReport report;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: const Icon(Icons.flag_outlined),
      title: Text('${report.contentType ?? ''} · ${report.reason}'),
      subtitle: Text(report.note ?? report.contentId ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextButton(
            onPressed: onOpenDetails,
            child: const Text('Xem chi tiết'),
          ),
        ],
      ),
    ),
  );
}

class AdminFreshnessStaleCard extends StatelessWidget {
  const AdminFreshnessStaleCard({
    super.key,
    required this.stale,
    required this.onCheckAgain,
  });

  final AdminFreshnessStale stale;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: const Icon(Icons.schedule_outlined),
      title: Text(
        '${stale.contentType ?? ''} · ${stale.contentId ?? stale.id}',
      ),
      subtitle: Text(
        '${stale.freshnessStatus ?? 'stale'} · ${stale.sourceType ?? 'unknown source'}'
        '${stale.lastError == null ? '' : '\n${stale.lastError}'}',
      ),
      trailing: TextButton(
        onPressed: onCheckAgain,
        child: const Text('Kiểm tra lại'),
      ),
    ),
  );
}

class AdminFreshnessRunCard extends StatelessWidget {
  const AdminFreshnessRunCard({super.key, required this.run});

  final AdminFreshnessRun run;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: const Icon(Icons.history),
      title: Text('${run.triggerType ?? ''} · ${run.status ?? ''}'),
      subtitle: Text(
        'selected ${run.selectedCount} · checked ${run.checkedCount} · proposals ${run.proposalCount} · failed ${run.failedCount}',
      ),
    ),
  );
}

class AdminFreshnessEmptyState extends StatelessWidget {
  const AdminFreshnessEmptyState({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(30),
    child: Center(child: Text(label)),
  );
}
