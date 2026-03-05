String normalizeZambianNumber(String phone) {
  final trimmed = phone.trim();
  if (trimmed.isEmpty) return trimmed;

  final compact = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');

  if (compact.startsWith('+260')) {
    return compact;
  }

  if (compact.startsWith('260')) {
    return '+$compact';
  }

  if (compact.startsWith('0')) {
    return '+260${compact.substring(1)}';
  }

  if (compact.startsWith('9')) {
    return '+260$compact';
  }

  if (compact.length == 9) {
    return '+260$compact';
  }

  return compact;
}

String formatZambianNumberForDisplay(String phone) {
  final normalized = normalizeZambianNumber(phone);
  if (!normalized.startsWith('+260')) return normalized;

  final local = normalized.substring(4);
  if (!RegExp(r'^\d{9}$').hasMatch(local)) return normalized;

  return '+260 ${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
}
