class PopularAppsPost {
  const PopularAppsPost({
    required this.appId,
    required this.title,
    required this.ctaLabel,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.summaryTitle,
    required this.summaryBody,
    required this.stepsTitle,
    required this.steps,
    required this.imageUrl,
  });

  final String appId;
  final String title;
  final String ctaLabel;
  final String heroTitle;
  final String heroSubtitle;
  final String summaryTitle;
  final String summaryBody;
  final String stepsTitle;
  final List<String> steps;
  final String imageUrl;
}
