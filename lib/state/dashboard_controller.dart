import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/dashboard_snapshot.dart';
import '../data/repositories/dashboard_repository.dart';
import 'repository_providers.dart';

class DashboardController extends StateNotifier<AsyncValue<DashboardSnapshot>> {
  DashboardController(this._repository)
      : super(const AsyncValue<DashboardSnapshot>.loading()) {
    refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      refresh(silent: true);
    });
  }

  final DashboardRepository _repository;
  Timer? _timer;

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = const AsyncValue<DashboardSnapshot>.loading();
    }

    final result = await AsyncValue.guard<DashboardSnapshot>(
      _repository.fetchDashboard,
    );
    state = result;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, AsyncValue<DashboardSnapshot>>((
      ref,
    ) {
      final repository = ref.read(dashboardRepositoryProvider);
      final controller = DashboardController(repository);
      ref.onDispose(controller.dispose);
      return controller;
    });
