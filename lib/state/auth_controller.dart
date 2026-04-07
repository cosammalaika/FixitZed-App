import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_app/services/token_storage.dart';
import 'package:fixitzed_app/state/app_sync.dart';

enum AuthStatus { initializing, authenticated, guest }

class AuthState {
  const AuthState(this.status);

  const AuthState.initializing() : status = AuthStatus.initializing;
  const AuthState.authenticated() : status = AuthStatus.authenticated;
  const AuthState.guest() : status = AuthStatus.guest;

  final AuthStatus status;

  bool get isInitializing => status == AuthStatus.initializing;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isGuest => status == AuthStatus.guest;
}

class AuthController extends Notifier<AuthState> {
  bool _syncRegistered = false;

  @override
  AuthState build() {
    _registerSync();
    unawaited(refresh());
    return const AuthState.initializing();
  }

  Future<void> refresh() async {
    final token = await TokenStorage.instance.getToken();
    state = token == null || token.isEmpty
        ? const AuthState.guest()
        : const AuthState.authenticated();
  }

  void markAuthenticated() {
    state = const AuthState.authenticated();
  }

  void markGuest() {
    state = const AuthState.guest();
  }

  void _registerSync() {
    if (_syncRegistered) return;
    _syncRegistered = true;

    ref.onAppSync(AppSyncTopic.auth, (event) {
      final payload = event.payload;
      final action = payload is Map
          ? payload['action']?.toString().trim().toLowerCase()
          : null;

      if (action == 'login' || action == 'register') {
        markAuthenticated();
        return;
      }
      if (action == 'logout') {
        markGuest();
        return;
      }

      unawaited(refresh());
    });
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
