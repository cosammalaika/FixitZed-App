import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:fixitzed_app/repositories/services_repository.dart';
import 'package:fixitzed_app/services/favorites_service.dart';
import 'package:fixitzed_app/services/token_storage.dart';
import 'package:fixitzed_app/utils/service_utils.dart';

/// Local favorites cache backed by SharedPreferences.
class FavoritesRepository extends ChangeNotifier {
  Set<String> _ids = {};
  bool _loaded = false;

  Set<String> get ids => Set.unmodifiable(_ids);

  Future<Set<String>> _ensureLoaded() async {
    final token = await TokenStorage.instance.getToken();
    if (token == null || token.isEmpty) {
      _ids = {};
      _loaded = true;
      await FavoritesService.clear();
      return _ids;
    }

    if (_loaded) return _ids;
    final stored = await FavoritesService.loadSet();
    _ids = stored;
    _loaded = true;
    return _ids;
  }

  Future<Set<String>> getFavoriteIds() async {
    final set = await _ensureLoaded();
    return Set<String>.from(set);
  }

  Future<bool> toggle(String serviceId) async {
    await _ensureLoaded();
    final next = Set<String>.from(_ids);
    final added = !next.remove(serviceId);
    if (added) {
      next.add(serviceId);
    }
    await FavoritesService.setAll(next);
    _ids = next;
    notifyListeners();
    return added;
  }

  Future<List<Map<String, dynamic>>> getFavoriteServices(
    ServicesRepository servicesRepository, {
    bool forceRefresh = false,
  }) async {
    await _ensureLoaded();
    final favIds = _ids;
    if (favIds.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    final services = await servicesRepository.getServices(
      forceRefresh: forceRefresh,
    );
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < services.length; i++) {
      final s = services[i];
      if (s is! Map) continue;
      final id = serviceId(s, fallbackIndex: i);
      if (favIds.contains(id)) {
        result.add(Map<String, dynamic>.from(s));
      }
    }
    return result;
  }

  Future<void> refreshFromStorage() async {
    final latest = await FavoritesService.loadSet();
    _ids = latest;
    _loaded = true;
    notifyListeners();
  }

  Future<void> clearCache() async {
    await FavoritesService.clear();
    _ids = {};
    _loaded = true;
    notifyListeners();
  }
}
