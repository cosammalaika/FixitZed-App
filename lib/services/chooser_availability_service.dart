import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fixitzed_app/services/home_service.dart';

enum FixerAvailability { unknown, none, available }

class _ActiveFixerServiceSet {
  const _ActiveFixerServiceSet({
    required this.ids,
    required this.names,
    required this.slugs,
  });

  final Set<String> ids;
  final Set<String> names;
  final Set<String> slugs;

  static const _ActiveFixerServiceSet empty = _ActiveFixerServiceSet(
    ids: <String>{},
    names: <String>{},
    slugs: <String>{},
  );

  bool get isEmpty => ids.isEmpty && names.isEmpty && slugs.isEmpty;
}

class ChooserAvailabilityService {
  ChooserAvailabilityService({HomeService? homeService})
      : _homeService = homeService ?? HomeService();

  static const Set<String> _activeFixerStatusTokens = {
    'active',
    'approved',
    'available',
    'online',
    'enabled',
    'verified',
    'live',
    'current',
  };

  static const Set<String> _inactiveFixerStatusTokens = {
    'inactive',
    'disabled',
    'suspended',
    'blocked',
    'pending',
    'unavailable',
    'offline',
    'archived',
    'deactivated',
    'draft',
    'rejected',
  };

  static const Duration _ttl = Duration(minutes: 7);
  static DateTime? _cacheFetchedAt;
  static final Map<String, FixerAvailability> _availabilityCache =
      <String, FixerAvailability>{};
  static Future<Map<String, FixerAvailability>>? _inflight;

  final HomeService _homeService;

  void invalidateCache() {
    _availabilityCache.clear();
    _cacheFetchedAt = null;
    _inflight = null;
  }

  bool _hasFreshCache() {
    final fetchedAt = _cacheFetchedAt;
    if (fetchedAt == null || _availabilityCache.isEmpty) return false;
    return DateTime.now().difference(fetchedAt) < _ttl;
  }

  String? _extractServiceId(Map<dynamic, dynamic> service) {
    final id = service['id'] ?? service['uuid'] ?? service['service_id'];
    if (id == null) return null;
    if (id is num) return id.toInt().toString();
    return id.toString();
  }

  String _safeJson(dynamic payload) {
    try {
      return jsonEncode(payload);
    } catch (_) {
      return payload.toString();
    }
  }

  bool _isEvidenceTarget(Map<String, dynamic> service, String id) {
    final name =
        (service['name'] ?? service['title'] ?? '').toString().toLowerCase();
    return name.contains('ac installation') || id == '87';
  }

  Map<String, FixerAvailability> _subsetFor(List<Map<String, dynamic>> services) {
    final out = <String, FixerAvailability>{};
    for (final service in services) {
      final id = _extractServiceId(service);
      if (id == null || id.isEmpty) continue;
      final availability = _availabilityCache[id];
      if (availability != null) {
        out[id] = availability;
      }
    }
    return out;
  }

