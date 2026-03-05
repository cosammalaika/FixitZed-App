import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:fixitzed_app/services/home_service.dart';

enum FixerAvailability { unknown, checking, none, available }

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

class _AvailabilityCacheEntry {
  const _AvailabilityCacheEntry({
    required this.state,
    required this.eligibleFixerCount,
    required this.verifiedAt,
  });

  final FixerAvailability state;
  final int eligibleFixerCount;
  final DateTime verifiedAt;
}

class FixerAvailabilityResolver {
  FixerAvailabilityResolver({HomeService? homeService})
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

  static const Duration _availabilityTtl = Duration(minutes: 5);
  static const Duration _fixersListTtl = Duration(minutes: 2);
  static const Duration _verifyTimeout = Duration(seconds: 12);

  final HomeService _homeService;
  final Map<String, _AvailabilityCacheEntry> _cache =
      <String, _AvailabilityCacheEntry>{};
  final Map<String, Future<int>> _inflightByService = <String, Future<int>>{};

  DateTime? _fixersFetchedAt;
  List<dynamic>? _fixersCache;
  Future<List<dynamic>>? _fixersInflight;

  String? _extractServiceId(Map<dynamic, dynamic> service) {
    final id = service['id'] ?? service['uuid'] ?? service['service_id'];
    if (id != null) {
      final normalized = id is num ? id.toInt().toString() : id.toString().trim();
      if (normalized.isNotEmpty) return normalized;
    }
    final slugToken = _normalizeSlugToken(
      service['slug'] ?? service['service_slug'] ?? service['serviceCode'],
    );
    if (slugToken.isNotEmpty) return 'slug:$slugToken';
    final nameToken = _normalizeServiceNameToken(
      service['name'] ?? service['title'] ?? service['service_name'],
    );
    if (nameToken.isNotEmpty) return 'name:$nameToken';
    return null;
  }

  bool _hasFreshFixerList() {
    final fetchedAt = _fixersFetchedAt;
    final cache = _fixersCache;
    if (fetchedAt == null || cache == null) return false;
    return DateTime.now().difference(fetchedAt) < _fixersListTtl;
  }

  bool _hasFreshAvailability(_AvailabilityCacheEntry entry) {
    return DateTime.now().difference(entry.verifiedAt) < _availabilityTtl;
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
    return id == '87' ||
        name.contains('ac installation') ||
        name.contains('general pest control');
  }

