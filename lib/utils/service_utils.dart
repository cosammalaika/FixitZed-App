import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/screens/booking_sheet.dart';
import 'package:fixitzed_app/widgets/auth_required.dart';

Map<String, dynamic>? normalizeService(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

/// Extracts a consistent service id across varied API payloads.
String serviceId(Map<dynamic, dynamic> service, {int? fallbackIndex}) {
  final dynamic id =
      service['id'] ??
      service['uuid'] ??
      service['service_id'] ??
      service['serviceId'] ??
      service['serviceID'];
  if (id != null) return id.toString();
  if (fallbackIndex != null) return fallbackIndex.toString();
  return service.hashCode.toString();
}

String? serviceCategoryLabel(Map<dynamic, dynamic> service) {
  final subcategory = service['subcategory'];
  if (subcategory is Map) {
    final candidate = (subcategory['name'] ?? subcategory['title'] ?? '')
        .toString()
        .trim();
    if (candidate.isNotEmpty) return candidate;
  }
  final category = service['category'];
  if (category is Map) {
    final candidate = (category['name'] ?? category['title'] ?? '')
        .toString()
        .trim();
    if (candidate.isNotEmpty) return candidate;
  }
  final subDirect = service['subcategory_name'] ?? service['subcategoryName'];
  if (subDirect is String && subDirect.trim().isNotEmpty) {
    return subDirect.trim();
  }
  final direct =
      service['category_name'] ??
      service['categoryName'] ??
      service['category_label'] ??
      service['categoryLabel'];
  if (direct is String && direct.trim().isNotEmpty) {
    return direct.trim();
  }
  return null;
}

Future<void> showBookingSheet(BuildContext context, {dynamic service}) async {
  final allowed = await ensureAuthenticated(
    context,
    title: 'Sign in to request a service',
    message:
        'You can keep browsing services as a guest. Sign in or create an account when you are ready to send a service request and track the booking.',
    actionLabel: 'Request service',
  );
  if (!allowed || !context.mounted) return;

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

Future<void> showServiceDetailsSheet(
  BuildContext context, {
  required dynamic service,
}) async {
  final normalized = normalizeService(service);
  if (normalized == null || normalized.isEmpty) {
    await showBookingSheet(context, service: service);
    return;
  }

  final title = (normalized['name'] ?? normalized['title'] ?? 'Service')
      .toString()
      .trim();
  final description = (normalized['description'] ?? normalized['summary'] ?? '')
      .toString()
      .trim();
  final category = serviceCategoryLabel(normalized);
  final image = (normalized['image_url'] ?? normalized['image'] ?? '')
      .toString()
      .trim();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final scheme = theme.colorScheme;
      final bottomInset = MediaQuery.of(sheetContext).padding.bottom;
      const brand = Color(0xFFF1592A);

      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          color: theme.cardColor,
          padding: EdgeInsets.fromLTRB(20, 12, 20, 18 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image(
                    image: image.startsWith('http')
                        ? NetworkImage(image) as ImageProvider
                        : AssetImage(image),
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: brand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.handyman_rounded,
                    color: brand,
                    size: 38,
                  ),
                ),
              const SizedBox(height: 18),
              if (category != null && category.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: brand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    category,
                    style: GoogleFonts.urbanist(
                      color: brand,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                title.isEmpty ? 'Service' : title,
                style: GoogleFonts.urbanist(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description.isEmpty
                    ? 'Request this service and we will match you with an available Fixer.'
                    : description,
                style: GoogleFonts.urbanist(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Future<void>.delayed(Duration.zero, () {
                      if (context.mounted) {
                        showBookingSheet(context, service: normalized);
                      }
                    });
                  },
                  icon: const Icon(Icons.event_available_rounded),
                  label: const Text('Request this service'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Continue browsing'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
