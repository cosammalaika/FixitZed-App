import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_app/common/connectivity/connectivity_banner.dart';
import 'package:fixitzed_app/common/connectivity/connectivity_controller.dart';

class ConnectivityOverlay extends ConsumerStatefulWidget {
  const ConnectivityOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConnectivityOverlay> createState() =>
      _ConnectivityOverlayState();
}

class _ConnectivityOverlayState extends ConsumerState<ConnectivityOverlay> {
  static const _restoredVisibleDuration = Duration(seconds: 2);

  Timer? _hideRestoredTimer;
  bool _showRestored = false;

  @override
  void dispose() {
    _hideRestoredTimer?.cancel();
    super.dispose();
  }

  void _handleConnectivityChange(
    ConnectivityStatus? previous,
    ConnectivityStatus next,
  ) {
    if (previous?.isOnline == false && next.isOnline) {
      _hideRestoredTimer?.cancel();
      setState(() => _showRestored = true);
      _hideRestoredTimer = Timer(_restoredVisibleDuration, () {
        if (!mounted) return;
        setState(() => _showRestored = false);
      });
      return;
    }

    if (!next.isOnline && _showRestored) {
      _hideRestoredTimer?.cancel();
      setState(() => _showRestored = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectivityStatus>(
      connectivityProvider,
      _handleConnectivityChange,
    );
    final status = ref.watch(connectivityProvider);
    final showBanner = !status.isOnline || _showRestored;
    final bannerStatus = status.isOnline
        ? ConnectivityBannerStatus.restored
        : ConnectivityBannerStatus.offline;

    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ConnectivityBanner(visible: showBanner, status: bannerStatus),
        ),
      ],
    );
  }
}
