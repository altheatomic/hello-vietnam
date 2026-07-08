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
      id: _readRequiredString(json['id']),
      name: _readRequiredString(json['name']),
      area: _readNullableString(json['area']),
      description: _readNullableString(json['description']),
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

String _readRequiredString(Object? value) {
  final String? normalized = _readNullableString(value);
  return normalized ?? '';
}

String? _readNullableString(Object? value) {
  if (value is String) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  return null;
}
