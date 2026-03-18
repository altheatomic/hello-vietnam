class RecommendFood {
  const RecommendFood({required this.name, required this.imagePath});

  final String name;
  final String imagePath;
}

class RecommendDestination {
  const RecommendDestination({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.description,
    required this.imagePath,
    required this.rating,
    this.tags = const [],
    this.bestTimeTitle = '',
    this.bestTimeDetails = const [],
    this.activities = const [],
    this.cuisine = const [],
    this.tips = const [],
    this.gallery = const [],
    this.highlights = '',
    this.bestMonths = const [],
  });

  final String id;
  final String name;

  /// One-line teaser shown in list cards.
  final String shortDescription;

  /// Full paragraph shown in detail pages.
  final String description;

  /// Network URL or asset path. Has an errorBuilder fallback everywhere.
  final String imagePath;

  final double rating;
  final List<String> tags;

  // ── Best-time data ─────────────────────────────────────────
  final String bestTimeTitle;
  final List<String> bestTimeDetails;

  // ── Activities & food ──────────────────────────────────────
  final List<String> activities;
  final List<RecommendFood> cuisine;
  final List<String> tips;

  // ── Gallery & highlight ────────────────────────────────────
  final List<String> gallery;
  final String highlights;

  /// Months (1–12) when this destination is at its best.
  /// Used by the When flow to filter results.
  final List<int> bestMonths;
}
