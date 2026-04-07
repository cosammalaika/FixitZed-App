import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/core/fixer_utils.dart';
import 'package:fixitzed_app/core/app_theme.dart';

class FixerListItem extends StatelessWidget {
  final Map fixer;
  const FixerListItem({super.key, required this.fixer});

  List<String> _serviceNames(Map f) {
    final names = <String>{};

    void addFrom(dynamic raw) {
      if (raw == null) return;
      if (raw is String) {
        final s = raw.trim();
        if (s.isNotEmpty) names.add(s);
      } else if (raw is Map) {
        final n = (raw['name'] ?? raw['title'] ?? raw['service_name'] ?? '')
            .toString()
            .trim();
        if (n.isNotEmpty) names.add(n);
      } else if (raw is List) {
        for (final e in raw) {
          addFrom(e);
          if (names.length >= 3) break;
        }
      }
    }

    // direct
    addFrom(f['services']);
    if (names.length < 3) addFrom(f['service_names']);

    // nested common keys
    if (names.length < 3) {
      for (final key in const [
        'fixer',
        'user',
        'profile',
        'fixer_profile',
        'owner',
      ]) {
        final nested = f[key];
        if (nested is Map) addFrom(nested['services']);
        if (names.length >= 3) break;
      }
    }

    return names.take(3).toList();
  }

  String _skillsOf(Map f) {
    final candidates = [
      f['skills'],
      f['skill_names'],
      f['expertise'],
      f['tags'],
      f['categories'],
      f['services'],
    ];
    for (final c in candidates) {
      if (c == null) continue;
      if (c is String) {
        final s = c.trim();
        if (s.isNotEmpty) return s;
      } else if (c is List) {
        final names = <String>[];
        for (final e in c) {
          if (e == null) continue;
          if (e is String) {
            final s = e.trim();
            if (s.isNotEmpty) names.add(s);
          } else if (e is Map) {
            final n = (e['name'] ?? e['title'] ?? e['service_name'] ?? '')
                .toString()
                .trim();
            if (n.isNotEmpty) names.add(n);
          }
        }
        if (names.isNotEmpty) return names.take(3).join(', ');
      }
    }
    // Try nested common containers
    for (final key in const [
      'fixer',
      'user',
      'profile',
      'fixer_profile',
      'owner',
    ]) {
      final nested = f[key];
      if (nested is Map) {
        final s = _skillsOf(nested);
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final name = fixerDisplayName(fixer);
    final avatar = fixerAvatarUrl(fixer);
    final rating = fixerRating(fixer);
    final skills = _skillsOf(fixer);
    final services = _serviceNames(fixer);
    final colors = Theme.of(context).fx;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipOval(
            child: SizedBox(
              width: 52,
              height: 52,
              child: avatar.isNotEmpty
                  ? Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: colors.brand,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                    )
                  : Container(
                      color: colors.brand,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (rating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: GoogleFonts.urbanist(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (services.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: List.generate(
                      services.length,
                      (j) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceRaised,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          services[j],
                          style: GoogleFonts.urbanist(
                            fontSize: 12,
                            color: colors.brand,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (skills.isNotEmpty)
                  Text(
                    skills,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(color: colors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
