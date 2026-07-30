import 'package:flutter_test/flutter_test.dart';
import 'package:hellovietnam/app/router.dart';
import 'package:hellovietnam/core/language/app_language.dart';
import 'package:hellovietnam/features/home/data/home_feature_data.dart';
import 'package:hellovietnam/features/home/domain/feature_item.dart';

void main() {
  test('forum home feature opens the bottom-nav forum branch', () {
    final FeatureItem forumFeature = homeFeatures.firstWhere(
      (FeatureItem item) => item.title == 'Forum',
    );

    expect(forumFeature.route, AppRoutes.messages);
    expect(
      AppStrings.of(
        AppLanguage.vietnamese,
      ).featureLabelForRoute(forumFeature.route),
      'Diễn đàn',
    );
  });

  test(
    'recommend home feature shows a localized label instead of its route',
    () {
      final FeatureItem recommendFeature = homeFeatures.firstWhere(
        (FeatureItem item) => item.title == 'Recommend',
      );

      expect(recommendFeature.route, AppRoutes.recommendWhereSearch);
      expect(
        AppStrings.of(
          AppLanguage.english,
        ).featureLabelForRoute(recommendFeature.route),
        'Recommend',
      );
      expect(
        AppStrings.of(
          AppLanguage.vietnamese,
        ).featureLabelForRoute(recommendFeature.route),
        'Gợi ý',
      );
    },
  );
}
