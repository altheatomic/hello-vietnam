import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hellovietnam/app/theme.dart';
import 'package:hellovietnam/core/widgets/glass_card.dart';
import 'package:hellovietnam/features/forum/data/forum_store.dart';
import 'package:hellovietnam/features/forum/presentation/widgets/forum_widgets.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final ForumStore _store = ForumStore.instance;
  late final TextEditingController _controller;
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = <XFile>[];
  bool _isSubmitting = false;

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
    if (content.isEmpty || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final String postId = await _store.createPost(
        content: content,
        imageFiles: _selectedImages,
      );
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
    final bool canSubmit = _controller.text.trim().isNotEmpty && !_isSubmitting;

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
