import 'package:hellovietnam/core/media/media_url_resolver.dart';

typedef PlannerMediaResolver = String Function(String rawValue);

class PlannerProvince {
  const PlannerProvince({
    required this.id,
    required this.name,
    required this.area,
    this.coverImage,
  });

  factory PlannerProvince.fromReferenceRecord(
    Map<String, dynamic> row, {
    PlannerMediaResolver mediaResolver = MediaUrlResolver.resolve,
  }) {
    final String rawImage = row['cover_image']?.toString().trim() ?? '';
    final String coverImage = rawImage.isEmpty
        ? ''
        : mediaResolver(rawImage).trim();
    return PlannerProvince(
      id: (row['id_province']?.toString() ?? '').trim(),
      name: (row['name']?.toString() ?? '').trim(),
      area: (row['region_code']?.toString() ?? '').trim(),
      coverImage: coverImage.isEmpty ? null : coverImage,
    );
  }

  final String id;
  final String name;
  final String area;
  final String? coverImage;
}
