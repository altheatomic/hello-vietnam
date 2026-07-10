import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_table_client.dart';
import '../domain/destination.dart';
import '../domain/dish.dart';

class HomeFeaturedContent {
  const HomeFeaturedContent({required this.destinations, required this.dishes});

  final List<Destination> destinations;
  final List<Dish> dishes;
}

class HomeRepository {
  HomeRepository({SupabaseClient? client, SupabaseTableClient? tableClient})
    : _clientOverride = client,
      _tableClient = tableClient;

  final SupabaseClient? _clientOverride;
  final SupabaseTableClient? _tableClient;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  SupabaseTableClient get _resolvedTableClient =>
      _tableClient ?? const SupabaseTableClient();

  Future<HomeFeaturedContent> fetchFeaturedContent({int limit = 4}) async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _fetchDestinations(limit).catchError((_) => <Destination>[]),
      _fetchDishes(limit).catchError((_) => <Dish>[]),
    ]);

    return HomeFeaturedContent(
      destinations: results[0] as List<Destination>,
      dishes: results[1] as List<Dish>,
    );
  }

  Future<List<Destination>> _fetchDestinations(int limit) async {
    final List<Map<String, dynamic>> rows = await _resolvedTableClient.list(
      'featured provinces',
      () async => _client.from('province').select().limit(limit),
    );

    return rows
        .where((Map<String, dynamic> row) => _provinceName(row).isNotEmpty)
        .map<Destination>((Map<String, dynamic> row) {
          final String id = _firstNonEmpty(<String>[
            _text(row['id_province']),
            _text(row['id_city']),
            _text(row['province_id']),
            _text(row['id']),
          ]);
          final int seed = id.isEmpty ? rows.indexOf(row) : id.hashCode;
          return Destination(
            id: id,
            name: _provinceName(row),
            category: _firstNonEmpty(<String>[
              _text(row['area']),
              _text(row['region']),
              _text(row['zone']),
              _shortCategory(_text(row['short_description'])),
              _shortCategory(_text(row['description'])),
              'Vietnam destination',
            ]),
            rating: _rowRating(row, fallbackSeed: seed),
            imagePath: _firstNonEmpty(<String>[
              _text(row['cover_image']),
              _destinationFallbackImage(seed),
            ]),
          );
        })
        .toList(growable: false);
  }

  Future<List<Dish>> _fetchDishes(int limit) async {
    final List<Map<String, dynamic>> rows = await _resolvedTableClient.list(
      'featured foods',
      () async {
        return _client
            .from('food')
            .select('id_food, name, type, image_path, description')
            .order('name')
            .limit(limit);
      },
    );

    return rows
        .where((Map<String, dynamic> row) => _text(row['name']).isNotEmpty)
        .map<Dish>((Map<String, dynamic> row) {
          final String id = _text(row['id_food']);
          final int seed = id.isEmpty ? rows.indexOf(row) : id.hashCode;
          return Dish(
            id: id,
            name: _text(row['name']),
            category: _firstNonEmpty(<String>[
              _text(row['type']),
              _shortCategory(_text(row['description'])),
              'Vietnamese dish',
            ]),
            rating: _ratingFromSeed(seed),
            imagePath: _firstNonEmpty(<String>[
              _text(row['image_path']),
              _dishFallbackImage(seed),
            ]),
          );
        })
        .toList(growable: false);
  }

  String _destinationFallbackImage(int seed) {
    const images = <String>[
      'assets/images/homepage/bestdestination_bg.jpeg',
      'assets/images/explore/explore_bg.jpeg',
      'assets/images/Auth_Image/Vietnam.jpg',
      'assets/images/recommend/where.png',
    ];
    return images[seed.abs() % images.length];
  }

  String _dishFallbackImage(int seed) {
    const images = <String>[
      'assets/images/homepage/bestdishes_bg.jpeg',
      'assets/images/dishes/banh_mi.jpg',
      'assets/images/explore/explore_bg.jpeg',
      'assets/images/Auth_Image/Login.png',
    ];
    return images[seed.abs() % images.length];
  }

  double _ratingFromSeed(int seed) {
    final int normalized = seed.abs() % 55;
    return double.parse((4.25 + normalized / 100).toStringAsFixed(2));
  }

  double _rowRating(Map<String, dynamic> row, {required int fallbackSeed}) {
    final Object? value = row['average_rating'];
    if (value is num) return double.parse(value.toStringAsFixed(2));
    final double? parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return double.parse(parsed.toStringAsFixed(2));
    return _ratingFromSeed(fallbackSeed);
  }

  String _shortCategory(String description) {
    if (description.isEmpty) return '';
    final String firstSentence = description.split(RegExp(r'[.!?]')).first;
    final List<String> words = firstSentence.trim().split(RegExp(r'\s+'));
    if (words.length <= 3) return firstSentence.trim();
    return words.take(3).join(' ');
  }

  String _firstNonEmpty(List<String> values) {
    for (final String value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  String _provinceName(Map<String, dynamic> row) {
    return _firstNonEmpty(<String>[
      _text(row['name']),
      _text(row['province_name']),
      _text(row['province']),
      _text(row['city']),
    ]);
  }

  String _text(Object? value) => value?.toString().trim() ?? '';
}
