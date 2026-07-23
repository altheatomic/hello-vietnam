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

typedef UpdatePostCallback =
    Future<void> Function({
      required String postId,
      required String content,
      required List<String> retainedImageUrls,
      List<XFile> imageFiles,
    });

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    this.request = const CreateForumPostRequest(),
    this.editingPost,
    this.currentUserAuthor,
    this.createPost,
    this.updatePost,
    this.exploreTrackingService,
  });

  final CreateForumPostRequest request;
  final ForumPost? editingPost;
  final ForumAuthor? currentUserAuthor;
  final CreatePostCallback? createPost;
  final UpdatePostCallback? updatePost;
  final ExploreTrackingService? exploreTrackingService;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final ForumStore _store = ForumStore.instance;
  late final TextEditingController _controller;
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _existingImageUrls = <String>[];
  final List<XFile> _selectedImages = <XFile>[];
  bool _isSubmitting = false;

  ForumAuthor get _currentUserAuthor =>
      widget.currentUserAuthor ??
      widget.editingPost?.author ??
      _store.currentUserAuthor;

  bool get _isEditing => widget.editingPost != null;

  SharedExploreItem? get _sharedExploreItem =>
      widget.editingPost?.sharedItem ?? widget.request.sharedExploreItem;

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

  Future<void> _updatePost({
    required String content,
    required List<XFile> imageFiles,
  }) {
    final ForumPost post = widget.editingPost!;
    final UpdatePostCallback? updatePost = widget.updatePost;
    if (updatePost != null) {
      return updatePost(
        postId: post.id,
        content: content,
        retainedImageUrls: List<String>.unmodifiable(_existingImageUrls),
        imageFiles: imageFiles,
      );
    }
    return _store.updatePost(
      postId: post.id,
      content: content,
      retainedImageUrls: List<String>.unmodifiable(_existingImageUrls),
      imageFiles: imageFiles,
    );
  }

  bool get _isShareFromExplore => _sharedExploreItem != null;

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
    _controller = TextEditingController(
      text: widget.editingPost?.content ?? '',
    );
    _existingImageUrls.addAll(
      widget.editingPost?.imageUrls ?? const <String>[],
    );
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
        final int available =
            6 - _existingImageUrls.length - _selectedImages.length;
        if (available > 0) {
          _selectedImages.addAll(images.take(available));
        }
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
      late final String postId;
      if (_isEditing) {
        postId = widget.editingPost!.id;
        await _updatePost(content: content, imageFiles: _selectedImages);
      } else {
        postId = await _createPost(
          content: content,
          imageFiles: _selectedImages,
        );
        final SharedExploreItem? sharedItem = _sharedExploreItem;
        if (sharedItem != null) {
          if (sharedItem.contentType == 'place') {
            await _logPlaceShareEvent(sharedItem.contentId);
          } else {
            await (widget.exploreTrackingService ??
                    ExploreTrackingService.instance)
                .trackShare(
                  contentType: sharedItem.contentType,
                  contentId: sharedItem.contentId,
                  provinceId: sharedItem.provinceId,
                );
          }
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
                title: context.l10n.ui(
                  _isEditing ? 'Edit post' : 'Create post',
                ),
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
                              _PostButton(
                                enabled: canSubmit,
                                onTap: _submit,
                                label: _isEditing ? 'Save' : 'Post',
                              ),
                            ],
                          ),
                          if (_sharedExploreItem != null) ...<Widget>[
                            const SizedBox(height: 18),
                            _SharedExplorePreview(item: _sharedExploreItem!),
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
                          if ((_existingImageUrls.isNotEmpty ||
                                  _selectedImages.isNotEmpty) &&
                              !_isShareFromExplore) ...<Widget>[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount:
                                    _existingImageUrls.length +
                                    _selectedImages.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (BuildContext context, int index) {
                                  final bool isExisting =
                                      index < _existingImageUrls.length;
                                  final int selectedIndex =
                                      index - _existingImageUrls.length;
                                  return Stack(
                                    children: <Widget>[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: isExisting
                                              ? _ExistingComposerImage(
                                                  imageUrl:
                                                      _existingImageUrls[index],
                                                )
                                              : _ComposerImage(
                                                  image:
                                                      _selectedImages[selectedIndex],
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (isExisting) {
                                                _existingImageUrls.removeAt(
                                                  index,
                                                );
                                              } else {
                                                _selectedImages.removeAt(
                                                  selectedIndex,
                                                );
                                              }
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
                                _selectedImages.isEmpty &&
                                        _existingImageUrls.isEmpty
                                    ? 'Add photos'
                                    : 'Edit photos (${_existingImageUrls.length + _selectedImages.length})',
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
  const _PostButton({
    required this.enabled,
    required this.onTap,
    required this.label,
  });

  final bool enabled;
  final VoidCallback onTap;
  final String label;

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
              context.l10n.ui(label),
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

class _ExistingComposerImage extends StatelessWidget {
  const _ExistingComposerImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFEAF4F8)),
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
