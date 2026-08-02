import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/ai_recognition_history_repository.dart';
import '../domain/ai_recognition_result.dart';

class AiRecognitionHistoryPage extends StatefulWidget {
  const AiRecognitionHistoryPage({
    super.key,
    this.historyStore,
    this.onOpenEntry,
  });

  final AiRecognitionHistoryStore? historyStore;
  final ValueChanged<AiRecognitionHistoryEntry>? onOpenEntry;

  @override
  State<AiRecognitionHistoryPage> createState() =>
      _AiRecognitionHistoryPageState();
}

class _AiRecognitionHistoryPageState extends State<AiRecognitionHistoryPage> {
  static const Color _accent = Color(0xFF29B6F6);
  static const Color _accentDark = Color(0xFF0277BD);

  late final AiRecognitionHistoryStore _historyStore;
  List<AiRecognitionHistoryEntry> _entries =
      const <AiRecognitionHistoryEntry>[];
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _historyStore = widget.historyStore ?? AiRecognitionHistoryRepository();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final List<AiRecognitionHistoryEntry> entries = await _historyStore
          .load();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestDelete(AiRecognitionHistoryEntry entry) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete recognition?'),
          content: Text(
            'Remove "${entry.result.detectedName}" from your local history?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await _historyStore.delete(entry.id);
      if (!mounted) return;
      setState(() {
        _entries = _entries
            .where((AiRecognitionHistoryEntry item) => item.id != entry.id)
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete history item: $error')),
      );
    }
  }

  void _openEntry(AiRecognitionHistoryEntry entry) {
    final ValueChanged<AiRecognitionHistoryEntry>? callback =
        widget.onOpenEntry;
    if (callback != null) {
      callback(entry);
      return;
    }
    context.push('/ai-search', extra: entry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildHeader(context),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Back',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Recognition History',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _HistoryMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load recognition history',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_entries.isEmpty) {
      return const _HistoryMessage(
        icon: Icons.history_rounded,
        title: 'No recognition history yet',
        subtitle: 'Successful recognitions will appear here automatically.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        itemCount: _entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          return _buildEntryCard(context, _entries[index]);
        },
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    AiRecognitionHistoryEntry entry,
  ) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int confidence = (entry.result.confidence * 100).round().clamp(
      0,
      100,
    );
    final String category = _displayCategory(
      entry.result.categoryText,
      entry.result.resultType,
    );

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEntry(entry),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  entry.thumbnailBytes,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 88,
                    height: 88,
                    color: _accent.withValues(alpha: 0.12),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: _accentDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.result.detectedName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _MetadataPill(label: category),
                        _MetadataPill(label: '$confidence% match'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(context, entry.createdAt),
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (entry.result.databaseMatch != null) ...<Widget>[
                      const SizedBox(height: 6),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.link_rounded,
                            size: 15,
                            color: _accentDark,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Linked to database',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _accentDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                key: Key('ai-history-delete-${entry.id}'),
                tooltip: 'Delete',
                onPressed: () => _requestDelete(entry),
                icon: Icon(Icons.delete_outline_rounded, color: colors.error),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayCategory(String categoryText, String resultType) {
    final String category = categoryText.trim().isNotEmpty
        ? categoryText.trim()
        : resultType.trim();
    if (category.isEmpty) return 'Object';
    return '${category[0].toUpperCase()}${category.substring(1)}';
  }

  String _formatTimestamp(BuildContext context, DateTime timestamp) {
    final DateTime local = timestamp.toLocal();
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String date = localizations.formatCompactDate(local);
    final String time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
    );
    return '$date at $time';
  }
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _AiRecognitionHistoryPageState._accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: _AiRecognitionHistoryPageState._accentDark,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: const Color(0xFF29B6F6)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
