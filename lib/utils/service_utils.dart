import 'package:flutter/material.dart';

import '../screens/booking_sheet.dart';

Map<String, dynamic>? normalizeService(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

String? serviceCategoryLabel(Map<dynamic, dynamic> service) {
  final category = service['category'];
  if (category is Map) {
    final candidate = (category['name'] ?? category['title'] ?? '').toString().trim();
    if (candidate.isNotEmpty) return candidate;
  }
  final direct = service['category_name'] ??
      service['categoryName'] ??
      service['category_label'] ??
      service['categoryLabel'];
  if (direct is String && direct.trim().isNotEmpty) {
    return direct.trim();
  }
  return null;
}

Future<void> showBookingSheet(BuildContext context, {dynamic service}) {
  final normalized = normalizeService(service);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => BookingSheet(initialService: normalized),
  );
}
