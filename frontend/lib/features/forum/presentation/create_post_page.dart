import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/core/widgets/glass_card.dart';
import 'package:hellovietnam/features/explore/data/explore_tracking_service.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/domain/create_forum_post_request.dart';
import 'package:hellovietnam/features/forum/domain/forum_models.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CreatePostCallback =
    Future<String> Function({
      required String content,
      List<String> imageUrls,
      List<XFile> imageFiles,
      SharedExploreItem? sharedExploreItem,
    });

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    this.request = const CreateForumPostRequest(),
    this.currentUserAuthor,
    this.createPost,
    this.exploreTrackingService,
  });

  final CreateForumPostRequest request;
  final ForumAuthor? currentUserAuthor;
  final CreatePostCallback? createPost;
  final ExploreTrackingService? exploreTrackingService;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final ForumStore _store = ForumStore.instance;
  late final TextEditingController _controller;
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = <XFile>[];
  bool _isSubmitting = false;

  ForumAuthor get _currentUserAuthor =>
      widget.currentUserAuthor ?? _store.currentUserAuthor;

  Future<String> _createPost({
    required String content,
    required List<XFile> imageFiles,
  }) {
    final CreatePostCallback? createPost = widget.createPost;
    if (createPost != null) {
      return createPost(
        content: content,
        imageFiles: imageFiles,
        sharedExploreItem: widget.request.sharedExploreItem,
      );
    }
    return _store.createPost(
      content: content,
      imageFiles: imageFiles,
      sharedExploreItem: widget.request.sharedExploreItem,
    );
  }

  bool get _isShareFromExplore => widget.request.sharedExploreItem != null;

  Future<void> _logPlaceShareEvent(String idPlace) async {
    try {
      final User? currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      await Supabase.instance.client.rpc(
        'log_user_event',
        params: <String, dynamic>{
          'p_user_id': currentUser.id,
          'p_place_id': idPlace,
          'p_event_type': 'share',
        },
      );
    } catch (error) {
      debugPrint('log_user_event(share) failed: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openImagePicker() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 86,
      );
      if (!mounted || images.isEmpty) return;

      setState(() {
        _selectedImages
          ..clear()
          ..addAll(images.take(6));
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _submit() async {
    final String content = _controller.text.trim();
    if (_isSubmitting) {
      return;
    }
    if (content.isEmpty && !_isShareFromExplore) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final String postId = await _createPost(
        content: content,
        imageFiles: _selectedImages,
      );
      final SharedExploreItem? sharedItem = widget.request.sharedExploreItem;
      if (sharedItem != null) {
        if (sharedItem.contentType == 'place') {
          await _logPlaceShareEvent(sharedItem.contentId);
        } else {
          await (widget.exploreTrackingService ?? ExploreTrackingService.instance)
              .trackShare(
                contentType: sharedItem.contentType,
                contentId: sharedItem.contentId,
                provinceId: sharedItem.provinceId,
              );
        }
      }
      if (mounted) {
        context.pop(postId);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit =
        (_controller.text.trim().isNotEmpty || _isShareFromExplore) &&
        !_isSubmitting;

    return ForumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: <Widget>[
              ForumTopBar(
                title: context.l10n.ui('Create post'),
                onBack: () => context.pop(),
                onBookmark: _openImagePicker,
                onAvatarTap: () {},
                avatarUrl: _currentUserAuthor.avatarUrl,
                showBookmark: !_isShareFromExplore,
                showAvatar: false,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  children: <Widget>[
                    GlassCard(
                      borderRadius: 28,
                      blur: 16,
                      opacity: 0.54,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              ForumAvatar(
                                imageUrl: _currentUserAuthor.avatarUrl,
                                size: 48,
                                borderColor: Colors.white.withValues(
                                  alpha: 0.76,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _currentUserAuthor.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: ForumColors.textPrimary,
                                  ),
                                ),
                              ),
                              _PostButton(enabled: canSubmit, onTap: _submit),
                            ],
                          ),
                          if (widget.request.sharedExploreItem !=
                              null) ...<Widget>[
                            const SizedBox(height: 18),
                            _SharedExplorePreview(
                              item: widget.request.sharedExploreItem!,
                            ),
                          ],
                          const SizedBox(height: 18),
                          TextField(
                            controller: _controller,
                            maxLines: 8,
                            minLines: 6,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: context.l10n.ui(
                                'What do you want to share?',
                              ),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.5,
                              color: ForumColors.textPrimary,
                            ),
                          ),
                          if (_selectedImages.isNotEmpty &&
                              !_isShareFromExplore) ...<Widget>[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (BuildContext context, int index) {
                                  return Stack(
                                    children: <Widget>[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: _ComposerImage(
                                            image: _selectedImages[index],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedImages.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                          if (!_isShareFromExplore) ...<Widget>[
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: _openImagePicker,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                foregroundColor: ForumColors.bluePrimary,
                              ),
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: Text(
                                _selectedImages.isEmpty
                                    ? 'Add photos'
                                    : 'Edit photos (${_selectedImages.length})',
                              ),
                            ),
                          ],
                        ],
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

class _SharedExplorePreview extends StatelessWidget {
  const _SharedExplorePreview({required this.item});

  final SharedExploreItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 64,
              height: 64,
              child: _SharedPreviewImage(imagePath: item.imagePath),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.labelOverride ?? item.category.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ForumColors.bluePrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ForumColors.textPrimary,
                  ),
                ),
                if (_secondaryText(item).isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    _secondaryText(item),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ForumColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _secondaryText(SharedExploreItem item) {
    final String provinceName = (item.provinceName ?? '').trim();
    if (provinceName.isNotEmpty) {
      return provinceName;
    }
    return (item.subtitle ?? '').trim();
  }
}

class _SharedPreviewImage extends StatelessWidget {
  const _SharedPreviewImage({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final String normalized = imagePath.trim();
    if (normalized.isEmpty) {
      return Container(
        key: const ValueKey<String>('shared-explore-placeholder'),
        color: const Color(0xFFEAF4F8),
      );
    }
    if (normalized.startsWith('assets/')) {
      return Image.asset(
        normalized,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(color: const Color(0xFFEAF4F8)),
      );
    }
    return Image.network(
      normalized,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(color: const Color(0xFFEAF4F8)),
    );
  }
}

class _PostButton extends StatelessWidget {
  const _PostButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: enabled ? ForumColors.primaryGradient : null,
        color: enabled ? null : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              context.l10n.ui('Post'),
              style: TextStyle(
                color: enabled
                    ? Colors.white
                    : AppColors.textSecondary.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerImage extends StatelessWidget {
  const _ComposerImage({required this.image});

  final XFile image;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        final Uint8List? bytes = snapshot.data;
        if (bytes == null) {
          return const ColoredBox(color: Color(0xFFEAF4F8));
        }
        return Image.memory(bytes, fit: BoxFit.cover);
      },
    );
  }
}
