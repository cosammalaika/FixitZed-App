import 'package:fixitzed_app/services/notification_service.dart';
import 'package:fixitzed_app/services/token_storage.dart';

/// Cache for notifications page 1.
class NotificationsRepository {
  NotificationsRepository(this._api);

  final NotificationService _api;

  List<Map<String, dynamic>>? _cache;
  DateTime? _lastFetch;
  static const _ttl = Duration(minutes: 5);

  List<Map<String, dynamic>>? get cached =>
      _cache == null ? null : List<Map<String, dynamic>>.from(_cache!);

  bool _isStale() {
    final fetchedAt = _lastFetch;
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > _ttl;
  }

  Future<List<Map<String, dynamic>>> getNotifications({
    bool forceRefresh = false,
  }) async {
    final token = await TokenStorage.instance.getToken();
    if (token == null || token.isEmpty) {
      clearCache();
      return <Map<String, dynamic>>[];
    }

    if (!forceRefresh && _cache != null && !_isStale()) {
      return List<Map<String, dynamic>>.from(_cache!);
    }
    try {
      final data = await _api.fetch(page: 1);
      if (data.isNotEmpty) {
        _cache = List<Map<String, dynamic>>.from(data);
        _lastFetch = DateTime.now();
        return List<Map<String, dynamic>>.from(_cache!);
      }
    } catch (_) {}
    return _cache == null
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(_cache!);
  }

  void clearCache() {
    _cache = null;
    _lastFetch = null;
  }
}
