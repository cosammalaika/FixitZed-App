import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixitzed_app/core/api.dart';

class HomeService {
  Map<String, String> _headers({String? token}) => {
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      const preferredKeys = [
        'data',
        'results',
        'items',
        'payload',
        'fixers',
        'records',
      ];
      for (final key in preferredKeys) {
        if (!data.containsKey(key)) continue;
        final nested = _extractList(data[key]);
        if (nested.isNotEmpty) return nested;
      }
      for (final value in data.values) {
        final nested = _extractList(value);
        if (nested.isNotEmpty) return nested;
      }
    }
    return const [];
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('${Api.baseUrl}/$path');
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        if (query != null) ...query.map((k, v) => MapEntry(k, '$v')),
      },
    );
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>?> fetchMe() async {
    try {
      final token = await _getToken();
      final res = await http.get(_uri('me'), headers: _headers(token: token));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> fetchCategories() async {
    try {
      final res = await http.get(_uri('categories'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = _extractList(data);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> fetchServices() async {
    try {
      final res = await http.get(_uri('services'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = _extractList(data);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> fetchFixers({int limit = 10}) async {
    try {
      final topList = await _fetchTopFixersRaw(limit: limit);
      if (topList.isNotEmpty) {
        final enriched = await _enrichFixers(topList);
        return enriched.isNotEmpty ? enriched : topList;
      }
      // Fallback to legacy /fixers
      final raw = await _fetchAllFixersRaw();
      if (raw.isNotEmpty) return raw;
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _fetchTopFixersRaw({int limit = 10}) async {
    try {
      final res = await http.get(
        _uri('fixers/top', {'limit': limit}),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = _extractList(data);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _fetchAllFixersRaw() async {
    try {
      final res = await http.get(_uri('fixers'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = _extractList(data);
        if (list.isNotEmpty) return list;
      }
      final res2 = await http.get(
        _uri('users', {'role': 'fixer'}),
        headers: _headers(),
      );
      if (res2.statusCode == 200) {
        final data = jsonDecode(res2.body);
        final list = _extractList(data);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return [];
  }

  Map<String, dynamic>? _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  void _mergeFixerRatings(List<dynamic> base, List<dynamic> candidates) {
    if (base.isEmpty || candidates.isEmpty) return;

    final byUserId = <String, Map<String, dynamic>>{};
    final byFixerId = <String, Map<String, dynamic>>{};

    for (final raw in candidates) {
      final map = _normalizeMap(raw);
      if (map == null || map.isEmpty) continue;
      final userId = map['user_id']?.toString();
      final fixerId = map['id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        byUserId[userId] = map;
      }
      if (fixerId != null && fixerId.isNotEmpty) {
        byFixerId[fixerId] = map;
      }
    }

    double? parseToDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        return double.tryParse(trimmed);
      }
      return null;
    }

    bool shouldOverwrite(dynamic current) {
      if (current == null) return true;
      if (current is num) return current.toDouble() <= 0;
      if (current is String) return current.trim().isEmpty;
      return false;
    }

    void applyRating(Map<String, dynamic> target, Map<String, dynamic> source) {
      const ratingKeys = [
        'rating',
        'avg_rating',
        'average_rating',
        'rating_avg',
        'ratings_avg',
        'ratings_average',
        'reviews_average',
        'rating_percentage',
        'rating_percent',
      ];

      for (final key in ratingKeys) {
        final fromSource = source[key];
        if (fromSource == null) continue;
        if (shouldOverwrite(target[key])) {
          target[key] = fromSource;
        }
      }

      const countKeys = [
        'ratings_count',
        'reviews_count',
        'rating_count',
        'ratings_total',
      ];

      for (final key in countKeys) {
        final fromSource = source[key];
        if (fromSource == null) continue;
        if (shouldOverwrite(target[key])) {
          target[key] = fromSource;
        }
      }

      final user = _normalizeMap(target['user']) ?? <String, dynamic>{};
      final sourceUser = _normalizeMap(source['user']);
      if (sourceUser != null) {
        final userRatingKeys = [
          'rating',
          'avg_rating',
          'average_rating',
        ];
        for (final key in userRatingKeys) {
          final val = sourceUser[key] ?? source[key];
          if (val == null) continue;
          if (shouldOverwrite(user[key])) {
            user[key] = val;
          }
          if (shouldOverwrite(user['average_rating'])) {
            user['average_rating'] = val;
          }
        }

        if (shouldOverwrite(user['ratings_count'])) {
          user['ratings_count'] =
              sourceUser['ratings_count'] ?? source['ratings_count'];
        }
      }
      if (user.isNotEmpty) {
        target['user'] = user;
      }

      final stats = _normalizeMap(target['stats']);
      final sourceStats = _normalizeMap(source['stats']);
      if (sourceStats != null) {
        final mergedStats = stats ?? <String, dynamic>{};
        sourceStats.forEach((key, value) {
          if (shouldOverwrite(mergedStats[key])) {
            mergedStats[key] = value;
          }
        });
        target['stats'] = mergedStats;
      }

      // Guard against lingering numeric strings by normalizing `rating` to a double string
      final ratingValue = parseToDouble(target['rating'] ?? target['avg_rating']);
      if (ratingValue != null) {
        target['rating'] = ratingValue;
        target['avg_rating'] ??= ratingValue;
        target['average_rating'] ??= ratingValue;
        final userMap = _normalizeMap(target['user']);
        if (userMap != null) {
          userMap['average_rating'] = ratingValue;
          userMap['rating'] ??= ratingValue;
          userMap['avg_rating'] ??= ratingValue;
          target['user'] = userMap;
        }
      }
    }

    for (var i = 0; i < base.length; i++) {
      final baseMap = _normalizeMap(base[i]);
      if (baseMap == null) continue;
      final fixerId = baseMap['id']?.toString();
      final userId = baseMap['user_id']?.toString() ??
          _normalizeMap(baseMap['user'])?['id']?.toString();
      Map<String, dynamic>? match;
      if (userId != null && userId.isNotEmpty) {
        match = byUserId[userId];
      }
      match ??= (fixerId != null ? byFixerId[fixerId] : null);
      if (match != null) {
        applyRating(baseMap, match);
        base[i] = baseMap;
      }
    }
  }

  Future<List<dynamic>> _enrichFixers(List<dynamic> compact) async {
    try {
      final needsEnrichment = compact.any((e) {
        if (e is! Map) return false;
        final Map map = e;
        final hasServices = map['services'] is List && (map['services'] as List).isNotEmpty;
        final hasAvatar = (map['avatar'] ?? map['image_url'] ?? map['photo'] ?? '')
            .toString()
            .trim()
            .isNotEmpty;
        final hasBio = (map['bio'] ?? '').toString().trim().isNotEmpty;
        return !(hasServices && hasAvatar && hasBio);
      });

      if (!needsEnrichment) {
        return compact;
      }

      final full = await _fetchAllFixersRaw();
      if (full.isEmpty) return compact;

      Map<String, Map> index = {};
      String? keyOf(Map m) {
        final id = m['id'] ?? m['user_id'] ?? (m['user'] is Map ? m['user']['id'] : null);
        if (id != null) return 'id:$id';
        final name = (m['name'] ?? m['full_name'] ?? m['display_name'])?.toString();
        if (name != null && name.isNotEmpty) return 'name:${name.toLowerCase()}';
        return null;
      }

      for (final e in full.whereType<Map>()) {
        final k = keyOf(e);
        if (k != null) index[k] = e;
      }

      Map merge(Map a, Map b) {
        final out = Map.of(a);
        b.forEach((k, v) {
          final exists = a[k];
          final isMissing = exists == null || (exists is String && exists.toString().trim().isEmpty);
          if (isMissing) out[k] = v;
        });
        return out;
      }

      final result = <dynamic>[];
      for (final e in compact) {
        if (e is Map) {
          final k = keyOf(e);
          if (k != null && index.containsKey(k)) {
            result.add(merge(e, index[k]!));
          } else {
            result.add(e);
          }
        } else {
          result.add(e);
        }
      }
      return result;
    } catch (_) {
      return compact;
    }
  }

  /// Fetches the full list of fixers (not just top),
  /// attempting to include service/skills data when the API provides it.
  Future<List<dynamic>> fetchAllFixers() async {
    final raw = await _fetchAllFixersRaw();
    if (raw.isEmpty) return [];

    final top =
        await _fetchTopFixersRaw(limit: raw.length > 10 ? raw.length : 10);
    if (top.isNotEmpty) {
      _mergeFixerRatings(raw, top);
    }
    return raw;
  }

  /// Best-effort: if your API exposes a list endpoint e.g. GET /coupons
  /// or returns a featured coupon from /coupons?active=1, we try both.
  Future<Map<String, dynamic>?> fetchFeaturedCoupon() async {
    for (final path in ['coupons', 'coupons?active=1']) {
      try {
        final res = await http.get(_uri(path), headers: _headers());
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List && data.isNotEmpty) {
            return Map<String, dynamic>.from(data.first as Map);
          }
          if (data is Map) {
            if (data['data'] is List && (data['data'] as List).isNotEmpty) {
              return Map<String, dynamic>.from(
                (data['data'] as List).first as Map,
              );
            }
            return Map<String, dynamic>.from(data);
          }
        }
      } catch (_) {
        // ignore and try next
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchCoupons() async {
    try {
      final res = await http.get(_uri('coupons'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = _extractList(data);
        if (list.isNotEmpty) {
          return list
              .whereType<Map>()
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e),
              )
              .toList();
        }
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }
}
