import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixitzed_app/common/connectivity/connectivity_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityController', () {
    testWidgets('publishes restored online state from connectivity events', (
      WidgetTester tester,
    ) async {
      final client = FakeConnectivityClient([ConnectivityResult.none]);
      final controller = ConnectivityController(
        client,
        reconnectResyncDelay: const Duration(milliseconds: 10),
      );

      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await tester.pump();
      expect(controller.state.isOnline, isFalse);

      client.setCurrentResults([ConnectivityResult.wifi]);
      client.emit([ConnectivityResult.wifi]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 11));

      expect(controller.state.isOnline, isTrue);
      expect(controller.state.result, ConnectivityResult.wifi);
    });

    testWidgets('rechecks connectivity after noisy offline events', (
      WidgetTester tester,
    ) async {
      final client = FakeConnectivityClient([ConnectivityResult.none]);
      final controller = ConnectivityController(
        client,
        reconnectResyncDelay: const Duration(milliseconds: 10),
      );

      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await tester.pump();
      expect(controller.state.isOnline, isFalse);

      client.setCurrentResults([ConnectivityResult.mobile]);
      client.emit([ConnectivityResult.none]);
      await tester.pump(const Duration(milliseconds: 11));

      expect(controller.state.isOnline, isTrue);
      expect(controller.state.result, ConnectivityResult.mobile);
    });

    testWidgets('refreshes connectivity when the app resumes', (
      WidgetTester tester,
    ) async {
      final client = FakeConnectivityClient([ConnectivityResult.none]);
      final controller = ConnectivityController(
        client,
        reconnectResyncDelay: const Duration(milliseconds: 10),
      );

      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await tester.pump();
      expect(controller.state.isOnline, isFalse);

      client.setCurrentResults([ConnectivityResult.wifi]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(controller.state.isOnline, isTrue);
      expect(controller.state.result, ConnectivityResult.wifi);
    });

    testWidgets('does not revert a restored online state with a stale resync', (
      WidgetTester tester,
    ) async {
      final client = FakeConnectivityClient([ConnectivityResult.none]);
      final controller = ConnectivityController(
        client,
        reconnectResyncDelay: const Duration(milliseconds: 10),
      );

      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await tester.pump();
      expect(controller.state.isOnline, isFalse);

      client.setCurrentResults([ConnectivityResult.none]);
      client.emit([ConnectivityResult.wifi]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 11));

      expect(controller.state.isOnline, isTrue);
      expect(controller.state.result, ConnectivityResult.wifi);
    });
  });
}

class FakeConnectivityClient implements ConnectivityClient {
  FakeConnectivityClient(List<ConnectivityResult> initialResults)
      : _currentResults = List<ConnectivityResult>.from(initialResults);

  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> _currentResults;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    return List<ConnectivityResult>.from(_currentResults);
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  void setCurrentResults(List<ConnectivityResult> results) {
    _currentResults = List<ConnectivityResult>.from(results);
  }

  void emit(List<ConnectivityResult> results) {
    _controller.add(List<ConnectivityResult>.from(results));
  }

  Future<void> dispose() {
    return _controller.close();
  }
}
