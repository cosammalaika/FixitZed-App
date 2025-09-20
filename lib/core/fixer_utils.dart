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

  final direct = _firstNonEmpty([
    data['name'],
    data['full_name'],
    data['fullName'],
    data['display_name'],
    data['username'],
    data['title'],
  ]);
  if (direct != null) return direct;

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
