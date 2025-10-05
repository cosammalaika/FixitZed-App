import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/bookings_snapshot.dart';
import '../data/repositories/bookings_repository.dart';
import 'repository_providers.dart';

class BookingsController extends StateNotifier<AsyncValue<BookingsSnapshot>> {
  BookingsController(this._repository)
      : super(const AsyncValue<BookingsSnapshot>.loading()) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      refresh(silent: true);
    });
  }

  final BookingsRepository _repository;
  Timer? _timer;

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = const AsyncValue<BookingsSnapshot>.loading();
    }
    final result = await AsyncValue.guard<BookingsSnapshot>(
      _repository.fetchBookings,
    );
    state = result;
  }

  bool hasOutstandingPayments() {
    final value = state.value;
    if (value == null) return false;
    return value.bookings.any((booking) {
      final id = (booking['id'] as num?)?.toInt();
      if (id == null) return false;
      final payment = value.payments[id];
      if (payment == null) return false;
      final status = (payment['status'] ?? '').toString().toLowerCase();
      return status != 'paid';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final bookingsControllerProvider =
    StateNotifierProvider<BookingsController, AsyncValue<BookingsSnapshot>>((
      ref,
    ) {
      final repository = ref.read(bookingsRepositoryProvider);
      final controller = BookingsController(repository);
      ref.onDispose(controller.dispose);
      return controller;
    });
