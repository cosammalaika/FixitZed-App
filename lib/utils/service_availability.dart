int? _parseCount(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool? _parseFlag(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value > 0;
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

int? serviceAvailableFixersCount(Map<dynamic, dynamic> service) {
  final count = _parseCount(
    service['available_fixers_count'] ??
        service['availableFixersCount'] ??
        service['opted_in_fixers_count'] ??
        service['ready_fixers_count'] ??
        service['readyFixersCount'] ??
        service['fixers_count'] ??
        service['fixersCount'],
  );
  if (count != null) return count;

  final flag = serviceHasAvailableFixersFlag(service);
  if (flag != null) return flag ? 1 : 0;

  final fixers = service['fixers'];
  if (fixers is List) return fixers.length;

  return null;
}

bool? serviceHasAvailableFixersFlag(Map<dynamic, dynamic> service) {
  return _parseFlag(
    service['has_available_fixers'] ??
        service['hasAvailableFixers'] ??
        service['has_fixers'] ??
        service['hasFixers'] ??
        service['has_ready_fixers'] ??
        service['hasReadyFixers'] ??
        service['has_opted_in_fixers'] ??
        service['hasOptedInFixers'],
  );
}

bool serviceHasAvailableFixers(Map<dynamic, dynamic> service) {
  final count = serviceAvailableFixersCount(service);
  if (count != null) return count > 0;
  return serviceHasAvailableFixersFlag(service) ?? false;
}
