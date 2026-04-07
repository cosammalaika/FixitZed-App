import 'package:fixitzed_app/services/payment_service.dart';
import 'package:fixitzed_app/services/service_request_service.dart';
import 'package:fixitzed_app/services/token_storage.dart';

/// Cache for booking lists and their payments.
class BookingsRepository {
  BookingsRepository(this._requestsApi, this._paymentApi);

  final ServiceRequestService _requestsApi;
  final PaymentService _paymentApi;

  List<Map<String, dynamic>>? _cache;
  DateTime? _lastFetch;
  static const _ttl = Duration(minutes: 5);

  final Map<int, Map<String, dynamic>> _paymentsCache = {};
  final Map<int, DateTime> _paymentFetchedAt = {};
  static const _paymentTtl = Duration(minutes: 10);

  List<Map<String, dynamic>>? get cachedRequests =>
      _cache == null ? null : List<Map<String, dynamic>>.from(_cache!);

  bool _stale(DateTime? fetchedAt, Duration ttl) {
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > ttl;
  }

  Future<List<Map<String, dynamic>>> getRequests({
    bool forceRefresh = false,
  }) async {
    final token = await TokenStorage.instance.getToken();
    if (token == null || token.isEmpty) {
      clearCache();
      return <Map<String, dynamic>>[];
    }

    if (!forceRefresh && _cache != null && !_stale(_lastFetch, _ttl)) {
      return List<Map<String, dynamic>>.from(_cache!);
    }
    try {
      final data = await _requestsApi.listRequests();
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

  Future<Map<String, dynamic>?> getPayment(
    int requestId, {
    bool forceRefresh = false,
  }) async {
    final token = await TokenStorage.instance.getToken();
    if (token == null || token.isEmpty) {
      clearCache();
      return null;
    }

    final cached = _paymentsCache[requestId];
    final fetchedAt = _paymentFetchedAt[requestId];
    if (!forceRefresh && cached != null && !_stale(fetchedAt, _paymentTtl)) {
      return Map<String, dynamic>.from(cached);
    }
    try {
      final data = await _paymentApi.get(requestId);
      if (data != null) {
        _paymentsCache[requestId] = Map<String, dynamic>.from(data);
        _paymentFetchedAt[requestId] = DateTime.now();
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    return cached == null ? null : Map<String, dynamic>.from(cached);
  }

  void clearCache() {
    _cache = null;
    _lastFetch = null;
    _paymentsCache.clear();
    _paymentFetchedAt.clear();
  }
}
