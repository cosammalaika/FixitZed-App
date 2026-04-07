import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:fixitzed_app/common/connectivity/connectivity_banner.dart';

void main() {
  testWidgets('Connectivity banner shows offline copy when visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ConnectivityBanner(visible: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("You're offline. We'll reconnect automatically."),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
  });

  testWidgets('Connectivity banner shows restored copy when restored', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConnectivityBanner(
            visible: true,
            status: ConnectivityBannerStatus.restored,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Internet restored'), findsOneWidget);
  });
}
