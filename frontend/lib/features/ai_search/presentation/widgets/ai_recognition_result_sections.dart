import 'package:flutter/material.dart';
import 'package:hellovietnam/features/ai_search/domain/ai_recognition_result.dart';

class AiRecognitionResultSections extends StatelessWidget {
  const AiRecognitionResultSections({
    super.key,
    required this.result,
    required this.onOpenMap,
    required this.onCopyOriginal,
    required this.onCopyTranslation,
    required this.onListen,
    required this.onTakePhoto,
    required this.onChooseImage,
  });

  final AiSearchResult result;
  final VoidCallback onOpenMap;
  final VoidCallback onCopyOriginal;
  final VoidCallback onCopyTranslation;
  final VoidCallback onListen;
  final VoidCallback onTakePhoto;
  final VoidCallback onChooseImage;

  @override
  Widget build(BuildContext context) {
    return switch (result.kind) {
      AiRecognitionKind.food => _FoodSection(result: result),
      AiRecognitionKind.landmark => _LandmarkSection(
        result: result,
        onOpenMap: onOpenMap,
      ),
      AiRecognitionKind.culturalObject => _CulturalObjectSection(
        result: result,
        onOpenMap: onOpenMap,
      ),
      AiRecognitionKind.signText => _SignTextSection(
        result: result,
        onOpenMap: onOpenMap,
        onCopyOriginal: onCopyOriginal,
        onCopyTranslation: onCopyTranslation,
        onListen: onListen,
      ),
      AiRecognitionKind.unclear => _UnclearSection(
        onTakePhoto: onTakePhoto,
        onChooseImage: onChooseImage,
      ),
      AiRecognitionKind.unsupported => _UnsupportedSection(
        onTakePhoto: onTakePhoto,
        onChooseImage: onChooseImage,
      ),
    };
  }
}

class _FoodSection extends StatelessWidget {
  const _FoodSection({required this.result});

  final AiSearchResult result;

  @override
  Widget build(BuildContext context) {
    return _SectionColumn(
      key: const Key('ai-result-food'),
      children: <Widget>[
        if (result.summary.isNotEmpty)
          _ResultCard(title: 'About this dish', child: Text(result.summary)),
        if (result.priceRange.isNotEmpty)
          _ResultCard(
            key: const Key('ai-result-price-card'),
            title: 'Typical price',
            child: Text(result.priceRange),
          ),
        if (result.productionMethod.isNotEmpty)
          _ResultCard(
            key: const Key('ai-result-production-card'),
            title: 'How it is made',
            child: Text(result.productionMethod),
          ),
        if (result.suggestedPlaces.isNotEmpty)
          _ResultCard(
            title: 'Where to try it',
            child: Text(result.suggestedPlaces.join(', ')),
          ),
      ],
    );
  }
}

class _LandmarkSection extends StatelessWidget {
  const _LandmarkSection({required this.result, required this.onOpenMap});

  final AiSearchResult result;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return _SectionColumn(
      key: const Key('ai-result-landmark'),
      children: <Widget>[
        if (result.summary.isNotEmpty)
          _ResultCard(title: 'Visitor context', child: Text(result.summary)),
        if (result.locationHint.isNotEmpty)
          _ResultCard(title: 'Area', child: Text(result.locationHint)),
        if (result.bestTime.isNotEmpty)
          _ResultCard(
            title: 'A good time to visit',
            child: Text(result.bestTime),
          ),
        if (_hasMap(result)) _MapButton(onPressed: onOpenMap),
      ],
    );
  }
}

class _CulturalObjectSection extends StatelessWidget {
  const _CulturalObjectSection({required this.result, required this.onOpenMap});

  final AiSearchResult result;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return _SectionColumn(
      key: const Key('ai-result-cultural-object'),
      children: <Widget>[
        if (result.primaryTags.isNotEmpty)
          _ResultCard(
            key: const Key('ai-result-materials-card'),
            title: 'Materials',
            child: Text(result.primaryTags.join(', ')),
          ),
        if (result.usageBullets.isNotEmpty)
          _ResultCard(
            key: const Key('ai-result-usage-card'),
            title: 'How it is used',
            child: _BulletList(result.usageBullets),
          ),
        if (result.productionMethod.isNotEmpty)
          _ResultCard(
            key: const Key('ai-result-production-card'),
            title: 'How it is made',
            child: Text(result.productionMethod),
          ),
        if (result.culturalSignificance.isNotEmpty)
          _ResultCard(
            key: const Key('ai-result-cultural-significance-card'),
            title: 'Cultural significance',
            child: Text(result.culturalSignificance),
          ),
        if (_hasMap(result)) _MapButton(onPressed: onOpenMap),
      ],
    );
  }
}

