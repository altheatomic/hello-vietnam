import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hellovietnam/core/auth/auth_repository.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/core/network/edge_function_client.dart';
import 'package:hellovietnam/core/network/supabase_table_client.dart';
import 'package:hellovietnam/core/storage/local_storage.dart' as app_storage;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class CurrencyCatalogEntry {
  const CurrencyCatalogEntry({
    required this.code,
    required this.name,
    required this.symbol,
    required this.flagCode,
  });

  final String code;
  final String name;
  final String symbol;
  final String flagCode;
}

class CurrencyRatesSnapshot {
  const CurrencyRatesSnapshot({
    required this.baseCode,
    required this.provider,
    required this.updatedAt,
    required this.rates,
  });

  final String baseCode;
  final String provider;
  final DateTime? updatedAt;
  final Map<String, double> rates;

  factory CurrencyRatesSnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> ratesJson = _asJsonMap(json['rates']);
    return CurrencyRatesSnapshot(
      baseCode: (json['base_code'] ?? json['baseCode'] ?? 'USD')
          .toString()
          .trim()
          .toUpperCase(),
      provider: (json['provider'] ?? '').toString().trim(),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
      rates: ratesJson.map<String, double>((String key, dynamic value) {
        final double parsed = value is num
            ? value.toDouble()
            : double.parse(value.toString());
        return MapEntry(key.toUpperCase(), parsed);
      }),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'base_code': baseCode,
    'provider': provider,
    'updated_at': updatedAt?.toIso8601String(),
    'rates': rates,
  };

  double? rateFor(String code) => rates[code.toUpperCase()];
}

class CurrencyCacheRecord {
  const CurrencyCacheRecord({
    required this.selectedCode,
    required this.snapshot,
  });

  final String selectedCode;
  final CurrencyRatesSnapshot snapshot;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'selected_code': selectedCode,
    'snapshot': snapshot.toJson(),
  };

  factory CurrencyCacheRecord.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> snapshotJson = _asJsonMap(json['snapshot']);
    return CurrencyCacheRecord(
      selectedCode: (json['selected_code'] ?? 'VND')
          .toString()
          .trim()
          .toUpperCase(),
      snapshot: CurrencyRatesSnapshot.fromJson(snapshotJson),
    );
  }
}

class CurrencyRatesException implements Exception {
  const CurrencyRatesException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class CurrencyAccountStore {
  Future<String?> loadSelectedCurrency(String userId);

  Future<void> saveSelectedCurrency(String userId, String currencyCode);
}

class SupabaseCurrencyAccountStore implements CurrencyAccountStore {
  SupabaseCurrencyAccountStore({
    SupabaseClient? client,
    SupabaseTableClient? tableClient,
  }) : _clientOverride = client,
       _tableClient = tableClient;

  final SupabaseClient? _clientOverride;
  final SupabaseTableClient? _tableClient;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  SupabaseTableClient get _resolvedTableClient =>
      _tableClient ?? const SupabaseTableClient();

