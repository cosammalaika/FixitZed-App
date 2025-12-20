import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickPicksSection extends StatelessWidget {
  const QuickPicksSection({
    super.key,
    required this.services,
    required this.availableServiceIds,
    required this.onTapService,
    required this.onViewAll,
    this.limit = 4,
  });

  final List<dynamic> services;
  final Set<String> availableServiceIds;
  final ValueChanged<Map<String, dynamic>> onTapService;
  final VoidCallback onViewAll;
  final int limit;

  String _serviceId(Map<dynamic, dynamic> service) {
    final dynamic id =
        service['id'] ?? service['uuid'] ?? service['service_id'];
    return id?.toString() ?? '';
  }

  int? _readyCount(Map<dynamic, dynamic> service) {
    final val = service['ready_fixers_count'] ?? service['readyFixersCount'];
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = services
        .whereType<Map>()
        .where((map) {
          final id = _serviceId(map);
          final count = _readyCount(map);
          final hasCount = count != null && count > 0;
          final inActiveSet =
              availableServiceIds.isNotEmpty && availableServiceIds.contains(id);
          return hasCount || inActiveSet;
        })
        .take(limit)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Quick picks for you',
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'View All',
                style: GoogleFonts.urbanist(
                  color: const Color(0xFFF1592A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...filtered.map(
          (svc) => QuickPickTile(
            title: (svc['name'] ?? svc['title'] ?? 'Service').toString(),
            subtitle: (svc['category_name'] ??
                    svc['subcategory_name'] ??
                    svc['category']?['name'] ??
                    svc['subcategory']?['name'] ??
                    svc['description'] ??
                    '')
                .toString(),
            icon: Icons.build_rounded,
            onTap: () => onTapService(svc),
          ),
        ),
      ],
    );
  }
}

class QuickPickTile extends StatelessWidget {
  const QuickPickTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.03)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0x1AF1592A),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: const Color(0xFFF1592A)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle.isEmpty ? 'Tap to book quickly' : subtitle,
                        style: GoogleFonts.urbanist(color: Colors.black54),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
