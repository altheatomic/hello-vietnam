import 'dart:convert';

import 'package:flutter/material.dart';

enum AdminContentFieldType {
  text,
  multiline,
  number,
  integer,
  status,
  imageUrl,
  json,
}

class AdminContentFieldConfig {
  const AdminContentFieldConfig({
    required this.key,
    required this.label,
    this.hint,
    this.type = AdminContentFieldType.text,
    this.required = false,
    this.visibleInTable = true,
    this.tableFlex = 1,
    this.options = const <String>[],
    this.readKeys = const <String>[],
  });

  final String key;
  final String label;
  final String? hint;
  final AdminContentFieldType type;
  final bool required;
  final bool visibleInTable;
  final int tableFlex;
  final List<String> options;
  final List<String> readKeys;

  List<String> get allReadKeys => <String>[key, ...readKeys];
}

class AdminContentResourceConfig {
  const AdminContentResourceConfig({
    required this.title,
    required this.subtitle,
    required this.table,
    required this.idColumn,
    required this.route,
    required this.icon,
    required this.fields,
    this.idColumnCandidates = const <String>[],
    this.orderColumn = 'name',
    this.orderAscending = true,
  });

  final String title;
  final String subtitle;
  final String table;
  final String idColumn;
  final String route;
  final IconData icon;
  final List<AdminContentFieldConfig> fields;
  final List<String> idColumnCandidates;
  final String orderColumn;
  final bool orderAscending;

  AdminContentFieldConfig get primaryField =>
      fields.firstWhere((field) => field.required, orElse: () => fields.first);
}

class AdminContentRecord {
  const AdminContentRecord({
    required this.id,
    required this.idColumn,
    required this.values,
  });

  final String id;
  final String idColumn;
  final Map<String, dynamic> values;

  String text(String key) {
    final value = values[key];
    if (value == null) return '';
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString().trim();
  }

