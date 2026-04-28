import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fixitzed_app/services/token_storage.dart';

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/core/date_utils.dart';
import 'package:fixitzed_app/services/local_notification_service.dart';
import 'package:fixitzed_app/services/session_guard.dart';
import 'package:fixitzed_app/state/app_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationFetchResult {
  const NotificationFetchResult({required this.items, required this.success});

  final List<Map<String, dynamic>> items;
  final bool success;
}

class NotificationDeleteResult {
  const NotificationDeleteResult({
    required this.success,
    this.statusCode,
    this.userMessage = 'Could not delete the notification right now.',
  });

  final bool success;
  final int? statusCode;
  final String userMessage;
}

class NotificationService {
  NotificationService({AppSync? sync}) : _sync = sync ?? AppSync.instance;

  final AppSync _sync;
  static const Duration _requestTimeout = Duration(seconds: 12);

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Uri _uri(String path) => Uri.parse('${Api.baseUrl}/$path');

  Future<String?> _token() async {
    return TokenStorage.instance.getToken();
  }

  Future<List<Map<String, dynamic>>> fetch({int page = 1}) async {
    final result = await fetchResult(page: page);
    return result.items;
  }

  Future<NotificationFetchResult> fetchResult({int page = 1}) async {
    try {
      final token = await _token();
      if (token == null || token.isEmpty) {
        return const NotificationFetchResult(
          items: <Map<String, dynamic>>[],
          success: true,
        );
      }
      final res = await http
          .get(_uri('notifications?page=$page'), headers: _headers(token))
          .timeout(_requestTimeout);
      await SessionGuard.evaluate(res);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        var list = <Map<String, dynamic>>[];
        if (body is List) {
          list = body
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map),
              )
              .toList();
        } else if (body is Map) {
          // Laravel: { success: true, data: { data: [...], ...pagination } }
          final data = body['data'];
          if (data is Map && data['data'] is List) {
            list = (data['data'] as List)
                .map<Map<String, dynamic>>(
                  (e) => Map<String, dynamic>.from(e as Map),
                )
                .toList();
          } else if (data is List) {
            list = data
                .map<Map<String, dynamic>>(
                  (e) => Map<String, dynamic>.from(e as Map),
                )
                .toList();
          }
        }
        if (page == 1 && list.isNotEmpty) {
          unawaited(_pushLocalAlerts(list));
        }
        return NotificationFetchResult(items: list, success: true);
      }
    } catch (_) {}
    return const NotificationFetchResult(
      items: <Map<String, dynamic>>[],
      success: false,
    );
  }

  Future<bool> markRead(int id) async {
    try {
      final token = await _token();
      if (token == null || token.isEmpty) return false;
      final res = await http.patch(
        _uri('notifications/$id/read'),
        headers: _headers(token),
        body: jsonEncode({}),
      );
      await SessionGuard.evaluate(res);
      final ok = res.statusCode == 200;
      if (ok) {
        _sync.emit(
          AppSyncTopic.notifications,
          payload: <String, dynamic>{'action': 'markRead', 'id': id},
        );
        _sync.emit(
          AppSyncTopic.dashboard,
          payload: <String, dynamic>{'source': 'notifications'},
        );
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllRead() async {
    try {
      final token = await _token();
      if (token == null || token.isEmpty) return false;
      final res = await http.post(
        _uri('notifications/read-all'),
        headers: _headers(token),
        body: jsonEncode({}),
      );
      await SessionGuard.evaluate(res);
      final ok = res.statusCode == 200;
      if (ok) {
        _sync.emit(
          AppSyncTopic.notifications,
          payload: const <String, dynamic>{'action': 'markAll'},
        );
        _sync.emit(
          AppSyncTopic.dashboard,
          payload: const <String, dynamic>{'source': 'notifications'},
        );
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<NotificationDeleteResult> deleteNotification(int id) async {
    final path = 'notifications/$id';
    try {
      final token = await _token();
      if (token == null || token.isEmpty) {
        return const NotificationDeleteResult(
          success: false,
          statusCode: 401,
          userMessage: 'Please sign in again to manage notifications.',
        );
      }
      final res = await http
          .delete(_uri(path), headers: _headers(token))
          .timeout(_requestTimeout);
      await SessionGuard.evaluate(res);
      _debugLogResponse(
        method: 'DELETE',
        path: path,
        statusCode: res.statusCode,
        responseBody: res.body,
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        return NotificationDeleteResult(
          success: true,
          statusCode: res.statusCode,
        );
      }
      return NotificationDeleteResult(
        success: false,
        statusCode: res.statusCode,
        userMessage: _deleteErrorMessage(res.statusCode, res.body),
      );
    } on TimeoutException catch (error, stackTrace) {
      _debugLogException(
        method: 'DELETE',
        path: path,
        error: error,
        stackTrace: stackTrace,
      );
      return const NotificationDeleteResult(
        success: false,
        userMessage:
            'Could not delete the notification right now. Check your connection and try again.',
      );
    } on http.ClientException catch (error, stackTrace) {
      _debugLogException(
        method: 'DELETE',
        path: path,
        error: error,
        stackTrace: stackTrace,
      );
      return const NotificationDeleteResult(
        success: false,
        userMessage:
            'Could not delete the notification right now. Check your connection and try again.',
      );
    } catch (error, stackTrace) {
      _debugLogException(
        method: 'DELETE',
        path: path,
        error: error,
        stackTrace: stackTrace,
      );
      return const NotificationDeleteResult(
        success: false,
        userMessage:
            'Could not delete the notification right now. Please try again shortly.',
      );
    }
  }

  Future<void> _pushLocalAlerts(
    List<Map<String, dynamic>> notifications,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenRaw = prefs.getStringList('local_notif_seen') ?? const [];
      final seen = seenRaw.toSet();
      final newIds = <String>[];

      for (final notif in notifications) {
        final id = _extractId(notif);
        if (id == null || seen.contains(id)) continue;
        newIds.add(id);

        final title = _resolveTitle(notif);
        final body = _resolveBody(notif);
        final createdAt = parseAppDate(
          notif['created_at'] ??
              notif['createdAt'] ??
              notif['createdAtFormatted'],
        );
        final suffix = createdAt != null
            ? ' • ${DateFormat('d MMM HH:mm').format(createdAt)}'
            : '';

        await LocalNotificationService.instance.showInstant(
          id: id.hashCode,
          title: title,
          body: body.isNotEmpty ? '$body$suffix' : 'Tap to view details$suffix',
          payload: 'remote_notification:$id',
        );
      }

      if (newIds.isNotEmpty) {
        seen.addAll(newIds);
        await prefs.setStringList('local_notif_seen', seen.toList());
      }
    } catch (_) {
      // Swallow errors to avoid breaking UI fetch.
    }
  }

  String? _extractId(Map<String, dynamic> notif) {
    final raw = notif['id'] ?? notif['uuid'] ?? notif['key'];
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  String _resolveTitle(Map<String, dynamic> notif) {
    final raw =
        (notif['title'] ??
                notif['subject'] ??
                notif['heading'] ??
                'Notification')
            .toString()
            .trim();
    return raw.isEmpty ? 'Notification' : raw;
  }

  String _resolveBody(Map<String, dynamic> notif) {
    final raw = (notif['message'] ?? notif['body'] ?? notif['content'] ?? '')
        .toString()
        .trim();
    return raw;
  }

  String _deleteErrorMessage(int statusCode, String responseBody) {
    final apiMessage = _extractApiMessage(responseBody);
    switch (statusCode) {
      case 401:
        return 'Please sign in again to manage notifications.';
      case 404:
        return 'This notification no longer exists on the server.';
      case 500:
        return 'Could not delete the notification right now. Please try again later.';
      default:
        return apiMessage ??
            'Could not delete the notification right now. Please try again.';
    }
  }

  String? _extractApiMessage(String responseBody) {
    final body = responseBody.trim();
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  void _debugLogResponse({
    required String method,
    required String path,
    required int statusCode,
    required String responseBody,
  }) {
    if (!kDebugMode) return;
    debugPrint('[NotificationService] $method ${_uri(path)} -> $statusCode');
    final body = responseBody.trim();
    debugPrint(
      '[NotificationService] response body: ${body.isEmpty ? '<empty>' : body}',
    );
  }

  void _debugLogException({
    required String method,
    required String path,
    required Object error,
    required StackTrace stackTrace,
  }) {
    if (!kDebugMode) return;
    debugPrint('[NotificationService] $method ${_uri(path)} failed: $error');
    debugPrint(stackTrace.toString());
  }
}
