import 'dart:convert';

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/services/session_guard.dart';
import 'package:fixitzed_app/services/token_storage.dart';
import 'package:http/http.dart' as http;

/// Lightweight HTTP client that injects the bearer token automatically.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  String get baseUrl => Api.baseUrl;

  Future<Map<String, String>> _headers({
    bool json = true,
    bool includeAuth = true,
    Map<String, String>? extra,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) headers['Content-Type'] = 'application/json';
    if (includeAuth) {
      final token = await TokenStorage.instance.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    if (extra != null && extra.isNotEmpty) headers.addAll(extra);
    return headers;
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final normalized = path.startsWith('http')
        ? path
        : path.startsWith('/')
            ? '${baseUrl}${path}'
            : '$baseUrl/$path';
    return Uri.parse(normalized).replace(queryParameters: query);
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    bool auth = true,
  }) async {
    final res = await http.get(
      _uri(path, query: query),
      headers: await _headers(extra: headers, includeAuth: auth),
    );
    if (auth) await SessionGuard.evaluate(res);
    return res;
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    bool jsonBody = true,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    final res = await http.post(
      _uri(path),
      headers: await _headers(
        json: jsonBody,
        includeAuth: auth,
        extra: headers,
      ),
      body: jsonBody ? jsonEncode(body) : body,
    );
    if (auth) await SessionGuard.evaluate(res);
    return res;
  }

  Future<http.Response> patch(
    String path, {
    Object? body,
    bool jsonBody = true,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    final res = await http.patch(
      _uri(path),
      headers: await _headers(
        json: jsonBody,
        includeAuth: auth,
        extra: headers,
      ),
      body: jsonBody ? jsonEncode(body) : body,
    );
    if (auth) await SessionGuard.evaluate(res);
    return res;
  }

  Future<http.Response> put(
    String path, {
    Object? body,
    bool jsonBody = true,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    final res = await http.put(
      _uri(path),
      headers: await _headers(
        json: jsonBody,
        includeAuth: auth,
        extra: headers,
      ),
      body: jsonBody ? jsonEncode(body) : body,
    );
    if (auth) await SessionGuard.evaluate(res);
    return res;
  }

  Future<http.MultipartRequest> multipart(
    String path, {
    String method = 'POST',
    Map<String, String>? fields,
    bool auth = true,
  }) async {
    final request = http.MultipartRequest(method, _uri(path));
    request.headers['Accept'] = 'application/json';
    if (auth) {
      final token = await TokenStorage.instance.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
    if (fields != null) request.fields.addAll(fields);
    return request;
  }
}
