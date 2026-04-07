import 'dart:convert';

import 'package:fixitzed_app/services/home_service.dart';
import 'package:fixitzed_app/services/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight cache around the user profile (/api/me).
class ProfileRepository {
  ProfileRepository(this._api);

  final HomeService _api;

  Map<String, dynamic>? _cache;
  DateTime? _lastFetch;
  static const _ttl = Duration(minutes: 10);
  static const _cacheStorageKey = 'profile_repository.me_cache';
  static const _cacheFetchedAtKey = 'profile_repository.me_cache_fetched_at';
  bool _hydratedFromStorage = false;
  Future<void>? _hydrateFuture;

  Map<String, dynamic>? get cached =>
      _cache == null ? null : Map<String, dynamic>.from(_cache!);

  bool _isStale() {
    final fetchedAt = _lastFetch;
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > _ttl;
  }

  Future<Map<String, dynamic>?> getProfile({bool forceRefresh = false}) async {
    final token = await TokenStorage.instance.getToken();
    if (token == null || token.isEmpty) {
      await clearCache();
      return null;
    }

    await _ensureHydrated();

    if (!forceRefresh && _cache != null && !_isStale()) {
      return cached;
    }
    try {
      final data = await _api.fetchMe();
      if (data != null) {
        _cache = Map<String, dynamic>.from(data);
        _lastFetch = DateTime.now();
        await _persistCache();
        return cached;
      }
    } catch (_) {}
    return cached;
  }

  Future<void> clearCache() async {
    _cache = null;
    _lastFetch = null;
    _hydratedFromStorage = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheStorageKey);
      await prefs.remove(_cacheFetchedAtKey);
    } catch (_) {}
  }

  Future<void> _ensureHydrated() async {
    if (_hydratedFromStorage) return;
    final existing = _hydrateFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final future = _hydrateFromStorage();
    _hydrateFuture = future;
    try {
      await future;
    } finally {
      _hydrateFuture = null;
    }
  }

  Future<void> _hydrateFromStorage() async {
    if (_hydratedFromStorage) return;
    _hydratedFromStorage = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_cacheStorageKey);
      if (rawJson != null && rawJson.trim().isNotEmpty) {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          _cache = decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      }
      final fetchedAtMs = prefs.getInt(_cacheFetchedAtKey);
      if (fetchedAtMs != null && fetchedAtMs > 0) {
        _lastFetch = DateTime.fromMillisecondsSinceEpoch(fetchedAtMs);
      }
    } catch (_) {
      // Ignore storage decode errors and fall back to network/cache miss.
    }
  }

  Future<void> _persistCache() async {
    final cache = _cache;
    if (cache == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheStorageKey, jsonEncode(cache));
      await prefs.setInt(
        _cacheFetchedAtKey,
        (_lastFetch ?? DateTime.now()).millisecondsSinceEpoch,
      );
    } catch (_) {
      // Ignore persistence failures; in-memory cache is still usable.
    }
  }
}