class _SignTextSection extends StatelessWidget {
  const _SignTextSection({
    required this.result,
    required this.onOpenMap,
    required this.onCopyOriginal,
    required this.onCopyTranslation,
    required this.onListen,
  });

  final AiSearchResult result;
  final VoidCallback onOpenMap;
  final VoidCallback onCopyOriginal;
  final VoidCallback onCopyTranslation;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final AiRecognitionTextAnalysis? text = result.textAnalysis;
    if (text == null || text.originalText.trim().isEmpty) {
      return const _UnclearSectionContent();
    }

    return _SectionColumn(
      key: const Key('ai-result-sign-text'),
      children: <Widget>[
        _ResultCard(
          title: 'Original text',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(text.originalText),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('ai-sign-copy-original-button'),
                  onPressed: onCopyOriginal,
                  icon: const Icon(Icons.copy_outlined, size: 17),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
        ),
        if (text.translatedText.trim().isNotEmpty)
          _ResultCard(
            title: 'Translation',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(text.translatedText),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      key: const Key('ai-sign-copy-translation-button'),
                      onPressed: onCopyTranslation,
                      icon: const Icon(Icons.copy_outlined, size: 17),
                      label: const Text('Copy'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('ai-sign-listen-button'),
                      onPressed: onListen,
                      icon: const Icon(Icons.volume_up_outlined, size: 17),
                      label: const Text('Listen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (text.signType == 'traffic')
          _ResultCard(
            key: const Key('ai-sign-traffic-note'),
            title: 'Safety note',
            child: const Text(
              'Follow local traffic signs and instructions. This explanation is for travel context only.',
            ),
          ),
        if (text.canOpenMap && text.mapQuery.trim().isNotEmpty)
          _MapButton(
            key: const Key('ai-sign-map-button'),
            onPressed: onOpenMap,
          ),
      ],
    );
  }
}

class _UnclearSection extends StatelessWidget {
  const _UnclearSection({
    required this.onTakePhoto,
    required this.onChooseImage,
  });

  final VoidCallback onTakePhoto;
  final VoidCallback onChooseImage;

  @override
  Widget build(BuildContext context) {
    return _SectionColumn(
      key: const Key('ai-result-unclear'),
      children: <Widget>[
        const _UnclearSectionContent(),
        _RetryActions(onTakePhoto: onTakePhoto, onChooseImage: onChooseImage),
      ],
    );
  }
}

class _UnclearSectionContent extends StatelessWidget {
  const _UnclearSectionContent();

  @override
  Widget build(BuildContext context) {
    return _ResultCard(
      title: 'Could not recognize clearly',
      child: const Text(
        'Try a brighter, closer photo with one clear subject in frame.',
      ),
    );
  }
}

class _UnsupportedSection extends StatelessWidget {
  const _UnsupportedSection({
    required this.onTakePhoto,
    required this.onChooseImage,
  });

  final VoidCallback onTakePhoto;
  final VoidCallback onChooseImage;

  @override
  Widget build(BuildContext context) {
    return _SectionColumn(
      key: const Key('ai-result-unsupported'),
      children: <Widget>[
        _ResultCard(
          title: 'Image type not supported',
          child: const Text(
            'This feature currently focuses on Vietnamese food, landmarks, cultural objects, and readable signs. We do not identify people or sensitive documents.',
          ),
        ),
        _RetryActions(onTakePhoto: onTakePhoto, onChooseImage: onChooseImage),
      ],
    );
  }
}

class _RetryActions extends StatelessWidget {
  const _RetryActions({required this.onTakePhoto, required this.onChooseImage});

  final VoidCallback onTakePhoto;
  final VoidCallback onChooseImage;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: <Widget>[
        FilledButton.icon(
          key: const Key('ai-retake-photo-button'),
          onPressed: onTakePhoto,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Take another photo'),
        ),
        OutlinedButton.icon(
          key: const Key('ai-choose-image-button'),
          onPressed: onChooseImage,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose another image'),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        key: const Key('ai-result-map-button'),
        onPressed: onPressed,
        icon: const Icon(Icons.map_outlined),
        label: const Text('Find on map'),
      ),
    );
  }
}

class _SectionColumn extends StatelessWidget {
  const _SectionColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int index = 0; index < children.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(height: 12),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodyMedium,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (String item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item'),
            ),
          )
          .toList(growable: false),
    );
  }
}

bool _hasMap(AiSearchResult result) =>
    result.canOpenMap && result.mapQuery.trim().isNotEmpty;