  int? _parseCount(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool? _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  Map<String, dynamic> _hintEvidence(Map<dynamic, dynamic> service) {
    return <String, dynamic>{
      'available_fixers_count':
          _parseCount(service['available_fixers_count'] ?? service['availableFixersCount']),
      'opted_in_fixers_count':
          _parseCount(service['opted_in_fixers_count'] ?? service['ready_fixers_count']),
      'fixers_count': _parseCount(service['fixers_count'] ?? service['fixersCount']),
      'has_fixers':
          _parseBool(service['has_fixers'] ?? service['hasFixers']),
      'has_ready_fixers':
          _parseBool(service['has_ready_fixers'] ?? service['hasReadyFixers']),
      'has_opted_in_fixers':
          _parseBool(service['has_opted_in_fixers'] ?? service['hasOptedInFixers']),
    };
  }

  Future<List<dynamic>> _loadFixers({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasFreshFixerList()) {
      return List<dynamic>.from(_fixersCache!);
    }
    if (!forceRefresh && _fixersInflight != null) {
      final pending = await _fixersInflight!;
      return List<dynamic>.from(pending);
    }

    Future<List<dynamic>> load() async {
      final list = await _homeService.fetchAllFixers();
      _fixersCache = List<dynamic>.from(list);
      _fixersFetchedAt = DateTime.now();
      return List<dynamic>.from(_fixersCache!);
    }

    final future = load();
    if (!forceRefresh) {
      _fixersInflight = future;
    }
    try {
      return await future;
    } finally {
      if (!forceRefresh) {
        _fixersInflight = null;
      }
    }
  }

  void invalidateCache({bool includeFixersList = true}) {
    _cache.clear();
    _inflightByService.clear();
    if (includeFixersList) {
      _fixersCache = null;
      _fixersFetchedAt = null;
      _fixersInflight = null;
    }
  }

  FixerAvailability stateForService(Map<dynamic, dynamic> service) {
    final id = _extractServiceId(service);
    if (id == null || id.isEmpty) return FixerAvailability.unknown;
    final entry = _cache[id];
    if (entry != null && _hasFreshAvailability(entry)) {
      return entry.state;
    }
    if (_inflightByService.containsKey(id)) {
      return FixerAvailability.checking;
    }
    return FixerAvailability.unknown;
  }

  Map<String, FixerAvailability> stateForServices(
    List<Map<String, dynamic>> services,
  ) {
    final out = <String, FixerAvailability>{};
    for (final service in services) {
      final id = _extractServiceId(service);
      if (id == null || id.isEmpty) continue;
      out[id] = stateForService(service);
    }
    return out;
  }

  Future<Map<String, FixerAvailability>> verifyServices(
    List<Map<String, dynamic>> services, {
    bool forceRefresh = false,
    int maxConcurrent = 4,
    String source = 'unknown',
  }) async {
    if (services.isEmpty) return const <String, FixerAvailability>{};
    final resolved = <String, FixerAvailability>{};
    final queue = Queue<Map<String, dynamic>>();
    for (final service in services) {
      final id = _extractServiceId(service);
      if (id == null || id.isEmpty) continue;
      final entry = _cache[id];
      if (!forceRefresh && entry != null && _hasFreshAvailability(entry)) {
        resolved[id] = entry.state;
      } else {
        resolved[id] = FixerAvailability.checking;
        queue.addLast(service);
      }
    }
    if (queue.isEmpty) {
      return resolved;
    }

    final limit = max(1, min(maxConcurrent, 5));
    while (queue.isNotEmpty) {
      final chunk = <Map<String, dynamic>>[];
      for (var i = 0; i < limit && queue.isNotEmpty; i++) {
        chunk.add(queue.removeFirst());
      }
      final states = await Future.wait(
        chunk.map((service) async {
          final id = _extractServiceId(service) ?? '';
          try {
            return await verifyService(
              service,
              forceRefresh: forceRefresh,
              source: source,
            ).timeout(_verifyTimeout);
          } catch (error, stackTrace) {
            if (id.isNotEmpty) {
              _cache[id] = _AvailabilityCacheEntry(
                state: FixerAvailability.none,
                eligibleFixerCount: 0,
                verifiedAt: DateTime.now(),
              );
            }
            assert(() {
              debugPrint(
                'FixerAvailabilityResolver[$source] verify failed service_id=$id error=$error stack=$stackTrace',
              );
              return true;
            }());
            return FixerAvailability.none;
          }
        }),
      );
      for (var i = 0; i < chunk.length; i++) {
        final id = _extractServiceId(chunk[i]);
        if (id == null || id.isEmpty) continue;
        resolved[id] = states[i];
      }
    }
    return resolved;
  }

  Future<FixerAvailability> verifyService(
    Map<String, dynamic> service, {
    bool forceRefresh = false,
    String source = 'unknown',
  }) async {
    final id = _extractServiceId(service);
    if (id == null || id.isEmpty) return FixerAvailability.none;
    final entry = _cache[id];
    if (!forceRefresh && entry != null && _hasFreshAvailability(entry)) {
      return entry.state;
    }
    final inflight = _inflightByService[id];
    if (!forceRefresh && inflight != null) {
      final count = await inflight;
      return count > 0 ? FixerAvailability.available : FixerAvailability.none;
    }

    final future = fetchEligibleFixerCount(
      service,
      forceRefresh: forceRefresh,
      source: source,
    );
    if (!forceRefresh) {
      _inflightByService[id] = future;
    }
    try {
      final count = await future;
      return count > 0 ? FixerAvailability.available : FixerAvailability.none;
    } finally {
      if (!forceRefresh) {
        _inflightByService.remove(id);
      }
    }
  }

  Future<int> fetchEligibleFixerCount(
    Map<String, dynamic> service, {
    bool forceRefresh = false,
    String source = 'unknown',
  }) async {
    final id = _extractServiceId(service);
    if (id == null || id.isEmpty) return 0;
    final startedAt = DateTime.now();
    List<dynamic> fixers;
    try {
      fixers = await _loadFixers(
        forceRefresh: forceRefresh,
      ).timeout(_verifyTimeout);
    } catch (error, stackTrace) {
      fixers = const <dynamic>[];
      assert(() {
        debugPrint(
          'FixerAvailabilityResolver[$source] load fixers failed service_id=$id error=$error stack=$stackTrace',
        );
        return true;
      }());
    }
    final pickerListLength = fixers.whereType<Map>().length;
    final eligibleCount = _eligibleFixerCount(service, fixers);
    final state = eligibleCount > 0
        ? FixerAvailability.available
        : FixerAvailability.none;
    final existing = _cache[id];
    if (existing == null || !existing.verifiedAt.isAfter(startedAt)) {
      _cache[id] = _AvailabilityCacheEntry(
        state: state,
        eligibleFixerCount: eligibleCount,
        verifiedAt: DateTime.now(),
      );
    }

    assert(() {
      if (_isEvidenceTarget(service, id)) {
        debugPrint(
          'FixerAvailabilityResolver[$source] service_id=$id hints=${_safeJson(_hintEvidence(service))} '
          'picker_list_len=$pickerListLength eligible_fixers=$eligibleCount state=$state raw=${_safeJson(service)}',
        );
      }
      return true;
    }());

    return eligibleCount;
  }

  int _eligibleFixerCount(Map<String, dynamic> service, List<dynamic> fixersRaw) {
    var count = 0;
    for (final rawFixer in fixersRaw) {
      if (rawFixer is! Map) continue;
      final fixer = Map<String, dynamic>.from(rawFixer);
      if (!_isFixerActive(fixer)) continue;
      final activeForFixer = _collectActiveFixerServices([fixer]);
      if (_serviceMatches(service, activeForFixer)) {
        count++;
      }
    }
    return count;
  }

  bool _serviceMatches(
    Map<String, dynamic> service,
    _ActiveFixerServiceSet active,
  ) {
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
              key.contains('tag')) {
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
    return lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}

// Backward-compatible alias used by existing imports/screens.
typedef ChooserAvailabilityService = FixerAvailabilityResolver;
