import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/widgets/glass_card.dart';
import 'package:hellovietnam/features/forum/data/forum_mock_data.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final ForumStore _store = ForumStore.instance;
  late final TextEditingController _controller;
  final List<String> _selectedImages = <String>[];

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
    final List<String>? result = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final Set<String> draft = <String>{..._selectedImages};
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GlassCard(
                  borderRadius: 28,
                  blur: 18,
                  opacity: 0.78,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Add photos',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ForumColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Mock multi-image picker for the forum composer.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: ForumMockData.uploadImageOptions.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1,
                            ),
                        itemBuilder: (BuildContext context, int index) {
                          final String imageUrl =
                              ForumMockData.uploadImageOptions[index];
                          final bool selected = draft.contains(imageUrl);
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                if (selected) {
                                  draft.remove(imageUrl);
                                } else {
                                  draft.add(imageUrl);
                                }
                              });
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: _ComposerImage(imageUrl: imageUrl),
                                ),
                                if (selected)
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: Colors.black.withValues(
                                        alpha: 0.24,
                                      ),
                                      border: Border.all(
                                        color: ForumColors.cyanPrimary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? ForumColors.cyanPrimary
                                          : Colors.white.withValues(
                                              alpha: 0.76,
                                            ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      selected ? Icons.check : Icons.add,
                                      size: 16,
                                      color: selected
                                          ? Colors.white
                                          : ForumColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ForumColors.bluePrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(draft.toList(growable: false)),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _selectedImages
        ..clear()
        ..addAll(result);
    });
  }

  void _submit() {
    final String content = _controller.text.trim();
    if (content.isEmpty) {
      return;
    }

    final String postId = _store.createPost(
      content: content,
      imageUrls: _selectedImages,
    );
    context.pop(postId);
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _controller.text.trim().isNotEmpty;

    return ForumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: <Widget>[
              ForumTopBar(
                title: 'Create post',
                onBack: () => context.pop(),
                onBookmark: _openImagePicker,
                onNotification: () {},
                onAvatarTap: () {},
                avatarUrl: _store.currentUserAuthor.avatarUrl,
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
                                imageUrl: _store.currentUserAuthor.avatarUrl,
                                size: 48,
                                borderColor: Colors.white.withValues(
                                  alpha: 0.76,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _store.currentUserAuthor.name,
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
                          const SizedBox(height: 18),
                          TextField(
                            controller: _controller,
                            maxLines: 8,
                            minLines: 6,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'What do you want to share?',
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.5,
                              color: ForumColors.textPrimary,
                            ),
                          ),
                          if (_selectedImages.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (BuildContext context, int index) {
                                  final String imageUrl =
                                      _selectedImages[index];
                                  return Stack(
                                    children: <Widget>[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: _ComposerImage(
                                            imageUrl: imageUrl,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedImages.remove(imageUrl);
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
              'Post',
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
  const _ComposerImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(imageUrl, fit: BoxFit.cover);
    }

    return Image.network(imageUrl, fit: BoxFit.cover);
  }
}
