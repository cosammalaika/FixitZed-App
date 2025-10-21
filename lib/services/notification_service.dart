import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/core/date_utils.dart';
import 'package:fixitzed_app/services/local_notification_service.dart';

class NotificationService {
  Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Uri _uri(String path) => Uri.parse('${Api.baseUrl}/$path');

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<List<Map<String, dynamic>>> fetch({int page = 1}) async {
    try {
      final token = await _token();
      if (token == null || token.isEmpty) return [];
      final res = await http.get(_uri('notifications?page=$page'), headers: _headers(token));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        var list = <Map<String, dynamic>>[];
        if (body is List) {
          list = body.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (body is Map) {
          // Laravel: { success: true, data: { data: [...], ...pagination } }
          final data = body['data'];
          if (data is Map && data['data'] is List) {
            list = (data['data'] as List)
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          } else if (data is List) {
            list = data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
        if (page == 1 && list.isNotEmpty) {
          unawaited(_pushLocalAlerts(list));
        }
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<bool> markRead(int id) async {
    try {
      final token = await _token();
      if (token == null || token.isEmpty) return false;
      final res = await http.patch(_uri('notifications/$id/read'), headers: _headers(token), body: jsonEncode({}));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllRead() async {
    try {
      final token = await _token();
      if (token == null || token.isEmpty) return false;
      final res = await http.post(_uri('notifications/read-all'), headers: _headers(token), body: jsonEncode({}));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pushLocalAlerts(List<Map<String, dynamic>> notifications) async {
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
          notif['created_at'] ?? notif['createdAt'] ?? notif['createdAtFormatted'],
        );
        final suffix = createdAt != null ? ' • ${DateFormat('d MMM HH:mm').format(createdAt)}' : '';

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
    final raw = (notif['title'] ?? notif['subject'] ?? notif['heading'] ?? 'Notification').toString().trim();
    return raw.isEmpty ? 'Notification' : raw;
  }

  String _resolveBody(Map<String, dynamic> notif) {
    final raw = (notif['message'] ?? notif['body'] ?? notif['content'] ?? '').toString().trim();
    return raw;
  }
}
