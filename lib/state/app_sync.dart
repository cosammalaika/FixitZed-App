import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Topic-tagged event pushed whenever data mutations occur in the app.
class AppSyncEvent {
  AppSyncEvent(this.topic, {this.payload})
      : timestamp = DateTime.now().toUtc();

  final String topic;
  final Object? payload;
  final DateTime timestamp;
}

/// Simple event hub used to fan out mutation signals across the app.
class AppSync {
  AppSync._internal();

  static final AppSync instance = AppSync._internal();

  factory AppSync() => instance;

  final _controller = StreamController<AppSyncEvent>.broadcast();

  /// Emit a new sync event for a given [topic].
  void emit(String topic, {Object? payload}) {
    if (_controller.isClosed) return;
    _controller.add(AppSyncEvent(topic, payload: payload));
  }

  /// Listen for sync events on a [topic].
  Stream<AppSyncEvent> on(String topic) =>
      _controller.stream.where((event) => event.topic == topic);

  /// No-op for singleton lifecycle compatibility.
  void dispose() {}
}

final appSyncProvider = Provider<AppSync>((ref) {
  return AppSync.instance;
});

/// Commonly used sync topics.
class AppSyncTopic {
  AppSyncTopic._();

  static const dashboard = 'dashboard';
  static const profile = 'profile';
  static const notifications = 'notifications';
  static const bookings = 'bookings';
  static const wallet = 'wallet';
}

extension AppSyncRef on Ref {
  /// Register a callback that runs each time [topic] emits a new event.
  void onAppSync(
    String topic,
    FutureOr<void> Function(AppSyncEvent event) handler,
  ) {
    final sync = read(appSyncProvider);
    final subscription = sync.on(topic).listen((event) {
      final result = handler(event);
      if (result is Future<void>) {
        unawaited(result);
      }
    });
    onDispose(subscription.cancel);
  }

  /// Trigger a sync event for the provided [topic].
  void triggerAppSync(String topic, {Object? payload}) {
    read(appSyncProvider).emit(topic, payload: payload);
  }
}
