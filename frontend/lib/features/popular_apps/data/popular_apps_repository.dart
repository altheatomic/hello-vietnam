// Supabase repository for the user-facing Popular Apps list and detail screen.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hellovietnam/features/admin/domain/popular_app_guide.dart';
import '../domain/popular_apps_item.dart';

class PopularAppsRepository {
  PopularAppsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _appTable = 'use_popular_app';
  static const String _categoryTable = 'use_popular_app_category';

  final SupabaseClient _client;

  Future<List<PopularAppsItem>> fetchItems() async {
    final List<dynamic> appRows = await _client
        .from(_appTable)
        .select('*')
        .eq('is_active', true)
        .order('display_order');
    final List<dynamic> catRows = await _client
        .from(_categoryTable)
        .select('*');

    final Map<String, Map<String, dynamic>> categoryById =
        <String, Map<String, dynamic>>{
          for (final Map<String, dynamic> r
              in catRows.cast<Map<String, dynamic>>())
            if (r['id'] != null) r['id'].toString(): r,
        };

    return appRows
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> r) => _rowToItem(r, categoryById))
        .whereType<PopularAppsItem>()
        .toList();
  }

  Future<Map<String, dynamic>?> fetchDetail(String appId) async {
    final List<dynamic> rows = await _client
        .from(_appTable)
        .select('*')
        .eq('id_app', appId)
        .limit(1);
    final List<Map<String, dynamic>> list =
        rows.cast<Map<String, dynamic>>();
    return list.isEmpty ? null : list.first;
  }

  Future<List<String>> fetchCategoryLabels() async {
    final List<dynamic> rows = await _client
        .from(_categoryTable)
        .select('label')
        .order('label');
    return rows
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> r) => _str(r['label']))
        .whereType<String>()
        .toList();
  }

  PopularAppsItem? _rowToItem(
    Map<String, dynamic> row,
    Map<String, Map<String, dynamic>> categoryById,
  ) {
    final String? id = _str(row['id_app']);
    final String? name = _str(row['name']);
    if (id == null || name == null) return null;

    final String catId =
        _str(row['category_id']) ?? _str(row['type']) ?? 'other';
    final Map<String, dynamic>? catRow = categoryById[catId];
    final int colorIndex = (catRow?['color_index'] as num?)?.toInt() ?? 4;
    final color =
        categoryColorPalette[colorIndex % categoryColorPalette.length];

    return PopularAppsItem(
      id: id,
      name: name,
      description: _str(row['description']) ?? '',
      category: _str(catRow?['label']) ?? catId.toUpperCase(),
      logo: name.isNotEmpty ? name[0].toUpperCase() : '?',
      badgeColor: color.withValues(alpha: 0.15),
      badgeTextColor: color,
    );
  }

  String? _str(dynamic v) {
    if (v == null) return null;
    final String s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
