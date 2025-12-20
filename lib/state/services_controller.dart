import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:fixitzed_app/repositories/services_repository.dart';

/// Bridges ServicesRepository to the UI with lifecycle-aware foreground sync.
class ServicesController extends ChangeNotifier with WidgetsBindingObserver {
  ServicesController(this._repo) {
    WidgetsBinding.instance.addObserver(this);
  }

  final ServicesRepository _repo;
  Timer? _syncTimer;

  List<dynamic> get cached => _repo.getCachedServices();
  DateTime? get lastFetch => _repo.lastFetch;
  bool get isFetching => _repo.isFetching;

  Future<List<dynamic>> getServices({bool forceRefresh = false}) async {
    final before = _repo.lastFetch;
    final result = await _repo.getServices(forceRefresh: forceRefresh);
    if (before != _repo.lastFetch) notifyListeners();
    return result;
  }

  Future<List<dynamic>> refresh({bool silent = true}) async {
    final before = _repo.lastFetch;
    final result = await _repo.refreshServices(silent: silent);
    if (before != _repo.lastFetch) notifyListeners();
    return result;
  }

  void startForegroundSync({Duration interval = const Duration(seconds: 45)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) {
      refresh(silent: true);
    });
    refresh(silent: true);
  }

  void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startForegroundSync();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      stopSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopSync();
    super.dispose();
  }
}
