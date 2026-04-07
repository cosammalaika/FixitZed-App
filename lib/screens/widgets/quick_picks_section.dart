import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/core/app_theme.dart';

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

  int? _readyCount(Map<dynamic, dynamic> service) {
    final val =
        service['opted_in_fixers_count'] ??
        service['ready_fixers_count'] ??
        service['readyFixersCount'] ??
        service['fixers_count'] ??
        service['fixersCount'];
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    final hasFlag = _hasReadyFlag(service);
    if (hasFlag != null) return hasFlag ? 1 : 0;
    final fixers = service['fixers'];
    if (fixers is List) return fixers.length;
    return null;
  }

  bool? _hasReadyFlag(Map<dynamic, dynamic> service) {
    final raw =
        service['has_fixers'] ??
        service['hasFixers'] ??
        service['has_ready_fixers'] ??
        service['hasReadyFixers'] ??
        service['has_opted_in_fixers'] ??
        service['hasOptedInFixers'];
    if (raw is bool) return raw;
    if (raw is num) return raw > 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).fx;
    final filtered = services
        .whereType<Map>()
        .where((map) {
          final count = _readyCount(map);
          final hasFixers = count != null
              ? count > 0
              : (_hasReadyFlag(map) ?? false);
          return hasFixers || services.length <= limit;
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
                  color: colors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...filtered.map((svc) {
          final count = _readyCount(svc);
          final hasFixers = count != null
              ? count > 0
              : (_hasReadyFlag(svc) ?? false);
          return QuickPickTile(
            title: (svc['name'] ?? svc['title'] ?? 'Service').toString(),
            subtitle:
                (svc['category_name'] ??
                        svc['subcategory_name'] ??
                        svc['category']?['name'] ??
                        svc['subcategory']?['name'] ??
                        svc['description'] ??
                        '')
                    .toString(),
            icon: Icons.build_rounded,
            available: hasFixers,
            onTap: () => onTapService(svc),
          );
        }),
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
    required this.available,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).fx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surface,
        elevation: 0,
        shadowColor: colors.shadow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.surfaceTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: colors.brand),
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
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle.isEmpty ? 'Tap to book quickly' : subtitle,
                        style: GoogleFonts.urbanist(
                          color: colors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _AvailabilityPill(available: available),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  final bool available;
  const _AvailabilityPill({required this.available});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).fx;
    final bg = available ? colors.successContainer : colors.surfaceSubtle;
    final text = available ? colors.success : colors.textSecondary;
    final label = available ? 'Available' : 'No fixers';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            size: 14,
            color: text,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.urbanist(
              color: text,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
