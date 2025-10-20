import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_banner.dart';
import 'connectivity_controller.dart';

class ConnectivityOverlay extends ConsumerWidget {
  const ConnectivityOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityProvider);

    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ConnectivityBanner(visible: !status.isOnline),
        ),
      ],
    );
  }
}
