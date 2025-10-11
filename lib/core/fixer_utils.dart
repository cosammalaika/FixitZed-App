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

bool _hintSuggestsPercent(String? hint) {
  if (hint == null) return false;
  final lower = hint.toLowerCase();
  return lower.contains('percent') ||
      lower.contains('percentage') ||
      lower.contains('pct');
}

double _percentToFive(num percent) {
  final normalized = percent.clamp(0, 100);
  return normalized.toDouble() / 20;
}

double? _parseRatingValue(dynamic value, Set<int> seen, {String? hint}) {
  if (value == null) return null;
  if (value is num) {
    var doubleValue = value.toDouble();
    if (doubleValue.isNaN || doubleValue.isInfinite) return null;
    if (doubleValue < 0) doubleValue = 0;
    if (_hintSuggestsPercent(hint)) {
      return _percentToFive(doubleValue);
    }
    if (doubleValue <= 5) {
      return doubleValue;
    }
    if (doubleValue <= 10) {
      return doubleValue / 2;
    }
    var normalized = doubleValue;
    for (var i = 0; i < 6 && normalized > 100; i++) {
      normalized /= 10;
    }
    if (normalized <= 100) {
      return _percentToFive(normalized);
    }
    return doubleValue > 5 ? 5.0 : doubleValue;
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll(',', '');
    final percentHint = _hintSuggestsPercent(hint) || normalized.contains('%');
    final withoutPercent = normalized.replaceAll('%', '');
    double? parsed = double.tryParse(withoutPercent);
    if (parsed == null) {
      final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(withoutPercent);
      if (match != null) {
        parsed = double.tryParse(match.group(0)!);
      }
    }
    if (parsed != null) {
      if (!percentHint && withoutPercent.contains('/100')) {
        return _percentToFive(parsed);
      }
      if (!percentHint && withoutPercent.contains('/10')) {
        return parsed / 2;
      }
      if (percentHint) {
        return _percentToFive(parsed);
      }
      return parsed;
    }
    return null;
  }
  if (value is bool) {
    return value ? 5.0 : 0.0;
  }
  if (value is Map) {
    final identity = identityHashCode(value);
    if (!seen.add(identity)) return null;

    const skipKeys = {
      'id',
      'uuid',
      'user_id',
      'fixer_id',
      'service_id',
      'name',
      'first_name',
      'firstname',
      'last_name',
      'lastname',
      'username',
      'email',
      'phone',
      'phone_number',
      'description',
      'bio',
      'about',
      'services',
      'skills',
      'tags',
      'created_at',
      'updated_at',
      'avatar',
      'image',
      'photo',
      'address',
      'location',
      'city',
      'country',
      'state',
      'province',
      'district',
      'ward',
      'street',
      'lat',
      'lng',
      'latitude',
      'longitude',
      'availability',
      'is_active',
      'active',
      'status',
      'verified',
      'experience',
      'role',
      'category',
      'category_id',
      'categories',
    };

    bool isAverageField(String lower) {
      return lower == 'rating' ||
          lower == 'score' ||
          lower == 'value' ||
          lower == 'stars' ||
          lower.contains('avg') ||
          lower.contains('average') ||
          lower.contains('mean') ||
          lower.contains('overall') ||
          lower.contains('star_rating') ||
          lower.contains('rating_value') ||
          (lower.contains('score') &&
              !lower.contains('score_sum') &&
              !lower.contains('score_count'));
    }

    bool isSumKey(String lower) {
      return lower == 'sum' ||
          lower.contains('sum_') ||
          lower.endsWith('_sum') ||
          lower.contains('score_total') ||
          lower.contains('total_score') ||
          lower.contains('total_points') ||
          lower.contains('rating_sum');
    }

    bool isCountKey(String lower) {
      return lower == 'count' ||
          lower.endsWith('_count') ||
          lower.contains('total_reviews') ||
          lower.contains('reviews_total') ||
          lower.contains('ratings_count') ||
          lower.contains('rating_count') ||
          lower.contains('num_ratings') ||
          lower.contains('number_of_ratings') ||
          lower.contains('total_votes') ||
          lower.contains('votes_count');
    }

    for (final entry in value.entries) {
      final keyStr = entry.key.toString();
      final lowerKey = keyStr.toLowerCase();
      if (isAverageField(lowerKey)) {
        final parsed = _parseRatingValue(entry.value, seen, hint: keyStr);
        if (parsed != null) return parsed;
      }
    }

    double? sum;
    double? count;
    for (final entry in value.entries) {
      final keyStr = entry.key.toString();
      final lowerKey = keyStr.toLowerCase();
      if (sum == null && isSumKey(lowerKey)) {
        sum = _parseRatingValue(entry.value, seen, hint: keyStr);
      }
      if (count == null && isCountKey(lowerKey)) {
        count = _parseRatingValue(entry.value, seen, hint: keyStr);
      }
    }
    if (sum != null && count != null && count > 0) {
      final avg = sum / count;
      return avg;
    }

    double bucketSum = 0;
    double bucketCount = 0;
    var bucketFound = false;
    for (final entry in value.entries) {
      final keyStr = entry.key.toString();
      final lowerKey = keyStr.toLowerCase();
      final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(lowerKey);
      if (match != null &&
          (lowerKey.contains('star') ||
              lowerKey.contains('rating') ||
              lowerKey.startsWith('star') ||
              lowerKey.length <= 3)) {
        final bucketValue = double.tryParse(match.group(0)!);
        final bucketFreq = _parseRatingValue(entry.value, seen, hint: keyStr);
        if (bucketValue != null && bucketFreq != null && bucketFreq > 0) {
          bucketSum += bucketValue * bucketFreq;
          bucketCount += bucketFreq;
          bucketFound = true;
        }
      }
    }
    if (bucketFound && bucketCount > 0) {
      return bucketSum / bucketCount;
    }

    for (final entry in value.entries) {
      final keyStr = entry.key.toString();
      final lowerKey = keyStr.toLowerCase();
      if (skipKeys.contains(lowerKey)) continue;
      if (isCountKey(lowerKey) || isSumKey(lowerKey)) continue;
      final parsed = _parseRatingValue(entry.value, seen, hint: keyStr);
      if (parsed != null) return parsed;
    }
    return null;
  }

  if (value is Iterable) {
    double sum = 0;
    int count = 0;
    for (final item in value) {
      final parsed = _parseRatingValue(item, Set<int>.from(seen), hint: hint);
      if (parsed != null) {
        sum += parsed;
        count++;
      }
    }
    if (count > 0) {
      return sum / count;
    }
  }

  return null;
}

