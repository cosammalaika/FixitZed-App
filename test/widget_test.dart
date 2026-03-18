import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:fixitzed_app/common/connectivity/connectivity_banner.dart';

void main() {
  testWidgets('Connectivity banner shows offline copy when visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConnectivityBanner(visible: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("You're offline. Changes will sync automatically."),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });
}