  @override
  Future<String?> loadSelectedCurrency(String userId) async {
    try {
      final Map<String, dynamic>? accountRow = await _resolvedTableClient
          .maybeSingle('user account currency', () async {
            return _client
                .from('user_account')
                .select('currency')
                .eq('id_user', userId)
                .maybeSingle();
          });
      final String? accountCurrency = _normalizeCurrencyCode(
        accountRow?['currency']?.toString(),
      );
      if (accountCurrency != null) {
        return accountCurrency;
      }
    } catch (_) {
      // Fall through to user_setting and local cache.
    }

    try {
      final Map<String, dynamic>? settingRow = await _resolvedTableClient
          .maybeSingle('user setting currency', () async {
            return _client
                .from('user_setting')
                .select('currency')
                .eq('id_user', userId)
                .maybeSingle();
          });
      return _normalizeCurrencyCode(settingRow?['currency']?.toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSelectedCurrency(String userId, String currencyCode) async {
    await _client.from('user_account').upsert(<String, dynamic>{
      'id_user': userId,
      'currency': currencyCode,
    });
  }
}

class CurrencyRatesGateway {
  CurrencyRatesGateway({
    http.Client? client,
    Future<String?> Function()? accessTokenProvider,
    Duration requestTimeout = const Duration(seconds: 20),
    EdgeFunctionClient? edgeFunctionClient,
  }) : _edgeFunctionClient =
           edgeFunctionClient ??
           EdgeFunctionClient(
             client: client,
             accessTokenProvider:
                 accessTokenProvider ?? _defaultAccessTokenProvider,
             requestTimeout: requestTimeout,
           );

  final EdgeFunctionClient _edgeFunctionClient;

  Future<CurrencyRatesSnapshot> fetchRates({
    String baseCode = 'USD',
    List<String> symbols = const <String>[],
  }) async {
    try {
      final Map<String, dynamic> json = await _edgeFunctionClient.postJson(
        Env.currencyRatesFunction,
        body: <String, Object?>{'base': baseCode, 'symbols': symbols},
      );
      return CurrencyRatesSnapshot.fromJson(json);
    } on EdgeFunctionException catch (error) {
      throw CurrencyRatesException(error.message);
    }
  }

  static Future<String?> _defaultAccessTokenProvider() async {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }
}

class CurrencyRepository extends ChangeNotifier {
  CurrencyRepository({
    CurrencyRatesGateway? gateway,
    CurrencyAccountStore? accountStore,
    SupabaseClient? client,
  }) : _gateway = gateway ?? CurrencyRatesGateway(),
       _accountStore =
           accountStore ??
           SupabaseCurrencyAccountStore(
             client: client ?? Supabase.instance.client,
           ),
       _client = client ?? Supabase.instance.client {
    AuthRepository.instance.addListener(_handleAuthChanged);
  }

  static final CurrencyRepository instance = CurrencyRepository();

  static const String _defaultCurrencyCode = 'VND';
  static const List<CurrencyCatalogEntry> supportedCurrencies =
      <CurrencyCatalogEntry>[
        CurrencyCatalogEntry(
          code: 'USD',
          name: 'US Dollar',
          symbol: '\$',
          flagCode: 'us',
        ),
        CurrencyCatalogEntry(
          code: 'VND',
          name: 'Vietnamese Dong',
          symbol: '₫',
          flagCode: 'vn',
        ),
        CurrencyCatalogEntry(
          code: 'EUR',
          name: 'Euro',
          symbol: '€',
          flagCode: 'eu',
        ),
        CurrencyCatalogEntry(
          code: 'GBP',
          name: 'British Pound',
          symbol: '£',
          flagCode: 'gb',
        ),
        CurrencyCatalogEntry(
          code: 'JPY',
          name: 'Japanese Yen',
          symbol: '¥',
          flagCode: 'jp',
        ),
        CurrencyCatalogEntry(
          code: 'CNY',
          name: 'Chinese Yuan',
          symbol: '¥',
          flagCode: 'cn',
        ),
        CurrencyCatalogEntry(
          code: 'KRW',
          name: 'South Korean Won',
          symbol: '₩',
          flagCode: 'kr',
        ),
        CurrencyCatalogEntry(
          code: 'AUD',
          name: 'Australian Dollar',
          symbol: 'A\$',
          flagCode: 'au',
        ),
        CurrencyCatalogEntry(
          code: 'CAD',
          name: 'Canadian Dollar',
          symbol: 'C\$',
          flagCode: 'ca',
        ),
        CurrencyCatalogEntry(
          code: 'CHF',
          name: 'Swiss Franc',
          symbol: 'Fr',
          flagCode: 'ch',
        ),
        CurrencyCatalogEntry(
          code: 'SGD',
          name: 'Singapore Dollar',
          symbol: 'S\$',
          flagCode: 'sg',
        ),
        CurrencyCatalogEntry(
          code: 'HKD',
          name: 'Hong Kong Dollar',
          symbol: 'HK\$',
          flagCode: 'hk',
        ),
        CurrencyCatalogEntry(
          code: 'INR',
          name: 'Indian Rupee',
          symbol: '₹',
          flagCode: 'in',
        ),
        CurrencyCatalogEntry(
          code: 'THB',
          name: 'Thai Baht',
          symbol: '฿',
          flagCode: 'th',
        ),
        CurrencyCatalogEntry(
          code: 'MYR',
          name: 'Malaysian Ringgit',
          symbol: 'RM',
          flagCode: 'my',
        ),
        CurrencyCatalogEntry(
          code: 'IDR',
          name: 'Indonesian Rupiah',
          symbol: 'Rp',
          flagCode: 'id',
        ),
        CurrencyCatalogEntry(
          code: 'PHP',
          name: 'Philippine Peso',
          symbol: '₱',
          flagCode: 'ph',
        ),
        CurrencyCatalogEntry(
          code: 'RUB',
          name: 'Russian Ruble',
          symbol: '₽',
          flagCode: 'ru',
        ),
        CurrencyCatalogEntry(
          code: 'BRL',
          name: 'Brazilian Real',
          symbol: 'R\$',
          flagCode: 'br',
        ),
        CurrencyCatalogEntry(
          code: 'MXN',
          name: 'Mexican Peso',
          symbol: 'Mex\$',
          flagCode: 'mx',
        ),
      ];

  final CurrencyRatesGateway _gateway;
  final CurrencyAccountStore _accountStore;
  final SupabaseClient _client;

  bool _isReady = false;
  bool _isRefreshing = false;
  bool _isSavingSelection = false;
  String? _selectedCurrencyCode;
  CurrencyRatesSnapshot? _snapshot;
  String? _lastError;

  bool get isReady => _isReady;
  bool get isRefreshing => _isRefreshing;
  bool get isSavingSelection => _isSavingSelection;
  String? get lastError => _lastError;
  String get selectedCurrencyCode =>
      _selectedCurrencyCode ?? _defaultCurrencyCode;
  CurrencyRatesSnapshot? get snapshot => _snapshot;
  bool get isUsingCache => _lastError != null && _snapshot != null;

  CurrencyCatalogEntry catalogEntryFor(String code) {
    return supportedCurrencies.firstWhere(
      (CurrencyCatalogEntry entry) => entry.code == code.toUpperCase(),
      orElse: () => supportedCurrencies.first,
    );
  }

  List<CurrencyOptionViewModel> get options => supportedCurrencies
      .map(
        (CurrencyCatalogEntry entry) => CurrencyOptionViewModel(
          entry: entry,
          rate: _snapshot?.rateFor(entry.code),
          selected: entry.code == selectedCurrencyCode,
        ),
      )
      .toList(growable: false);

  Future<void> initialize() async {
    if (_isReady) return;
    await app_storage.LocalStorage.instance.initialize();
    _isReady = true;
    await _restoreCachedState();
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (!_isReady || _isRefreshing) return;
    _isRefreshing = true;
    _lastError = null;
    notifyListeners();

    try {
      final CurrencyRatesSnapshot remoteSnapshot = await _gateway.fetchRates(
        baseCode: 'USD',
        symbols: supportedCurrencies
            .map((CurrencyCatalogEntry entry) => entry.code)
            .toList(growable: false),
      );
      _snapshot = remoteSnapshot;
      await _persistCachedState();
    } on Object catch (error) {
      _lastError = error.toString();
      await _restoreCachedSnapshot();
    }

    try {
      final String? remoteCode = await _loadRemoteCurrencyCode();
      if (remoteCode != null) {
        _selectedCurrencyCode = remoteCode;
        await _persistCachedState();
      }
    } catch (_) {
      _selectedCurrencyCode ??=
          _readCachedSelectedCode() ?? _defaultCurrencyCode;
    }

    _selectedCurrencyCode ??= _readCachedSelectedCode() ?? _defaultCurrencyCode;
    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> selectCurrency(String currencyCode) async {
    final String? normalizedCode = _normalizeCurrencyCode(currencyCode);
    if (normalizedCode == null) {
      throw CurrencyRatesException('Invalid currency code.');
    }
    if (supportedCurrencies.indexWhere(
          (CurrencyCatalogEntry entry) => entry.code == normalizedCode,
        ) ==
        -1) {
      throw CurrencyRatesException('Unsupported currency: $normalizedCode');
    }

    _selectedCurrencyCode = normalizedCode;
    _isSavingSelection = true;
    _lastError = null;
    notifyListeners();

    await _persistCachedState();

    final String? userId = _currentUserId;
    if (userId != null) {
      try {
        await _accountStore.saveSelectedCurrency(userId, normalizedCode);
      } catch (error) {
        _lastError = error.toString();
      }
    }

    _isSavingSelection = false;
    notifyListeners();
  }

  Future<void> _restoreCachedState() async {
    final CurrencyCacheRecord? cached = _readCachedRecord();
    if (cached != null) {
      _selectedCurrencyCode = cached.selectedCode;
      _snapshot = cached.snapshot;
      return;
    }

    _selectedCurrencyCode = _readCachedSelectedCode() ?? _defaultCurrencyCode;
  }

  Future<void> _restoreCachedSnapshot() async {
    final CurrencyCacheRecord? cached = _readCachedRecord();
    if (cached != null) {
      _snapshot = cached.snapshot;
      _selectedCurrencyCode = cached.selectedCode;
      return;
    }
    _snapshot ??= CurrencyRatesSnapshot(
      baseCode: 'USD',
      provider: 'cache',
      updatedAt: null,
      rates: <String, double>{},
    );
  }

  Future<void> _persistCachedState() async {
    final CurrencyCacheRecord record = CurrencyCacheRecord(
      selectedCode: selectedCurrencyCode,
      snapshot:
          _snapshot ??
          CurrencyRatesSnapshot(
            baseCode: 'USD',
            provider: 'cache',
            updatedAt: null,
            rates: <String, double>{},
          ),
    );
    await app_storage.LocalStorage.instance.setString(
      _storageKeyForUser(_currentCacheUserId),
      jsonEncode(record.toJson()),
    );
  }

  CurrencyCacheRecord? _readCachedRecord() {
    final String? raw = app_storage.LocalStorage.instance.getString(
      _storageKeyForUser(_currentCacheUserId),
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return CurrencyCacheRecord.fromJson(
        Map<String, dynamic>.from(decoded.cast<String, dynamic>()),
      );
    } catch (_) {
      return null;
    }
  }

  String? _readCachedSelectedCode() => _readCachedRecord()?.selectedCode;

  Future<String?> _loadRemoteCurrencyCode() async {
    final String? userId = _currentUserId;
    if (userId == null) return null;
    return _accountStore.loadSelectedCurrency(userId);
  }

  String? get _currentUserId =>
      _client.auth.currentUser?.id ?? AuthRepository.instance.user?.id;

  String get _currentCacheUserId => _currentUserId ?? 'guest';

  String _storageKeyForUser(String userId) => 'currency_state_v1_$userId';

  void _handleAuthChanged() {
    if (!_isReady) return;
    unawaited(refresh());
  }
}

class CurrencyOptionViewModel {
  const CurrencyOptionViewModel({
    required this.entry,
    required this.rate,
    required this.selected,
  });

  final CurrencyCatalogEntry entry;
  final double? rate;
  final bool selected;

  String get title => '${entry.code} - ${entry.symbol}';

  String get subtitle => entry.name;

  String get rateLabel {
    if (rate == null) return 'Live rate unavailable';
    return '1 USD = ${_formatRate(rate!)} ${entry.code}';
  }
}

String? _normalizeCurrencyCode(String? value) {
  final String code = value?.trim().toUpperCase() ?? '';
  return code.isEmpty ? null : code;
}

String _formatRate(double value) {
  if (value >= 1000) return value.toStringAsFixed(0);
  if (value >= 100) return value.toStringAsFixed(1);
  if (value >= 1) return value.toStringAsFixed(2);
  if (value >= 0.1) return value.toStringAsFixed(3);
  return value.toStringAsFixed(4);
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic> _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (Object? key, Object? innerValue) => MapEntry(key.toString(), innerValue),
    );
  }
  return <String, dynamic>{};
}