  Future<Map<String, FixerAvailability>> resolveForServices(
    List<Map<String, dynamic>> services, {
    bool forceRefresh = false,
    String source = 'unknown',
  }) async {
    if (services.isEmpty) return const <String, FixerAvailability>{};

    if (forceRefresh) {
      invalidateCache();
    }

    if (!forceRefresh && _hasFreshCache()) {
      return _subsetFor(services);
    }

    if (!forceRefresh && _inflight != null) {
      await _inflight;
      return _subsetFor(services);
    }

    Future<Map<String, FixerAvailability>> load() async {
      final fixersRaw = await _homeService.fetchAllFixers();
      final filtered = _filterServicesByActiveFixers(services, fixersRaw);
      final activeIds = filtered
          .map(_extractServiceId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final resolved = <String, FixerAvailability>{};
      for (final service in services) {
        final id = _extractServiceId(service);
        if (id == null || id.isEmpty) continue;
        final availability = activeIds.contains(id)
            ? FixerAvailability.available
            : FixerAvailability.none;
        resolved[id] = availability;

        assert(() {
          if (_isEvidenceTarget(service, id)) {
            debugPrint(
              'ChooserAvailability[$source] service_id=$id result=$availability raw=${_safeJson(service)}',
            );
          }
          return true;
        }());
      }

      _availabilityCache
        ..clear()
        ..addAll(resolved);
      _cacheFetchedAt = DateTime.now();
      return resolved;
    }

    final future = load();
    if (!forceRefresh) _inflight = future;
    try {
      final resolved = await future;
      return _subsetFor(services)..addAll(resolved);
    } finally {
      if (!forceRefresh) _inflight = null;
    }
  }

  List<Map<String, dynamic>> _filterServicesByActiveFixers(
    List<Map<String, dynamic>> services,
    List<dynamic> fixersRaw,
  ) {
    if (services.isEmpty) return services;
    final active = _collectActiveFixerServices(fixersRaw);
    if (active.isEmpty) return services;

    bool matches(Map<String, dynamic> service) {
      final id = _extractServiceId(service);
      if (id != null && active.ids.contains(id)) {
        return true;
      }

      for (final candidate in <String>{
        _normalizeSlugToken(service['slug']),
        _normalizeSlugToken(service['service_slug']),
        _normalizeSlugToken(service['serviceCode']),
      }) {
        if (candidate.isNotEmpty && active.slugs.contains(candidate)) {
          return true;
        }
      }

      for (final name in _serviceNameCandidates(service)) {
        final normalized = _normalizeServiceNameToken(name);
        if (normalized.isNotEmpty && active.names.contains(normalized)) {
          return true;
        }
      }
      return false;
    }

    final filtered = <Map<String, dynamic>>[];
    for (final service in services) {
      if (matches(service)) {
        filtered.add(service);
      }
    }
    return filtered.isEmpty ? services : filtered;
  }

  _ActiveFixerServiceSet _collectActiveFixerServices(List<dynamic> fixersRaw) {
    if (fixersRaw.isEmpty) return _ActiveFixerServiceSet.empty;

    final ids = <String>{};
    final names = <String>{};
    final slugs = <String>{};
    final seenFixerMaps = <int>{};
    final seenServiceMaps = <int>{};

    void addId(dynamic value) {
      if (value == null) return;
      if (value is num) {
        ids.add(value.toInt().toString());
      } else if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;
        if (RegExp(r'^\d+$').hasMatch(trimmed)) {
          ids.add(trimmed);
        }
      }
    }

    void addName(dynamic value) {
      if (value == null) return;
      if (value is String) {
        final segments = value
            .split(RegExp(r'[,&/;|]+'))
            .map((e) => e.trim())
            .where((element) => element.isNotEmpty);
        for (final segment in segments) {
          final normalized = _normalizeServiceNameToken(segment);
          if (normalized.isNotEmpty) names.add(normalized);
          final slug = _normalizeSlugToken(segment);
          if (slug.isNotEmpty) slugs.add(slug);
        }
      }
    }

    void addSlug(dynamic value) {
      final normalized = _normalizeSlugToken(value);
      if (normalized.isNotEmpty) slugs.add(normalized);
    }

    void collectService(dynamic raw) {
      if (raw == null) return;
      if (raw is Map) {
        final id = identityHashCode(raw);
        if (!seenServiceMaps.add(id)) return;
        addId(
          raw['service_id'] ??
              raw['serviceId'] ??
              raw['id'] ??
              raw['service_id_fk'],
        );
        addSlug(
          raw['slug'] ?? raw['service_slug'] ?? raw['slug_name'] ?? raw['code'],
        );
        addName(raw['name']);
        addName(raw['title']);
        addName(raw['label']);
        addName(raw['service_name']);
        addName(raw['display_name']);
        collectService(raw['service']);
        collectService(raw['pivot']);
        for (final entry in raw.entries) {
          final key = entry.key.toString().toLowerCase();
          if (key.contains('service') ||
              key.contains('skill') ||
              key.contains('tag') ||
              key.contains('category')) {
            collectService(entry.value);
          }
        }
      } else if (raw is Iterable) {
        for (final item in raw) {
          collectService(item);
        }
      } else if (raw is num) {
        addId(raw);
      } else if (raw is String) {
        addName(raw);
      }
    }

    void collectFixer(Map<dynamic, dynamic> fixer) {
      final id = identityHashCode(fixer);
      if (!seenFixerMaps.add(id)) return;
      if (!_isFixerActive(fixer)) return;

      collectService(fixer['services']);
      collectService(fixer['service_names']);
      collectService(fixer['service_list']);
      collectService(fixer['serviceIds']);
      collectService(fixer['service_ids']);
      collectService(fixer['service_ids_array']);
      collectService(fixer['skills']);
      collectService(fixer['skill_names']);
      collectService(fixer['tags']);
      collectService(fixer['categories']);
      collectService(fixer['specialities']);

      for (final key in const [
        'fixer',
        'user',
        'profile',
        'fixer_profile',
        'owner',
        'details',
        'metadata',
        'meta',
      ]) {
        final nested = fixer[key];
        if (nested is Map) {
          collectFixer(nested);
        } else if (nested is Iterable) {
          for (final item in nested) {
            if (item is Map) collectFixer(item);
          }
        }
      }
    }

    for (final raw in fixersRaw) {
      if (raw is Map) {
        collectFixer(raw);
      }
    }

    if (ids.isEmpty && names.isEmpty && slugs.isEmpty) {
      return _ActiveFixerServiceSet.empty;
    }
    return _ActiveFixerServiceSet(ids: ids, names: names, slugs: slugs);
  }

