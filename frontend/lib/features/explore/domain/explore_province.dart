class ExploreProvince {
  final String id;
  final String name;
  final String? area;
  final String? description;

  const ExploreProvince({
    required this.id,
    required this.name,
    this.area,
    this.description,
  });

  bool get isResolved => id.trim().isNotEmpty;

  factory ExploreProvince.fromJson(Map<String, dynamic> json) {
    return ExploreProvince(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      area: (json['area'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
    );
  }

  factory ExploreProvince.unresolved(String name) {
    return ExploreProvince(id: '', name: name.trim());
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'area': area,
      'description': description,
    };
  }
}
