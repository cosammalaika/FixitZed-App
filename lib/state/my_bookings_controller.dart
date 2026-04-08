import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/state/app_sync.dart';

class MyBookingsState {
  const MyBookingsState({
    this.requests = const <Map<String, dynamic>>[],
    this.payments = const <int, Map<String, dynamic>>{},
  });

  final List<Map<String, dynamic>> requests;
  final Map<int, Map<String, dynamic>> payments;
}

class MyBookingsController extends AsyncNotifier<MyBookingsState> {
  bool _syncRegistered = false;
  Future<void>? _refreshInFlight;
  DateTime? _lastRefreshAt;
  static const Duration _minRefreshGap = Duration(seconds: 10);

  @override
  FutureOr<MyBookingsState> build() {
    _registerSync();
    final cached = _initialFromCache();
    if (cached.requests.isEmpty) {
      return _fetch(forceRefresh: false);
    }
    unawaited(_refresh());
    return cached;
  }

  Future<void> refresh() async {
    await _refresh(force: true);
  }

  Future<void> _refresh({bool force = false}) async {
    final existing = _refreshInFlight;
    if (existing != null) {
      await existing;
      return;
    }

    if (!force &&
        _lastRefreshAt != null &&
        DateTime.now().difference(_lastRefreshAt!) < _minRefreshGap) {
      return;
    }

    final future = _runRefresh(force: force);
    _refreshInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<void> _runRefresh({required bool force}) async {
    final previous = state.asData?.value ?? _initialFromCache();
    if (previous.requests.isEmpty) {
      state = const AsyncValue<MyBookingsState>.loading();
    }

    try {
      final next = await _fetch(forceRefresh: force);
      _lastRefreshAt = DateTime.now();
      state = AsyncValue<MyBookingsState>.data(next);
    } catch (error, stackTrace) {
      if (previous.requests.isNotEmpty) {
        state = AsyncValue<MyBookingsState>.data(previous);
        return;
      }
      state = AsyncValue<MyBookingsState>.error(error, stackTrace);
    }
  }

  Future<MyBookingsState> _fetch({bool forceRefresh = true}) async {
    final bookingsRepo = ref.read(bookingsRepositoryProvider);

    final requests = await bookingsRepo.getRequests(forceRefresh: forceRefresh);
    final normalizedRequests = requests
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final ids = normalizedRequests
        .map((request) => (request['id'] as num?)?.toInt())
        .whereType<int>();
    final payments = await bookingsRepo.getPaymentsForRequests(
      ids,
      forceRefresh: forceRefresh,
    );

    return MyBookingsState(requests: normalizedRequests, payments: payments);
  }

  void _registerSync() {
    if (_syncRegistered) return;
    _syncRegistered = true;

    Future<void> handle(AppSyncEvent _) => refresh();

    ref.onAppSync(AppSyncTopic.bookings, handle);
    ref.onAppSync(AppSyncTopic.wallet, handle);
  }

  MyBookingsState _initialFromCache() {
    final bookingsRepo = ref.read(bookingsRepositoryProvider);
    final requests =
        bookingsRepo.cachedRequests ?? const <Map<String, dynamic>>[];
    return MyBookingsState(requests: requests);
  }
}

final myBookingsControllerProvider =
    AsyncNotifierProvider<MyBookingsController, MyBookingsState>(
      MyBookingsController.new,
    );
