import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/trip_share_link.dart';
import '../../data/trip_repository.dart';

Future<void> showTripShareSheet(
  BuildContext context, {
  required String idPlan,
  required Future<void> Function() onShareToForum,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) =>
        TripShareSheet(idPlan: idPlan, onShareToForum: onShareToForum),
  );
}

class TripShareSheet extends StatefulWidget {
  const TripShareSheet({
    super.key,
    required this.idPlan,
    required this.onShareToForum,
    this.repository,
  });

  final String idPlan;
  final Future<void> Function() onShareToForum;
  final TripRepository? repository;

  @override
  State<TripShareSheet> createState() => _TripShareSheetState();
}

class _TripShareSheetState extends State<TripShareSheet> {
  late final TripRepository _repository;
  int _expiryDays = 30;
  bool _allowCopy = true;
  bool _busy = false;
  bool _loadingLinks = true;
  List<TripShareLink> _links = const <TripShareLink>[];
  Uri? _latestUrl;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? TripRepository();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    try {
      final links = await _repository.listShareLinks(idPlan: widget.idPlan);
      if (mounted) setState(() => _links = links);
    } catch (_) {
      if (mounted) {
        _message('Could not load existing links.');
      }
    } finally {
      if (mounted) setState(() => _loadingLinks = false);
    }
  }

  Future<void> _createAndShare() async {
    setState(() => _busy = true);
    try {
      final CreatedTripShare result = await _repository.createShareLink(
        widget.idPlan,
        expiryDays: _expiryDays,
        allowCopy: _allowCopy,
      );
      if (!mounted) return;
      setState(() {
        _latestUrl = result.url;
      });
      await SharePlus.instance.share(
        ShareParams(
          text: 'Explore my Vietnam itinerary on HelloVietnam:\n${result.url}',
          subject: 'HelloVietnam itinerary',
        ),
      );
      await _loadLinks();
    } catch (_) {
      if (mounted) {
        _message('Could not create the share link. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copyLatestLink() async {
    final Uri? url = _latestUrl;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url.toString()));
    if (mounted) _message('Link copied.');
  }

  Future<void> _revoke(TripShareLink link) async {
    setState(() => _busy = true);
    try {
      await _repository.revokeShareLink(link.idShare);
      if (!mounted) return;
      setState(() {
        _links = _links
            .map(
              (item) => item.idShare == link.idShare
                  ? TripShareLink(
                      idShare: item.idShare,
                      idPlan: item.idPlan,
                      tokenPrefix: item.tokenPrefix,
                      title: item.title,
                      allowCopy: item.allowCopy,
                      expiresAt: item.expiresAt,
                      revokedAt: DateTime.now().toUtc(),
                      createdAt: item.createdAt,
                    )
                  : item,
            )
            .toList();
      });
      _message('Link revoked.');
    } catch (_) {
      if (mounted) {
        _message('Could not revoke this link.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TripShareLink> activeLinks = _links
        .where((link) => link.isActiveAt(DateTime.now().toUtc()))
        .toList();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Share itinerary',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Anyone with the link can view this itinerary. The link can be revoked at any time.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Text('Link expires after', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 7, label: Text('7 days')),
              ButtonSegment<int>(value: 30, label: Text('30 days')),
              ButtonSegment<int>(value: 90, label: Text('90 days')),
            ],
            selected: <int>{_expiryDays},
            onSelectionChanged: _busy
                ? null
                : (Set<int> value) => setState(() => _expiryDays = value.first),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow recipients to copy this trip'),
            value: _allowCopy,
            onChanged: _busy
                ? null
                : (bool value) => setState(() => _allowCopy = value),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _createAndShare,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: const Text('Create link and share'),
          ),
          if (_latestUrl != null) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _copyLatestLink,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy latest link'),
            ),
          ],
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    Navigator.pop(context);
                    await widget.onShareToForum();
                  },
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Share inside HelloVietnam Forum'),
          ),
          const Divider(height: 28),
          Text(
            'Active links',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_loadingLinks)
            const Center(child: CircularProgressIndicator())
          else if (activeLinks.isEmpty)
            const Text('No active public links.')
          else
            ...activeLinks.map(
              (link) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_rounded),
                title: Text('Link ${link.tokenPrefix}…'),
                subtitle: Text('Expires ${_date(link.expiresAt)}'),
                trailing: IconButton(
                  tooltip: 'Revoke link',
                  onPressed: _busy ? null : () => _revoke(link),
                  icon: const Icon(Icons.link_off_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _date(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
