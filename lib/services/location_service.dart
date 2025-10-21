import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/data/province_districts.dart';

class LocationService {
  Future<Map<String, List<String>>> fetchProvinceDistricts() async {
    try {
      final uri = Uri.parse('${Api.baseUrl}/provinces');
      final res = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final parsed = _parsePayload(decoded);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
    } catch (_) {
      // WHY: Silent failure, we fall back to bundled data.
    }

    return ProvinceData.asMutable();
  }

  Map<String, List<String>> _parsePayload(dynamic payload) {
    final result = <String, List<String>>{};
    final nodes = _extractNodes(payload);

    for (final node in nodes) {
      if (node is! Map) continue;
      final name = node['name']?.toString().trim();
      if (name == null || name.isEmpty) continue;

      final districtsRaw = node['districts'];
      final districts = <String>{};

      if (districtsRaw is List) {
        for (final entry in districtsRaw) {
          if (entry is Map && entry['name'] is String) {
            final value = entry['name'].toString().trim();
            if (value.isNotEmpty) districts.add(value);
          } else if (entry is String) {
            final value = entry.trim();
            if (value.isNotEmpty) districts.add(value);
          }
        }
      }

      if (districts.isEmpty) continue;
      final sorted = districts.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      result[name] = sorted;
    }

    if (result.isEmpty) {
      return result;
    }

    final sortedEntries = result.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return {for (final entry in sortedEntries) entry.key: entry.value};
  }

  List<dynamic> _extractNodes(dynamic payload) {
    if (payload is List) {
      return payload;
    }

    if (payload is Map) {
      for (final key in ['data', 'provinces', 'results']) {
        final value = payload[key];
        if (value is List) return value;
      }

      return payload.values.whereType<List>().expand((list) => list).toList();
    }

    return const [];
  }
}
