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

class MyBookingsController extends AutoDisposeAsyncNotifier<MyBookingsState> {
  bool _syncRegistered = false;

  @override
  FutureOr<MyBookingsState> build() {
    _registerSync();
    final cached = _initialFromCache();
    unawaited(_refresh(fromCache: cached));
    return cached;
  }

  Future<void> refresh() async {
    state = const AsyncValue<MyBookingsState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> _refresh({MyBookingsState? fromCache}) async {
    if (fromCache != null) {
      state = AsyncValue<MyBookingsState>.data(fromCache)
          .copyWithPrevious(state);
    }
    state = await AsyncValue.guard(_fetch);
  }

  Future<MyBookingsState> _fetch() async {
    final bookingsRepo = ref.read(bookingsRepositoryProvider);

    final requests = await bookingsRepo.getRequests(forceRefresh: true);
    final normalizedRequests = requests
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final payments = <int, Map<String, dynamic>>{};
    for (final r in normalizedRequests) {
      final id = (r['id'] as num?)?.toInt();
      if (id == null) continue;
      try {
        final payment = await bookingsRepo.getPayment(id);
        if (payment != null) {
          payments[id] = Map<String, dynamic>.from(payment);
        }
      } catch (_) {
        // ignore failures for individual payments
      }
    }

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
    AutoDisposeAsyncNotifierProvider<MyBookingsController, MyBookingsState>(
      MyBookingsController.new,
    );
