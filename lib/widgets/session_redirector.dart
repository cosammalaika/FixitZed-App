import 'dart:async';

import 'package:fixitzed_app/state/app_sync.dart';
import 'package:flutter/material.dart';

class SessionRedirector extends StatefulWidget {
  const SessionRedirector({super.key, required this.child});

  final Widget child;

  @override
  State<SessionRedirector> createState() => _SessionRedirectorState();
}

class _SessionRedirectorState extends State<SessionRedirector> {
  StreamSubscription<AppSyncEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = AppSync.instance.on(AppSyncTopic.auth).listen(_handleEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleEvent(AppSyncEvent event) {
    final payload = event.payload;
    if (payload is Map) {
      final reason = payload['reason']?.toString() ?? '';
      if (reason == 'manual') return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final route = ModalRoute.of(context);
      final currentName = route?.settings.name ?? '';
      if (currentName == '/home' || currentName == '/auth') return;
      navigator.pushNamedAndRemoveUntil('/home', (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
