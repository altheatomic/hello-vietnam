import 'package:flutter/material.dart';

import '../data/uploaded_media_repository.dart';
import '../domain/uploaded_media.dart';

/// The historical route name is retained for deep-link compatibility.
///
/// This screen now manages only media a user has uploaded. It never deletes a
/// forum post or any trip, preference, or itinerary data.
class DeleteUserDataPage extends StatefulWidget {
  const DeleteUserDataPage({super.key, this.repository});

  final UploadedMediaRepository? repository;

  @override
  State<DeleteUserDataPage> createState() => _DeleteUserDataPageState();
}

enum _MediaScreen { loading, list, confirming, deleting }

class _DeleteUserDataPageState extends State<DeleteUserDataPage> {
  static const Color _primaryBlue = Color(0xFF81D4FA);
  static const Color _textDark = Color(0xFF151515);

  late final UploadedMediaRepository _repository =
      widget.repository ?? UploadedMediaRepositoryImpl();
  final Set<String> _selectedIds = <String>{};
  List<UploadedMediaItem> _items = const <UploadedMediaItem>[];
  Set<String> _failedIds = <String>{};
  _MediaScreen _screen = _MediaScreen.loading;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _screen = _MediaScreen.loading;
      _errorMessage = null;
    });
    try {
      final List<UploadedMediaItem> loaded = await _repository.loadOwnedMedia();
      if (!mounted) return;
      setState(() {
        _items = loaded;
        _selectedIds.removeWhere(
          (String id) => !loaded.any((UploadedMediaItem item) => item.id == id),
        );
        _screen = _MediaScreen.list;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _screen = _MediaScreen.list;
        _errorMessage = _userFacingError(error);
      });
    }
  }

  String _userFacingError(Object error) {
    const String stateErrorPrefix = 'Bad state: ';
    final String message = error.toString();
    return message.startsWith(stateErrorPrefix)
        ? message.substring(stateErrorPrefix.length)
        : message;
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _statusMessage = null;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _items.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_items.map((UploadedMediaItem item) => item.id));
      }
      _statusMessage = null;
    });
  }

  void _toggleGroup(List<UploadedMediaItem> group) {
    final Set<String> groupIds = group.map((UploadedMediaItem item) => item.id).toSet();
    setState(() {
      if (groupIds.every(_selectedIds.contains)) {
        _selectedIds.removeAll(groupIds);
      } else {
        _selectedIds.addAll(groupIds);
      }
      _statusMessage = null;
    });
  }

  void _openConfirmation() {
    if (_selectedIds.isEmpty) return;
    setState(() {
      _screen = _MediaScreen.confirming;
      _statusMessage = null;
    });
  }

  Future<void> _deleteSelected() async {
    final List<String> ids = _selectedIds.toList(growable: false);
    if (ids.isEmpty) return;

    setState(() {
      _screen = _MediaScreen.deleting;
    });
    try {
      final UploadedMediaDeleteSummary summary = await _repository.deleteMedia(ids);
      if (!mounted) return;

      final Set<String> deletedIds = summary.results
          .where(
            (UploadedMediaDeleteResult result) =>
                result.status == UploadedMediaDeleteStatus.deleted ||
                result.status == UploadedMediaDeleteStatus.notFound,
          )
          .map((UploadedMediaDeleteResult result) => result.mediaId)
          .toSet();
      final Set<String> failedIds = <String>{
        ...summary.failedMediaIds,
        ...ids.where((String id) => !deletedIds.contains(id) && !summary.failedMediaIds.contains(id)),
      };

      setState(() {
        _items.removeWhere((UploadedMediaItem item) => deletedIds.contains(item.id));
        _selectedIds
          ..clear()
          ..addAll(failedIds);
        _failedIds = failedIds;
        _screen = _MediaScreen.list;
        _statusMessage = failedIds.isEmpty
            ? 'Media deleted'
            : 'Some media could not be deleted';
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _screen = _MediaScreen.list;
        _failedIds = ids.toSet();
        _selectedIds
          ..clear()
          ..addAll(ids);
        _statusMessage = 'Some media could not be deleted';
        _errorMessage = null;
      });
    }
  }

  void _retryFailedMedia() {
    if (_failedIds.isEmpty) return;
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(_failedIds);
      _statusMessage = null;
    });
    _deleteSelected();
  }

  void _handleBack() {
    if (_screen == _MediaScreen.confirming) {
      setState(() => _screen = _MediaScreen.list);
      return;
    }
    if (_screen != _MediaScreen.deleting) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _screen != _MediaScreen.confirming && _screen != _MediaScreen.deleting,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _screen == _MediaScreen.confirming) {
          setState(() => _screen = _MediaScreen.list);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _HeaderBar(onBack: _handleBack),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_screen) {
      case _MediaScreen.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading uploaded media...'),
            ],
          ),
        );
      case _MediaScreen.confirming:
        return _buildConfirmation();
      case _MediaScreen.deleting:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Deleting uploaded media...'),
            ],
          ),
        );
      case _MediaScreen.list:
        return _buildMediaList();
    }
  }

  Widget _buildMediaList() {
    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _loadMedia);
    }

    final List<UploadedMediaItem> forumItems = _items
        .where((UploadedMediaItem item) => item.source == UploadedMediaSource.forum)
        .toList(growable: false);
    final List<UploadedMediaItem> aiItems = _items
        .where((UploadedMediaItem item) => item.source == UploadedMediaSource.ai)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
      children: <Widget>[
        const Text(
          'Review and permanently delete images and media you uploaded. This does not delete forum posts or other personal data.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Color(0xFF2B2B2B), height: 1.35),
        ),
        const SizedBox(height: 20),
        if (_statusMessage != null) _StatusMessage(message: _statusMessage!),
        if (_items.isEmpty)
          const _EmptyMediaState()
        else ...<Widget>[
          Row(
            children: <Widget>[
              Text(
                '${_selectedIds.length} selected',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                key: const ValueKey<String>('select-all-media'),
                onPressed: _toggleSelectAll,
                child: Text(_selectedIds.length == _items.length ? 'Clear all' : 'Select all'),
              ),
            ],
          ),
          if (forumItems.isNotEmpty) ...<Widget>[
            _buildGroupHeading('Forum images', forumItems),
            ...forumItems.map(_buildMediaRow),
          ],
          if (aiItems.isNotEmpty) ...<Widget>[
            _buildGroupHeading('AI images', aiItems),
            ...aiItems.map(_buildMediaRow),
          ],
          if (_failedIds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _retryFailedMedia,
              child: const Text('Retry failed media'),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedIds.isEmpty ? null : _openConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD0D0D0),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Delete selected'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGroupHeading(String label, List<UploadedMediaItem> group) {
    final String keyLabel = label.toLowerCase().replaceAll(' ', '-');
    final bool selected = group.every((UploadedMediaItem item) => _selectedIds.contains(item.id));
    return Row(
      children: <Widget>[
        Expanded(child: _GroupHeading(label)),
        TextButton(
          key: ValueKey<String>('select-all-$keyLabel'),
          onPressed: () => _toggleGroup(group),
          child: Text(selected ? 'Clear' : 'Select all'),
        ),
      ],
    );
  }

  Widget _buildMediaRow(UploadedMediaItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _MediaRow(
        key: ValueKey<String>('media-${item.id}'),
        item: item,
        selected: _selectedIds.contains(item.id),
        onTap: () => _toggleSelection(item.id),
        onImageTap: () => _showImagePreview(item),
      ),
    );
  }

  Future<void> _showImagePreview(UploadedMediaItem item) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          key: const ValueKey<String>('media-preview-dialog'),
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(18),
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: item.url == null
                ? const SizedBox(
                    height: 280,
                    child: Center(
                      child: Icon(Icons.image_outlined, color: Colors.white, size: 72),
                    ),
                  )
                : Image.network(
                    key: const ValueKey<String>('media-preview-image'),
                    item.url!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 280,
                      child: Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 72),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmation() {
    final List<UploadedMediaItem> selectedItems = _items
        .where((UploadedMediaItem item) => _selectedIds.contains(item.id))
        .toList(growable: false);
    final bool includesLastImageOnlyPost = selectedItems.any(_isLastImageOnlyPost);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
      children: <Widget>[
        const Text(
          'Confirm media deletion',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _textDark),
        ),
        const SizedBox(height: 12),
        const Text(
          'Selected uploaded media will be permanently deleted and cannot be undone.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Color(0xFF2B2B2B), height: 1.35),
        ),
        if (includesLastImageOnlyPost) ...<Widget>[
          const SizedBox(height: 18),
          const _PostWarning(),
        ],
        const SizedBox(height: 22),
        ...selectedItems.map(
          (UploadedMediaItem item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ConfirmationRow(item: item),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _screen = _MediaScreen.list),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _deleteSelected,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete media'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isLastImageOnlyPost(UploadedMediaItem item) {
    final String? postId = item.postId;
    if (item.source != UploadedMediaSource.forum || postId == null || item.postHasText) {
      return false;
    }
    return _items
        .where((UploadedMediaItem candidate) => candidate.postId == postId)
        .every((UploadedMediaItem candidate) => _selectedIds.contains(candidate.id));
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 40,
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.chevron_left, color: Color(0xFF1B1B1B), size: 30),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage uploaded media',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF121212)),
          ),
        ],
      ),
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onImageTap,
  });

  final UploadedMediaItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onImageTap;

  @override
  Widget build(BuildContext context) {
    final String date = '${item.createdAt.year.toString().padLeft(4, '0')}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')}';
    final String source = item.source == UploadedMediaSource.forum ? 'Forum image' : 'AI image';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFF72C9F2) : const Color(0xFFD8D8D8), width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GestureDetector(
                key: ValueKey<String>('media-image-${item.id}'),
                onTap: onImageTap,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: item.url == null
                      ? const ColoredBox(color: Color(0xFFE5F5FC), child: Icon(Icons.image_outlined))
                      : Image.network(
                          item.url!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFE5F5FC),
                            child: Icon(Icons.image_outlined),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(source, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('Uploaded $date', style: const TextStyle(fontSize: 12, color: Color(0xFF686868))),
                  if (item.source == UploadedMediaSource.forum && item.postHasText)
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text('Post includes text', style: TextStyle(fontSize: 12, color: Color(0xFF686868))),
                    ),
                ],
              ),
            ),
            Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? const Color(0xFF72C9F2) : const Color(0xFFD0D0D0)),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({required this.item});

  final UploadedMediaItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD8D8D8))),
      child: Row(
        children: <Widget>[
          const Icon(Icons.image_outlined),
          const SizedBox(width: 12),
          Expanded(child: Text(item.source == UploadedMediaSource.forum ? 'Forum image' : 'AI image')),
        ],
      ),
    );
  }
}

class _PostWarning extends StatelessWidget {
  const _PostWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0C36A)),
      ),
      child: const Text(
        "Deleting media does not delete the forum post. If this is the post's last image, deleting the post is a separate action.",
        style: TextStyle(height: 1.35, color: Color(0xFF634A16)),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final bool failed = message.startsWith('Some');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: failed ? const Color(0xFFFFF1F0) : const Color(0xFFEAF8EF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(message),
      ),
    );
  }
}

class _EmptyMediaState extends StatelessWidget {
  const _EmptyMediaState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 52),
      child: Column(
        children: <Widget>[
          Icon(Icons.perm_media_outlined, size: 54, color: Color(0xFF8E8E8E)),
          SizedBox(height: 14),
          Text('No uploaded media yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('Images and media you upload will appear here.', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 52, color: Color(0xFF8E8E8E)),
            const SizedBox(height: 14),
            const Text('Unable to load uploaded media', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