  bool _isFixerActive(Map<dynamic, dynamic> fixer) {
    bool? parseBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) return null;
        if (_activeFixerStatusTokens.contains(normalized) ||
            normalized == 'true' ||
            normalized == '1' ||
            normalized == 'yes') {
          return true;
        }
        if (_inactiveFixerStatusTokens.contains(normalized) ||
            normalized == 'false' ||
            normalized == '0' ||
            normalized == 'no') {
          return false;
        }
      }
      return null;
    }

    final direct =
        parseBool(fixer['is_active']) ??
            parseBool(fixer['active']) ??
            parseBool(fixer['isActive']) ??
            parseBool(fixer['available']) ??
            parseBool(fixer['availability']) ??
            parseBool(fixer['status']) ??
            parseBool(fixer['state']);

    if (direct != null) {
      return direct;
    }

    for (final key in const [
      'status',
      'state',
      'availability',
      'availability_status',
      'fixer_status',
    ]) {
      final value = fixer[key];
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        if (_inactiveFixerStatusTokens.contains(normalized)) {
          return false;
        }
        if (_activeFixerStatusTokens.contains(normalized)) {
          return true;
        }
      }
    }
    return true;
  }

  Iterable<String> _serviceNameCandidates(Map<dynamic, dynamic> service) sync* {
    for (final key in const [
      'name',
      'title',
      'label',
      'service_name',
      'display_name',
      'subcategory_name',
      'subcategory',
    ]) {
      final value = service[key];
      if (value is String && value.trim().isNotEmpty) {
        yield value;
      } else if (value is Map) {
        final nestedName = value['name'] ?? value['title'];
        if (nestedName is String && nestedName.trim().isNotEmpty) {
          yield nestedName;
        }
      }
    }
    final sub = service['subcategory'];
    if (sub is Map) {
      final subName = sub['name'] ?? sub['title'];
      if (subName is String && subName.trim().isNotEmpty) {
        yield subName;
      }
    }
    final subName2 = service['subcategory_name'] ?? service['subcategoryName'];
    if (subName2 is String && subName2.trim().isNotEmpty) {
      yield subName2;
    }
    final category = service['category'];
    if (category is Map) {
      final categoryName = category['name'] ?? category['title'];
      if (categoryName is String && categoryName.trim().isNotEmpty) {
        yield categoryName;
      }
    }
  }

  String _normalizeServiceNameToken(dynamic value) {
    if (value == null) return '';
    final lower = value.toString().trim().toLowerCase();
    if (lower.isEmpty) return '';
    return lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeSlugToken(dynamic value) {
    if (value == null) return '';
    final lower = value.toString().trim().toLowerCase();
    if (lower.isEmpty) return '';
    final cleaned = lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return cleaned;
  }
}
