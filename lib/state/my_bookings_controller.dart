import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service_providers.dart';

class MyBookingsState {
  const MyBookingsState({
    this.requests = const <Map<String, dynamic>>[],
    this.payments = const <int, Map<String, dynamic>>{},
  });

  final List<Map<String, dynamic>> requests;
  final Map<int, Map<String, dynamic>> payments;
}

class MyBookingsController extends AutoDisposeAsyncNotifier<MyBookingsState> {
  @override
  FutureOr<MyBookingsState> build() {
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncValue<MyBookingsState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(_fetch);
  }

  Future<MyBookingsState> _fetch() async {
    final requestService = ref.read(serviceRequestServiceProvider);
    final paymentService = ref.read(paymentServiceProvider);

    final rawList = await requestService.listRequests();
    final requests = rawList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final payments = <int, Map<String, dynamic>>{};
    for (final r in requests) {
      final id = (r['id'] as num?)?.toInt();
      if (id == null) continue;
      try {
        final payment = await paymentService.get(id);
        if (payment != null) {
          payments[id] = Map<String, dynamic>.from(payment);
        }
      } catch (_) {
        // ignore failures for individual payments
      }
    }

    return MyBookingsState(requests: requests, payments: payments);
  }
}

final myBookingsControllerProvider =
    AutoDisposeAsyncNotifierProvider<MyBookingsController, MyBookingsState>(
      MyBookingsController.new,
    );
