import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:fixitzed_app/services/home_service.dart';

/// Cache for service catalog lists.
class ServicesRepository {
  ServicesRepository(this._api);

  final HomeService _api;

  List<dynamic>? _cache;
  DateTime? _lastFetch;
  bool _isFetching = false;
  static const _ttl = Duration(minutes: 10);
  static const _minRefreshGap = Duration(seconds: 30);

  List<dynamic>? get cached => _cache == null ? null : List<dynamic>.from(_cache!);
  DateTime? get lastFetch => _lastFetch;
  bool get isFetching => _isFetching;

  List<dynamic> getCachedServices() {
    return _cache == null ? <dynamic>[] : List<dynamic>.from(_cache!);
  }

  bool _isStale() {
    final fetchedAt = _lastFetch;
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > _ttl;
  }

  Future<List<dynamic>> refreshServices({bool silent = true}) async {
    final now = DateTime.now();
    if (_isFetching) return getCachedServices();
    if (_lastFetch != null &&
        now.difference(_lastFetch!) < _minRefreshGap) {
      return getCachedServices();
    }
    _isFetching = true;
    try {
      final data = await _api.fetchServices(forceRefresh: true);
      if (data.isNotEmpty) {
        _cache = List<dynamic>.from(data);
        _lastFetch = DateTime.now();
        return List<dynamic>.from(_cache!);
      }
      _logEmpty('refresh');
    } catch (_) {}
    finally {
      _isFetching = false;
    }
    return getCachedServices();
  }

  Future<List<dynamic>> getServices({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null && !_isStale()) {
      return List<dynamic>.from(_cache!);
    }
    if (_isFetching) {
      return getCachedServices();
    }
    _isFetching = true;
    try {
      final data = await _api.fetchServices(forceRefresh: forceRefresh);
      if (data.isNotEmpty) {
        _cache = List<dynamic>.from(data);
        _lastFetch = DateTime.now();
        return List<dynamic>.from(_cache!);
      }
      _logEmpty('getServices');
    } catch (_) {}
    finally {
      _isFetching = false;
    }
    return _cache == null ? <dynamic>[] : List<dynamic>.from(_cache!);
  }

  void _logEmpty(String phase) {
    if (!kDebugMode) return;
    debugPrint('ServicesRepository: $phase returned an empty list from API');
  }
}
