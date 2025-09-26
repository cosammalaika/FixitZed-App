import 'api.dart';

String _asString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString();
  return value.toString().trim();
}

String? _firstNonEmpty(Iterable<dynamic> values) {
  for (final value in values) {
    final str = _asString(value);
    if (str.isNotEmpty) return str;
  }
  return null;
}

String? _nameFromMap(Map<dynamic, dynamic> data, Set<int> seen) {
  final id = identityHashCode(data);
  if (!seen.add(id)) return null;

  // Prefer first + last when available for a proper full name
  final first = _firstNonEmpty([
    data['first_name'],
    data['firstname'],
    data['firstName'],
  ]);
  final last = _firstNonEmpty([
    data['last_name'],
    data['lastname'],
    data['lastName'],
  ]);
  final combined = [first, last].whereType<String>().join(' ').trim();
  if (combined.isNotEmpty) return combined;

  // Then try common full-name style fields
  final direct = _firstNonEmpty([
    data['name'],
    data['full_name'],
    data['fullName'],
    data['display_name'],
    data['title'],
  ]);
  if (direct != null) return direct;

  // Fallback to username if that's all we have
  final username = _asString(data['username']);
  if (username.isNotEmpty) return username;

  final email = _asString(data['email']);
  if (email.isNotEmpty) return email;

  for (final entry in data.entries) {
    final value = entry.value;
    if (value is Map) {
      final nested = _nameFromMap(value, seen);
      if (nested != null && nested.isNotEmpty) return nested;
    }
  }

  return null;
}

/// Returns a human friendly name for a fixer payload, attempting to handle
/// various API response shapes (flat or nested).
String fixerDisplayName(Map<dynamic, dynamic> fixer) {
  final name = _nameFromMap(fixer, <int>{});
  return (name != null && name.isNotEmpty) ? name : 'Fixer';
}

String _stringFrom(dynamic v) {
  if (v == null) return '';
  if (v is String) return v.trim();
  if (v is Map) {
    final s = _firstNonEmpty([
      v['url'],
      v['src'],
      v['link'],
      v['path'],
      v['image'],
      v['original_url'],
      v['preview_url'],
    ]);
    return s?.toString().trim() ?? '';
  }
  if (v is List && v.isNotEmpty) {
    return _stringFrom(v.first);
  }
  return v.toString().trim();
}

String fixerAvatarUrl(Map<dynamic, dynamic> fixer) {
  String raw = '';
  final candidates = [
    fixer['avatar'],
    fixer['photo'],
    fixer['image_url'],
    fixer['profile_photo_url'],
    fixer['profile_photo_path'],
    fixer['profile_photo'],
    fixer['profile_image'],
    fixer['image'],
  ];
  for (final c in candidates) {
    raw = _stringFrom(c);
    if (raw.isNotEmpty) break;
  }
  if (raw.isEmpty) {
    for (final key in ['user', 'fixer', 'fixer_profile', 'profile', 'owner']) {
      final nested = fixer[key];
      if (nested is Map) {
        final nestedRaw = fixerAvatarUrl(nested);
        if (nestedRaw.isNotEmpty) return nestedRaw;
      }
    }
  }
  return Api.resolveImageUrl(raw);
}

double? fixerRating(Map<dynamic, dynamic> fixer) {
  dynamic rating =
      fixer['rating'] ??
      fixer['avg_rating'] ??
      fixer['average_rating'] ??
      fixer['rating_avg'] ??
      fixer['reviews_avg_rating'] ??
      fixer['ratings_avg'] ??
      fixer['ratings_average'] ??
      fixer['reviews_average'] ??
      (fixer['stats'] is Map
          ? (fixer['stats']['rating'] ?? fixer['stats']['avg_rating'])
          : null);
  if (rating == null) {
    for (final key in ['user', 'fixer', 'fixer_profile', 'profile', 'owner']) {
      final nested = fixer[key];
      if (nested is Map) {
        final r = fixerRating(nested);
        if (r != null) return r;
      }
    }
  }
  if (rating == null) return null;
  return double.tryParse(rating.toString());
}