double? fixerRating(Map<dynamic, dynamic> fixer) {
  double? zeroCandidate;

  double? attempt(String? hint, dynamic candidate) {
    if (candidate == null) return null;
    final parsed = _parseRatingValue(candidate, <int>{}, hint: hint);
    if (parsed == null) return null;
    if (parsed > 0.01) return parsed;
    zeroCandidate ??= parsed;
    return null;
  }

  final candidates = <MapEntry<String?, dynamic>>[
    MapEntry('rating', fixer['rating']),
    MapEntry('avg_rating', fixer['avg_rating']),
    MapEntry('average_rating', fixer['average_rating']),
    MapEntry('rating_avg', fixer['rating_avg']),
    MapEntry('reviews_avg_rating', fixer['reviews_avg_rating']),
    MapEntry('ratings_avg', fixer['ratings_avg']),
    MapEntry('ratings_average', fixer['ratings_average']),
    MapEntry('reviews_average', fixer['reviews_average']),
    MapEntry('rating_percentage', fixer['rating_percentage']),
    MapEntry('rating_percent', fixer['rating_percent']),
    MapEntry('score', fixer['score']),
    MapEntry('stats', fixer['stats']),
    MapEntry('metrics', fixer['metrics']),
    MapEntry('aggregates', fixer['aggregates']),
    MapEntry('rating_summary', fixer['rating_summary']),
    MapEntry('ratings_summary', fixer['ratings_summary']),
    MapEntry('review_summary', fixer['review_summary']),
    MapEntry('reviews_summary', fixer['reviews_summary']),
    MapEntry('rating_details', fixer['rating_details']),
    MapEntry('reviews', fixer['reviews']),
    MapEntry('ratings', fixer['ratings']),
    MapEntry(null, fixer),
  ];

  for (final entry in candidates) {
    final result = attempt(entry.key, entry.value);
    if (result != null) return result;
  }

  for (final key in ['user', 'fixer', 'fixer_profile', 'profile', 'owner']) {
    final nested = fixer[key];
    final result = attempt(key, nested);
    if (result != null) return result;
  }

  return zeroCandidate;
}
