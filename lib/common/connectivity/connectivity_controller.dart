import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/legacy.dart';

final connectivityProvider =
    StateNotifierProvider<ConnectivityController, ConnectivityStatus>((ref) {
  return ConnectivityController(Connectivity());
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
    _subscription = _connectivity.onConnectivityChanged.listen(_setStatus);
  }

  void _setStatus(List<ConnectivityResult> results) {
    final primary = results.isNotEmpty ? results.first : ConnectivityResult.none;
    final online = results.any((result) => result != ConnectivityResult.none);
    state = state.copyWith(isOnline: online, result: primary);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
