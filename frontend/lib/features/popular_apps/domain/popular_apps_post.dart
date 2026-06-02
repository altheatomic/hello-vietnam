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

  factory PopularAppsPost.fromDbRow(Map<String, dynamic> row) {
    final String name = row['name']?.toString().trim() ?? 'App';
    final String description = row['description']?.toString().trim() ?? '';
    final String guide = row['guide']?.toString().trim() ?? '';
    final String imageUrl = row['url_image']?.toString().trim() ?? '';
    final List<String> steps = guide.isEmpty
        ? <String>['No guide available yet.']
        : guide
            .split('\n')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList();
    return PopularAppsPost(
      appId: row['id_app']?.toString() ?? '',
      title: name,
      ctaLabel: 'Open / Download $name',
      heroTitle: 'Video Tutorial',
      heroSubtitle: row['url_video'] != null ? 'Watch the guide' : 'How to use the app',
      summaryTitle: 'What is $name?',
      summaryBody: description.isEmpty ? 'No description available.' : description,
      stepsTitle: 'How to use $name?',
      steps: steps,
      imageUrl: imageUrl,
    );
  }

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