  String textForField(AdminContentFieldConfig field) {
    for (final key in field.allReadKeys) {
      final value = text(key);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String searchableText(Iterable<AdminContentFieldConfig> fields) {
    return <String>[
      id,
      for (final field in fields) textForField(field),
    ].join(' ').toLowerCase();
  }
}

class AdminContentConfigs {
  const AdminContentConfigs._();

  static const province = AdminContentResourceConfig(
    title: 'Province Management',
    subtitle: 'Manage provinces and city-level destination records.',
    table: 'province',
    idColumn: 'id_province',
    idColumnCandidates: <String>['id_province', 'id_city', 'province_id', 'id'],
    route: '/admin/provinces',
    icon: Icons.location_city_outlined,
    fields: <AdminContentFieldConfig>[
      AdminContentFieldConfig(
        key: 'name',
        label: 'Province name',
        required: true,
        tableFlex: 2,
        readKeys: <String>['province_name', 'city', 'city_name'],
      ),
      AdminContentFieldConfig(
        key: 'region_code',
        label: 'Region code',
        required: true,
        tableFlex: 1,
      ),
      AdminContentFieldConfig(
        key: 'short_description',
        label: 'Short description',
        type: AdminContentFieldType.multiline,
        tableFlex: 3,
      ),
      AdminContentFieldConfig(
        key: 'detailed_description',
        label: 'Detailed description',
        type: AdminContentFieldType.multiline,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'cover_image',
        label: 'Cover image URL',
        type: AdminContentFieldType.imageUrl,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'gallery',
        label: 'Gallery JSON',
        type: AdminContentFieldType.json,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'average_rating',
        label: 'Rating',
        type: AdminContentFieldType.number,
      ),
      AdminContentFieldConfig(
        key: 'review_count',
        label: 'Reviews',
        type: AdminContentFieldType.integer,
      ),
    ],
  );

  static const place = AdminContentResourceConfig(
    title: 'Place Management',
    subtitle: 'Manage places, opening time notes, media paths, and status.',
    table: 'place',
    idColumn: 'id_place',
    route: '/admin/places',
    icon: Icons.place_outlined,
    orderColumn: 'created_at',
    orderAscending: false,
    fields: <AdminContentFieldConfig>[
      AdminContentFieldConfig(
        key: 'name',
        label: 'Place name',
        required: true,
        tableFlex: 2,
      ),
      AdminContentFieldConfig(
        key: 'short_description',
        label: 'Short description',
        type: AdminContentFieldType.multiline,
        tableFlex: 3,
      ),
      AdminContentFieldConfig(key: 'address', label: 'Address', tableFlex: 2),
      AdminContentFieldConfig(key: 'timespan', label: 'Opening time'),
      AdminContentFieldConfig(key: 'timeclose', label: 'Closing time'),
      AdminContentFieldConfig(
        key: 'status',
        label: 'Status',
        type: AdminContentFieldType.status,
        options: <String>['active', 'draft', 'hidden', 'archived'],
      ),
      AdminContentFieldConfig(
        key: 'id_place_subcategory',
        label: 'Subcategory ID',
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'detailed_description',
        label: 'Detailed description',
        type: AdminContentFieldType.multiline,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'cover_image',
        label: 'Cover image URL',
        type: AdminContentFieldType.imageUrl,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'gallery',
        label: 'Gallery JSON',
        type: AdminContentFieldType.json,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'average_rating',
        label: 'Rating',
        type: AdminContentFieldType.number,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'review_count',
        label: 'Reviews',
        type: AdminContentFieldType.integer,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'phone',
        label: 'Phone',
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'website',
        label: 'Website',
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'latitude',
        label: 'Latitude',
        type: AdminContentFieldType.number,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'longitude',
        label: 'Longitude',
        type: AdminContentFieldType.number,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'minimum_price',
        label: 'Minimum price',
        type: AdminContentFieldType.number,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'maximum_price',
        label: 'Maximum price',
        type: AdminContentFieldType.number,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'estimated_duration_minutes',
        label: 'Estimated duration minutes',
        type: AdminContentFieldType.integer,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'price_level',
        label: 'Price level',
        type: AdminContentFieldType.number,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'id_province',
        label: 'Province ID',
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'id_region',
        label: 'Region ID',
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'id_zone',
        label: 'Zone ID',
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'old_province',
        label: 'Old province ID',
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'source',
        label: 'Source',
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'source_place_id',
        label: 'Source place ID',
        visibleInTable: false,
      ),
    ],
  );

  static const activity = AdminContentResourceConfig(
    title: 'Activity Management',
    subtitle: 'Manage activity suggestions used by explore and planning flows.',
    table: 'activity',
    idColumn: 'id',
    route: '/admin/activities',
    icon: Icons.directions_run_outlined,
    idColumnCandidates: <String>['id', 'id_activity'],
    fields: <AdminContentFieldConfig>[
      AdminContentFieldConfig(
        key: 'name',
        label: 'Activity name',
        required: true,
        tableFlex: 2,
      ),
      AdminContentFieldConfig(key: 'activity_type', label: 'Activity type'),
      AdminContentFieldConfig(
        key: 'short_description',
        label: 'Short description',
        type: AdminContentFieldType.multiline,
        tableFlex: 3,
      ),
      AdminContentFieldConfig(key: 'price_range', label: 'Price range'),
      AdminContentFieldConfig(
        key: 'status',
        label: 'Status',
        type: AdminContentFieldType.status,
        options: <String>['active', 'draft', 'hidden', 'expired', 'archived'],
      ),
      AdminContentFieldConfig(
        key: 'detailed_description',
        label: 'Detailed description',
        type: AdminContentFieldType.multiline,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'safety_notes',
        label: 'Safety notes',
        type: AdminContentFieldType.multiline,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'cover_image',
        label: 'Cover image URL',
        type: AdminContentFieldType.imageUrl,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'gallery',
        label: 'Gallery JSON',
        type: AdminContentFieldType.json,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'opening_hours',
        label: 'Opening hours JSON',
        type: AdminContentFieldType.json,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'average_rating',
        label: 'Rating',
        type: AdminContentFieldType.number,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'review_count',
        label: 'Reviews',
        type: AdminContentFieldType.integer,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'id_province',
        label: 'Province ID',
        visibleInTable: false,
      ),
    ],
  );

  static const culture = AdminContentResourceConfig(
    title: 'Culture Management',
    subtitle: 'Manage cultural content, traditions, and heritage entries.',
    table: 'culture',
    idColumn: 'id',
    route: '/admin/cultures',
    icon: Icons.museum_outlined,
    idColumnCandidates: <String>['id', 'id_culture'],
    fields: <AdminContentFieldConfig>[
      AdminContentFieldConfig(
        key: 'name',
        label: 'Culture title',
        required: true,
        tableFlex: 2,
      ),
      AdminContentFieldConfig(
        key: 'short_description',
        label: 'Short description',
        type: AdminContentFieldType.multiline,
        tableFlex: 3,
      ),
      AdminContentFieldConfig(key: 'event_time', label: 'Event time'),
      AdminContentFieldConfig(
        key: 'status',
        label: 'Status',
        type: AdminContentFieldType.status,
        options: <String>['active', 'draft', 'hidden', 'expired', 'archived'],
      ),
      AdminContentFieldConfig(
        key: 'origin_history',
        label: 'Origin / History',
        type: AdminContentFieldType.multiline,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'cultural_significance',
        label: 'Cultural significance',
        type: AdminContentFieldType.multiline,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'etiquette',
        label: 'Etiquette',
        type: AdminContentFieldType.multiline,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'notable_figures',
        label: 'Notable figures',
        type: AdminContentFieldType.multiline,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'detailed_description',
        label: 'Detailed description',
        type: AdminContentFieldType.multiline,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'cover_image',
        label: 'Cover image URL',
        type: AdminContentFieldType.imageUrl,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'gallery',
        label: 'Gallery JSON',
        type: AdminContentFieldType.json,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'average_rating',
        label: 'Rating',
        type: AdminContentFieldType.number,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'review_count',
        label: 'Reviews',
        type: AdminContentFieldType.integer,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'id_province',
        label: 'Province ID',
        visibleInTable: false,
      ),
    ],
  );

  static const localProduct = AdminContentResourceConfig(
    title: 'Local Product Management',
    subtitle: 'Manage regional products and local specialty records.',
    table: 'local_products',
    idColumn: 'id',
    route: '/admin/local-products',
    icon: Icons.inventory_2_outlined,
    idColumnCandidates: <String>['id', 'id_local_product'],
    fields: <AdminContentFieldConfig>[
      AdminContentFieldConfig(
        key: 'name',
        label: 'Product name',
        required: true,
        tableFlex: 2,
      ),
      AdminContentFieldConfig(key: 'category', label: 'Category'),
      AdminContentFieldConfig(
        key: 'short_description',
        label: 'Short description',
        type: AdminContentFieldType.multiline,
        tableFlex: 3,
      ),
      AdminContentFieldConfig(key: 'price_range', label: 'Price range'),
      AdminContentFieldConfig(
        key: 'status',
        label: 'Status',
        type: AdminContentFieldType.status,
        options: <String>['active', 'draft', 'hidden', 'expired', 'archived'],
      ),
      AdminContentFieldConfig(
        key: 'detailed_description',
        label: 'Detailed description',
        type: AdminContentFieldType.multiline,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'storage_transport',
        label: 'Storage / transport',
        type: AdminContentFieldType.multiline,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'trusted_places',
        label: 'Trusted places',
        type: AdminContentFieldType.multiline,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'cover_image',
        label: 'Cover image URL',
        type: AdminContentFieldType.imageUrl,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'gallery',
        label: 'Gallery JSON',
        type: AdminContentFieldType.json,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'average_rating',
        label: 'Rating',
        type: AdminContentFieldType.number,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'review_count',
        label: 'Reviews',
        type: AdminContentFieldType.integer,
        visibleInTable: false,
      ),
      AdminContentFieldConfig(
        key: 'id_province',
        label: 'Province ID',
        visibleInTable: false,
      ),
    ],
  );
}
