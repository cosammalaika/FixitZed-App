import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider =
    StateNotifierProvider<ConnectivityController, ConnectivityStatus>((ref) {
  final controller = ConnectivityController(Connectivity());
  ref.onDispose(controller.dispose);
  return controller;
});

class ConnectivityStatus {
  const ConnectivityStatus({
    required this.isOnline,
    required this.result,
  });

  final bool isOnline;
  final ConnectivityResult result;

  ConnectivityStatus copyWith({
    bool? isOnline,
    ConnectivityResult? result,
  }) {
    return ConnectivityStatus(
      isOnline: isOnline ?? this.isOnline,
      result: result ?? this.result,
    );
  }
}

class ConnectivityController extends StateNotifier<ConnectivityStatus> {
  ConnectivityController(this._connectivity)
      : super(const ConnectivityStatus(
          isOnline: true,
          result: ConnectivityResult.other,
        )) {
    _init();
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> _init() async {
    final initial = await _connectivity.checkConnectivity();
    _setStatus(initial);
    _subscription =
        _connectivity.onConnectivityChanged.listen(_setStatus);
  }

  void _setStatus(dynamic results) {
    final list = results is List<ConnectivityResult>
        ? results
        : results is ConnectivityResult
            ? <ConnectivityResult>[results]
            : const <ConnectivityResult>[];
    final primary =
        list.isNotEmpty ? list.first : ConnectivityResult.none;
    final online = list.any((r) => r != ConnectivityResult.none);
    state = state.copyWith(isOnline: online, result: primary);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
