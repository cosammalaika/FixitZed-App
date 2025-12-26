import 'dart:developer';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:fixitzed_app/services/local_notification_service.dart';
import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/services/token_storage.dart';
import 'package:http/http.dart' as http;

Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await LocalNotificationService.instance.init();
  final notification = message.notification;
  final title = notification?.title ?? message.data['title'];
  final body = notification?.body ?? message.data['body'];
  if (title != null || body != null) {
    await LocalNotificationService.instance.showInstant(
      title: title ?? 'New notification',
      body: body ?? '',
      payload: message.data['payload'],
    );
  }
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();
  static const String appType = 'customer';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      if (kDebugMode) print('Firebase init failed: $e');
      return;
    }

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      log('FCM permission: ${settings.authorizationStatus}');
    }

    // On iOS, ensure we actually have an APNs token before asking for an FCM
    // token, otherwise firebase_messaging will throw.
    if (Platform.isIOS) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null || apnsToken.isEmpty) {
        if (kDebugMode) {
          log('APNs token missing; skipping FCM token registration for now.');
        }
        return;
      }
    }

    final token = await _getMessagingToken();
    if (token != null) {
      await _persistToken(token);
    }
    FirebaseMessaging.instance.onTokenRefresh.listen(_persistToken);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'];
      final body = notification?.body ?? message.data['body'];
      if (title != null || body != null) {
        LocalNotificationService.instance.showInstant(
          title: title ?? 'New notification',
          body: body ?? '',
          payload: message.data['payload'],
        );
      }
    });

    _initialized = true;
  }

  Future<void> deleteToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      if (kDebugMode) log('FCM delete token failed: $e');
    }
  }

  Future<String?> _getMessagingToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      if (kDebugMode) log('FCM getToken failed: $e');
      return null;
    }
  }

  Future<void> _persistToken(String token) async {
    if (kDebugMode) log('FCM token: $token');
    try {
      final authToken = await TokenStorage.instance.getToken();
      if (authToken == null || authToken.isEmpty) return;

      final uri = Uri.parse('${Api.baseUrl}/device-tokens');
      final res = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: '{"token":"$token","platform":"${Platform.isIOS ? 'ios' : 'android'}","app":"$appType"}',
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (kDebugMode) print('FCM token persisted (${res.statusCode})');
      } else {
        if (kDebugMode) {
          print('Failed to persist token (${res.statusCode}): ${res.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Failed to persist token: $e');
    }
  }

  Future<void> registerTokenForCurrentUser() async {
    try {
      final authToken = await TokenStorage.instance.getToken();
      if (authToken == null || authToken.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _persistToken(token);
    } catch (e) {
      if (kDebugMode) log('registerTokenForCurrentUser failed: $e');
    }
  }

  Future<void> unregisterTokenForCurrentUser() async {
    try {
      final authToken = await TokenStorage.instance.getToken();
      if (authToken == null || authToken.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final uri = Uri.parse('${Api.baseUrl}/device-tokens');
      await http.delete(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: '{"token":"$token"}',
      );
    } catch (e) {
      if (kDebugMode) log('unregisterTokenForCurrentUser failed: $e');
    }
  }
}
