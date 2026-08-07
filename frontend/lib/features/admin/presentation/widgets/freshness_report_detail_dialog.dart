import 'package:flutter/material.dart';
import 'package:hellovietnam/features/admin/domain/admin_data_freshness.dart';

/// Report detail presentation used by the Data Freshness report queue.
class FreshnessReportDetailDialog extends StatefulWidget {
  const FreshnessReportDetailDialog({
    super.key,
    required this.report,
    required this.onClose,
    required this.onEdit,
    required this.onResolve,
  });

  final AdminFreshnessReport report;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final Future<void> Function() onResolve;

  @override
  State<FreshnessReportDetailDialog> createState() => _FreshnessReportDetailDialogState();
}

class _FreshnessReportDetailDialogState extends State<FreshnessReportDetailDialog> {
  late AdminFreshnessReport _report = widget.report;
  bool _saving = false;

  Future<void> _resolve() async {
    if (_saving || _report.status == 'resolved') return;
    setState(() => _saving = true);
    try {
      await widget.onResolve();
      if (mounted) setState(() => _report = _report.copyWith(status: 'resolved'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.sizeOf(context).height * .9;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 672, maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 50,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              _Header(report: _report, onClose: widget.onClose),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Reporter(report: _report),
                      const SizedBox(height: 20),
                      const _SectionLabel('ISSUE TYPE'),
                      const SizedBox(height: 8),
                      _IssueChip(reason: _report.reason),
                      const SizedBox(height: 20),
                      const _SectionLabel('AFFECTED ITEM'),
                      const SizedBox(height: 8),
                      _InfoBlock(
                        icon: Icons.place_outlined,
                        title: _report.contentType ?? 'Unknown content',
                        subtitle: _report.contentId ?? 'Unknown ID',
                      ),
                      const SizedBox(height: 20),
                      const _SectionLabel('DESCRIPTION PROVIDED'),
                      const SizedBox(height: 8),
                      _Description(
                        _report.note?.trim().isNotEmpty == true
                            ? _report.note!.trim()
                            : 'No description provided.',
                      ),
                    ],
                  ),
                ),
              ),
              _Footer(
                onClose: widget.onClose,
                onEdit: _report.status == 'resolved' ? null : widget.onEdit,
                onResolve: _resolve,
                saving: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.report, required this.onClose});

  final AdminFreshnessReport report;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    height: 65,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: const BoxDecoration(
      color: Color(0xFFF8FAFC),
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
    ),
    child: Row(
      children: <Widget>[
        const Text(
          'Report Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172B),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Report',
          style: TextStyle(fontSize: 13, color: Color(0xFF62748E)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '(${report.id})',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Color(0xFF62748E)),
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF90A1B9)),
        ),
      ],
    ),
  );
}

class _Reporter extends StatelessWidget {
  const _Reporter({required this.report});

  final AdminFreshnessReport report;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(bottom: 16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
    ),
    child: Row(
      children: <Widget>[
        const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFFF1F5F9),
          child: Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Reported by', style: TextStyle(fontSize: 14, color: Color(0xFF62748E))),
              const SizedBox(height: 2),
              Text(
                report.reporterName ?? 'Unknown user',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172B)),
              ),
              const SizedBox(height: 2),
              Text(
                report.reporterEmail ?? 'Data Freshness report',
                style: const TextStyle(fontSize: 14, color: Color(0xFF62748E)),
              ),
            ],
          ),
        ),
        _StatusBadge(status: report.status),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: .7,
      color: Color(0xFF62748E),
    ),
  );
}

class _IssueChip extends StatelessWidget {
  const _IssueChip({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) => Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF1F5F9)),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.flag_outlined, size: 20, color: Color(0xFFEF4444)),
        const SizedBox(width: 10),
        Text(reason, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172B))),
      ],
    ),
  );
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF1F5F9)),
    ),
    child: Row(
      children: <Widget>[
        Icon(icon, color: const Color(0xFF2563EB)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172B))),
              const SizedBox(height: 3),
              SelectableText(subtitle, style: const TextStyle(color: Color(0xFF62748E))),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Description extends StatelessWidget {
  const _Description(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFF1F5F9)),
    ),
    child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF334155))),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onClose, required this.onEdit, required this.onResolve, required this.saving});

  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final Future<void> Function() onResolve;
  final bool saving;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 8,
      children: <Widget>[
        OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
        OutlinedButton.icon(
          onPressed: saving ? null : () => onResolve(),
          icon: saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_circle_outline, size: 16),
          label: const Text('Resolved'),
        ),
        TextButton(onPressed: onClose, child: const Text('Close')),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFDBEAFE),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFF93C5FD)),
    ),
    child: Text(
      status == 'open' ? 'pending' : status,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
    ),
  );
}
