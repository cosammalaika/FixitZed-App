import 'package:fixitzed_app/services/home_service.dart';

/// Lightweight cache around the user profile (/api/me).
class ProfileRepository {
  ProfileRepository(this._api);

  final HomeService _api;

  Map<String, dynamic>? _cache;
  DateTime? _lastFetch;
  static const _ttl = Duration(minutes: 10);

  Map<String, dynamic>? get cached => _cache == null
      ? null
      : Map<String, dynamic>.from(_cache!);

  bool _isStale() {
    final fetchedAt = _lastFetch;
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > _ttl;
  }

  Future<Map<String, dynamic>?> getProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null && !_isStale()) {
      return cached;
    }
    try {
      final data = await _api.fetchMe();
      if (data != null) {
        _cache = Map<String, dynamic>.from(data);
        _lastFetch = DateTime.now();
        return cached;
      }
    } catch (_) {}
    return cached;
  }
}
