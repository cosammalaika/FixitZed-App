import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:fixitzed_app/services/token_storage.dart';

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/services/session_guard.dart';

class LocationsService {
  Map<String, String> _headers({String? token}) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<String?> _getToken() async {
    return TokenStorage.instance.getToken();
  }

  Uri _uri(String path) => Uri.parse('${Api.baseUrl}/$path');

  Future<List<Map<String, dynamic>>> list() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        _uri('locations'),
        headers: _headers(token: token),
      );
      await SessionGuard.evaluate(res);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List list;
        if (data is List) {
          list = data;
        } else if (data is Map) {
          list = (data['data'] is List) ? data['data'] as List : [];
        } else {
          list = [];
        }
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> save({
    int? id,
    required String label,
    required String address,
    String? city,
    String? instructions,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;
      final payload = <String, dynamic>{
        'label': label,
        'address': address,
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (instructions != null && instructions.trim().isNotEmpty)
          'details': instructions.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'is_default': isDefault,
      };
      final body = jsonEncode(payload);

      http.Response res;
      if (id == null) {
        res = await http.post(
          _uri('locations'),
          headers: _headers(token: token),
          body: body,
        );
      } else {
        res = await http.put(
          _uri('locations/$id'),
          headers: _headers(token: token),
          body: body,
        );
        if (res.statusCode == 404) {
          res = await http.patch(
            _uri('locations/$id'),
            headers: _headers(token: token),
            body: body,
          );
        }
      }
      await SessionGuard.evaluate(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          if (data['data'] is Map) {
            return Map<String, dynamic>.from(data['data'] as Map);
          }
          return Map<String, dynamic>.from(data);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> delete(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return false;
      final res = await http.delete(
        _uri('locations/$id'),
        headers: _headers(token: token),
      );
      await SessionGuard.evaluate(res);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
