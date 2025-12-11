import 'package:fixitzed_app/services/home_service.dart';

/// Cache for service catalog lists.
class ServicesRepository {
  ServicesRepository(this._api);

  final HomeService _api;

  List<dynamic>? _cache;
  DateTime? _lastFetch;
  static const _ttl = Duration(minutes: 10);

  List<dynamic>? get cached => _cache == null ? null : List<dynamic>.from(_cache!);

  bool _isStale() {
    final fetchedAt = _lastFetch;
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > _ttl;
  }

  Future<List<dynamic>> getServices({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null && !_isStale()) {
      return List<dynamic>.from(_cache!);
    }
    try {
      final data = await _api.fetchServices(forceRefresh: forceRefresh);
      if (data.isNotEmpty) {
        _cache = List<dynamic>.from(data);
        _lastFetch = DateTime.now();
        return List<dynamic>.from(_cache!);
      }
    } catch (_) {}
    return _cache == null ? <dynamic>[] : List<dynamic>.from(_cache!);
  }
}
