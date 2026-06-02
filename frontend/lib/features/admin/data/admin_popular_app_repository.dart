// Supabase repository for admin Popular App Guide management.
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/popular_app_guide.dart';

class AdminPopularAppRepository {
  AdminPopularAppRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<PopularAppGuide>> fetchApps() async {
    final List<dynamic> rows = await _client
        .from('use_popular_app')
        .select('*')
        .order('created_at', ascending: false);
    return rows.cast<Map<String, dynamic>>().map(_guideFromRow).toList();
  }

  Future<List<AppCategory>> fetchCategories() async {
    final List<dynamic> rows = await _client
        .from('use_popular_app_category')
        .select('*')
        .order('label');
    return rows.cast<Map<String, dynamic>>().map(_categoryFromRow).toList();
  }

  Future<PopularAppGuide> createApp({required PopularAppGuide app}) async {
    final Map<String, dynamic> inserted = await _client
        .from('use_popular_app')
        .insert(_appToRow(app))
        .select('*')
        .single();
    return _guideFromRow(inserted);
  }

  Future<PopularAppGuide> updateApp({required PopularAppGuide app}) async {
    final Map<String, dynamic> updated = await _client
        .from('use_popular_app')
        .update(_appToRow(app))
        .eq('id_app', app.id)
        .select('*')
        .single();
    return _guideFromRow(updated);
  }

  Future<void> deleteApp(String id) async {
    await _client.from('use_popular_app').delete().eq('id_app', id);
  }

  Future<void> upsertCategory({required AppCategory category}) async {
    await _client.from('use_popular_app_category').upsert(<String, dynamic>{
      'id': category.id,
      'label': category.label,
      'color_index': category.colorIndex,
    });
  }

  Future<void> deleteCategory(String id) async {
    await _client.from('use_popular_app_category').delete().eq('id', id);
  }

  Future<void> reassignCategory({
    required String fromId,
    required String toId,
  }) async {
    await _client
        .from('use_popular_app')
        .update(<String, dynamic>{'category_id': toId})
        .eq('category_id', fromId);
  }

  PopularAppGuide _guideFromRow(Map<String, dynamic> row) {
    return PopularAppGuide(
      id: _str(row['id_app']) ?? '',
      name: _str(row['name']) ?? '',
      categoryId:
          _str(row['category_id']) ?? _str(row['type']) ?? 'other',
      packageName: _str(row['package_name']) ?? '',
      storeUrl: _str(row['store_url']) ?? '',
      urlImage: _nullableStr(row['url_image']),
      urlVideo: _nullableStr(row['url_video']),
      description: _nullableStr(row['description']),
      guide: _nullableStr(row['guide']),
      createdAt: _parseDate(row['created_at'] ?? row['update_at']),
    );
  }

  AppCategory _categoryFromRow(Map<String, dynamic> row) {
    return AppCategory(
      id: _str(row['id']) ?? '',
      label: _str(row['label']) ?? '',
      colorIndex: (row['color_index'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> _appToRow(PopularAppGuide app) => <String, dynamic>{
    'name': app.name,
    'category_id': app.categoryId,
    'description': _nullableStr(app.description),
    'guide': _nullableStr(app.guide),
    'url_image': _nullableStr(app.urlImage),
    'url_video': _nullableStr(app.urlVideo),
    'package_name':
        app.packageName.trim().isEmpty ? null : app.packageName.trim(),
    'store_url': app.storeUrl.trim().isEmpty ? null : app.storeUrl.trim(),
  };

  String? _str(dynamic v) {
    if (v == null) return null;
    final String s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String? _nullableStr(String? v) {
    final String? s = v?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString())?.toLocal() ?? DateTime.now();
  }
}
