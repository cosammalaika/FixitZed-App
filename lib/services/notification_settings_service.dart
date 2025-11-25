import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/services/app_analytics.dart';
import 'package:fixitzed_app/services/session_guard.dart';
import 'package:fixitzed_app/services/session_manager.dart';

class NotificationSettingsService {
  static const _endpoints = [
    'settings/notifications',
    'notifications/settings',
    'notification-preferences',
  ];

  Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<Map<String, bool>> fetch() async {
    final token = await SessionManager.instance.readToken();
    if (token == null) return <String, bool>{};
    for (final path in _endpoints) {
      try {
        final res = await http.get(
          Uri.parse('${Api.baseUrl}/$path'),
          headers: _headers(token),
        );
        await SessionGuard.evaluate(res);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body);
          final parsed = _extractFlags(data);
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (err, stack) {
        AppAnalytics.instance.logError(
          'notification_settings_fetch_failed',
          message: err.toString(),
          stackTrace: stack,
          parameters: {'endpoint': path},
        );
      }
    }
    return <String, bool>{};
  }

  Future<bool> update({bool? push, bool? email}) async {
    if (push == null && email == null) return false;
    final token = await SessionManager.instance.readToken();
    if (token == null) return false;
    final payload = <String, dynamic>{
      if (push != null) 'push': push,
      if (email != null) 'email': email,
      if (push != null) 'push_notifications': push,
      if (email != null) 'email_notifications': email,
    };
    final body = jsonEncode(payload);
    for (final path in _endpoints) {
      try {
        final res = await http.patch(
          Uri.parse('${Api.baseUrl}/$path'),
          headers: _headers(token),
          body: body,
        );
        await SessionGuard.evaluate(res);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return true;
        }
      } catch (err, stack) {
        AppAnalytics.instance.logError(
          'notification_settings_update_failed',
          message: err.toString(),
          stackTrace: stack,
          parameters: {'endpoint': path},
        );
      }
    }
    return false;
  }

  Map<String, bool> _extractFlags(dynamic payload) {
    if (payload is Map) {
      final map = payload['data'] is Map ? payload['data'] as Map : payload;
      final push = map['push'] ?? map['push_notifications'];
      final email = map['email'] ?? map['email_notifications'];
      final parsed = <String, bool>{};
      if (push is bool) parsed['push'] = push;
      if (push is num) parsed['push'] = push != 0;
      if (email is bool) parsed['email'] = email;
      if (email is num) parsed['email'] = email != 0;
      return parsed;
    }
    return <String, bool>{};
  }
}
