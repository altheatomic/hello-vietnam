import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hellovietnam/core/config/env.dart';
import 'package:hellovietnam/features/item_detail/domain/detail_category.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ExploreTrackingSender =
    Future<void> Function({
      Map<String, String>? headers,
      required Map<String, dynamic> body,
    });

enum ExploreEventType { viewDetail, favorite, unfavorite, share }

class ExploreTrackingService {
  ExploreTrackingService({
    SupabaseClient? client,
    ExploreTrackingSender? sender,
    String? Function()? accessTokenProvider,
    String Function()? requestIdGenerator,
    String functionName = Env.exploreFunction,
  }) : _client = client,
       _functionName = functionName,
       _sender = sender,
       _accessTokenProvider = accessTokenProvider,
       _requestIdGenerator = requestIdGenerator;

  static final ExploreTrackingService instance = ExploreTrackingService();

  final SupabaseClient? _client;
  final String _functionName;
  final ExploreTrackingSender? _sender;
  final String? Function()? _accessTokenProvider;
  final String Function()? _requestIdGenerator;

  Future<void> trackViewDetail({
    required DetailCategory category,
    required String contentId,
    String? provinceId,
  }) {
    return _recordEvent(
      category: category,
      contentId: contentId,
      provinceId: provinceId,
      eventType: ExploreEventType.viewDetail,
    );
  }

  Future<void> trackFavoriteChanged({
    required DetailCategory category,
    required String contentId,
    required bool isFavorite,
    String? provinceId,
  }) {
    return _recordEvent(
      category: category,
      contentId: contentId,
      provinceId: provinceId,
      eventType: isFavorite
          ? ExploreEventType.favorite
          : ExploreEventType.unfavorite,
    );
  }

  Future<void> trackShare({
    required String contentType,
    required String contentId,
    String? provinceId,
  }) {
    return _recordEvent(
      contentType: contentType,
      contentId: contentId,
      provinceId: provinceId,
      eventType: ExploreEventType.share,
    );
  }

  Future<void> _recordEvent({
    DetailCategory? category,
    String? contentType,
    required String contentId,
    required ExploreEventType eventType,
    String? provinceId,
  }) async {
    final String normalizedContentId = contentId.trim();
    if (normalizedContentId.isEmpty) {
      if (kDebugMode) {
        debugPrint('[ExploreTracking] Skip empty contentId for $eventType');
      }
      return;
    }

    final String normalizedContentType =
        _normalizedOrNull(contentType) ??
        (category == null ? '' : _contentTypeForCategory(category));
    if (normalizedContentType.isEmpty) {
      if (kDebugMode) {
        debugPrint('[ExploreTracking] Skip empty contentType for $eventType');
      }
      return;
    }

    final String? accessToken = _accessTokenProvider != null
        ? _accessTokenProvider.call()
        : _client?.auth.currentSession?.accessToken ??
            Supabase.instance.client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[ExploreTracking] Skip ${_eventTypeValue(eventType)} for '
          '$normalizedContentType:$normalizedContentId because no session token was found.',
        );
      }
      return;
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'action': 'recordExploreEvent',
      'contentType': normalizedContentType,
      'contentId': normalizedContentId,
      'provinceId': _normalizedOrNull(provinceId),
      'eventType': _eventTypeValue(eventType),
      'requestId': _requestIdGenerator?.call() ?? _buildRequestId(),
    };

    try {
      final ExploreTrackingSender sender = _sender ?? _defaultSender;
      if (kDebugMode) {
        debugPrint('[ExploreTracking] Sending $body');
      }
      await sender(
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        body: body,
      );
      if (kDebugMode) {
        debugPrint(
          '[ExploreTracking] Sent ${_eventTypeValue(eventType)} for '
          '$normalizedContentType:$normalizedContentId',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Explore tracking failed: $error\n$stackTrace');
    }
  }

  Future<void> _defaultSender({
    Map<String, String>? headers,
    required Map<String, dynamic> body,
  }) async {
    final SupabaseClient client = _client ?? Supabase.instance.client;
    await client.functions.invoke(
      _functionName,
      headers: headers,
      body: body,
    );
  }

  String _buildRequestId() {
    final int micros = DateTime.now().microsecondsSinceEpoch;
    final int random = math.Random().nextInt(1 << 32);
    return 'explore-$micros-$random';
  }

  String _contentTypeForCategory(DetailCategory category) {
    switch (category) {
      case DetailCategory.activities:
        return 'activity';
      case DetailCategory.culture:
        return 'culture';
      case DetailCategory.food:
        return 'food';
      case DetailCategory.localProducts:
        return 'local_product';
    }
  }

  String _eventTypeValue(ExploreEventType eventType) {
    switch (eventType) {
      case ExploreEventType.viewDetail:
        return 'view_detail';
      case ExploreEventType.favorite:
        return 'favorite';
      case ExploreEventType.unfavorite:
        return 'unfavorite';
      case ExploreEventType.share:
        return 'share';
    }
  }

  String? _normalizedOrNull(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
