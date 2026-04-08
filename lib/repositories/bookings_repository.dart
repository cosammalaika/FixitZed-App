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
  Future<List<Map<String, dynamic>>>? _requestsInFlight;

  final Map<int, Map<String, dynamic>> _paymentsCache = {};
  final Map<int, DateTime> _paymentFetchedAt = {};
  final Map<int, Future<Map<String, dynamic>?>> _paymentsInFlight = {};
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
    final existing = _requestsInFlight;
    if (existing != null) {
      return existing;
    }

    final future = _loadRequestsFromNetwork();
    _requestsInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_requestsInFlight, future)) {
        _requestsInFlight = null;
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadRequestsFromNetwork() async {
    try {
      final data = await _requestsApi.listRequests();
      _cache = List<Map<String, dynamic>>.from(data);
      _lastFetch = DateTime.now();
      return List<Map<String, dynamic>>.from(_cache!);
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

    final existing = _paymentsInFlight[requestId];
    if (existing != null) {
      return existing;
    }

    final future = _loadPaymentFromNetwork(requestId, cached);
    _paymentsInFlight[requestId] = future;
    try {
      return await future;
    } finally {
      if (identical(_paymentsInFlight[requestId], future)) {
        final _ = _paymentsInFlight.remove(requestId);
      }
    }
  }

  Future<Map<String, dynamic>?> _loadPaymentFromNetwork(
    int requestId,
    Map<String, dynamic>? cached,
  ) async {
    try {
      final data = await _paymentApi.get(requestId);
      if (data != null) {
        final normalized = Map<String, dynamic>.from(data);
        _paymentsCache[requestId] = normalized;
        _paymentFetchedAt[requestId] = DateTime.now();
        return Map<String, dynamic>.from(normalized);
      }
    } catch (_) {}
    return cached == null ? null : Map<String, dynamic>.from(cached);
  }

  Future<Map<int, Map<String, dynamic>>> getPaymentsForRequests(
    Iterable<int> requestIds, {
    bool forceRefresh = false,
  }) async {
    final ids = requestIds.toSet();
    if (ids.isEmpty) return const <int, Map<String, dynamic>>{};

    final payments = await Future.wait(
      ids.map((id) async {
        final payment = await getPayment(id, forceRefresh: forceRefresh);
        return MapEntry<int, Map<String, dynamic>?>(id, payment);
      }),
    );

    final result = <int, Map<String, dynamic>>{};
    for (final entry in payments) {
      final payment = entry.value;
      if (payment != null) {
        result[entry.key] = Map<String, dynamic>.from(payment);
      }
    }
    return result;
  }

  void clearCache() {
    _cache = null;
    _lastFetch = null;
    _requestsInFlight = null;
    _paymentsCache.clear();
    _paymentFetchedAt.clear();
    _paymentsInFlight.clear();
  }
}
