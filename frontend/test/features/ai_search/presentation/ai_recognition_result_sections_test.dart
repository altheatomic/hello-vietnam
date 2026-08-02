import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/features/ai_search/domain/ai_recognition_result.dart';
import 'package:hellovietnam/features/ai_search/presentation/widgets/ai_recognition_result_sections.dart';

void main() {
  testWidgets('renders readable sign OCR, translation, and actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _result(
          kind: AiRecognitionKind.signText,
          detectedName: 'DUONG NGUYEN HUE',
          textAnalysis: const AiRecognitionTextAnalysis(
            originalText: 'DUONG NGUYEN HUE',
            detectedLanguageCode: 'vi',
            detectedLanguageName: 'Vietnamese',
            translatedText: 'Nguyen Hue Street',
            targetLanguageCode: 'en',
            signType: 'street',
            travelContext: 'A street name.',
            mapQuery: 'Nguyen Hue Street, Vietnam',
            canOpenMap: true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('ai-result-sign-text')), findsOneWidget);
    expect(find.text('DUONG NGUYEN HUE'), findsOneWidget);
    expect(find.text('Nguyen Hue Street'), findsOneWidget);
    expect(find.byKey(const Key('ai-sign-map-button')), findsOneWidget);
    expect(find.byKey(const Key('ai-sign-listen-button')), findsOneWidget);
    expect(
      find.byKey(const Key('ai-sign-copy-original-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ai-sign-copy-translation-button')),
      findsOneWidget,
    );
  });

  testWidgets('food retains its travel detail cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _result(
          kind: AiRecognitionKind.food,
          detectedName: 'Bun bo Hue',
          priceRange: '40,000-70,000 VND',
          productionMethod: 'Simmered broth',
          suggestedPlaces: const <String>['Hue'],
        ),
      ),
    );

    expect(find.byKey(const Key('ai-result-food')), findsOneWidget);
    expect(find.byKey(const Key('ai-result-price-card')), findsOneWidget);
    expect(find.byKey(const Key('ai-result-production-card')), findsOneWidget);
    expect(find.text('40,000-70,000 VND'), findsOneWidget);
  });

  testWidgets('landmark exposes visitor context and a conditional map button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _result(
          kind: AiRecognitionKind.landmark,
          detectedName: 'Imperial City of Hue',
          summary: 'A historic citadel.',
          locationHint: 'Hue',
          mapQuery: 'Imperial City of Hue, Vietnam',
          canOpenMap: true,
          bestTime: 'Early morning',
        ),
      ),
    );

    expect(find.byKey(const Key('ai-result-landmark')), findsOneWidget);
    expect(find.byKey(const Key('ai-result-map-button')), findsOneWidget);
    expect(find.text('Early morning'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        _result(
          kind: AiRecognitionKind.landmark,
          detectedName: 'Unknown landmark',
        ),
      ),
    );
    expect(find.byKey(const Key('ai-result-map-button')), findsNothing);
  });

  testWidgets(
    'cultural object exposes materials, use, production, and meaning',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          _result(
            kind: AiRecognitionKind.culturalObject,
            detectedName: 'Non la',
            primaryTags: const <String>['Palm leaf'],
            usageBullets: const <String>['Sun protection', 'Souvenir'],
            productionMethod: 'Hand woven',
            culturalSignificance: 'A familiar Vietnamese craft.',
          ),
        ),
      );

      expect(
        find.byKey(const Key('ai-result-cultural-object')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ai-result-materials-card')), findsOneWidget);
      expect(find.byKey(const Key('ai-result-usage-card')), findsOneWidget);
      expect(
        find.byKey(const Key('ai-result-production-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ai-result-cultural-significance-card')),
        findsOneWidget,
      );
    },
  );

  testWidgets('unclear result exposes retry actions without detail claims', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(_result(kind: AiRecognitionKind.unclear)));

    expect(find.byKey(const Key('ai-result-unclear')), findsOneWidget);
    expect(find.byKey(const Key('ai-result-price-card')), findsNothing);
    expect(find.byKey(const Key('ai-result-materials-card')), findsNothing);
    expect(find.byKey(const Key('ai-result-map-button')), findsNothing);
    expect(find.byKey(const Key('ai-retake-photo-button')), findsOneWidget);
    expect(find.byKey(const Key('ai-choose-image-button')), findsOneWidget);
  });

  testWidgets('unsupported result explains supported scope', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(_result(kind: AiRecognitionKind.unsupported)),
    );

    expect(find.byKey(const Key('ai-result-unsupported')), findsOneWidget);
    expect(find.textContaining('food'), findsOneWidget);
    expect(find.byKey(const Key('ai-result-price-card')), findsNothing);
    expect(find.byKey(const Key('ai-retake-photo-button')), findsOneWidget);
  });

  testWidgets('traffic sign includes an informational safety note', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _result(
          kind: AiRecognitionKind.signText,
          textAnalysis: const AiRecognitionTextAnalysis(
            originalText: 'STOP',
            detectedLanguageCode: 'en',
            detectedLanguageName: 'English',
            translatedText: 'STOP',
            targetLanguageCode: 'vi',
            signType: 'traffic',
            travelContext: 'Traffic sign.',
            mapQuery: '',
            canOpenMap: false,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('ai-sign-traffic-note')), findsOneWidget);
    expect(find.byKey(const Key('ai-sign-map-button')), findsNothing);
  });
}

Widget _host(AiSearchResult result) {
  return MaterialApp(
    home: Scaffold(
      body: AiRecognitionResultSections(
        result: result,
        onOpenMap: () {},
        onCopyOriginal: () {},
        onCopyTranslation: () {},
        onListen: () {},
        onTakePhoto: () {},
        onChooseImage: () {},
      ),
    ),
  );
}

AiSearchResult _result({
  required AiRecognitionKind kind,
  String detectedName = 'Sample result',
  String summary = 'Summary',
  String locationHint = 'Vietnam',
  String bestTime = '',
  String productionMethod = '',
  String priceRange = '',
  String culturalSignificance = '',
  String mapQuery = '',
  bool canOpenMap = false,
  List<String> primaryTags = const <String>[],
  List<String> usageBullets = const <String>[],
  List<String> suggestedPlaces = const <String>[],
  AiRecognitionTextAnalysis? textAnalysis,
}) {
  return AiSearchResult(
    kind: kind,
    confidence: 0.91,
    detectedName: detectedName,
    subtitle: 'Subtitle',
    summary: summary,
    locationHint: locationHint,
    categoryText: 'Category',
    primaryTags: primaryTags,
    secondaryTags: const <String>[],
    bestTime: bestTime,
    note: '',
    culturalSignificance: culturalSignificance,
    usageBullets: usageBullets,
    productionMethod: productionMethod,
    alternativeNames: '',
    priceRange: priceRange,
    suggestedPlaces: suggestedPlaces,
    mapQuery: mapQuery,
    canOpenMap: canOpenMap,
    textAnalysis: textAnalysis,
  );
}
