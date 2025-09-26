import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api.dart';
import '../core/fixer_utils.dart';
import '../services/home_service.dart';

class FixersListScreen extends StatefulWidget {
  const FixersListScreen({super.key});

  @override
  State<FixersListScreen> createState() => _FixersListScreenState();
}

class _FixersListScreenState extends State<FixersListScreen> {
  final _svc = HomeService();
  bool _loading = true;
  List<dynamic> _fixers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _svc.fetchAllFixers();
    if (!mounted) return;
    setState(() {
      _fixers = data;
      _loading = false;
    });
  }

  String _skillsOf(Map f) {
    // Try several common shapes: string, list of strings, list of maps with name/title
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
        // Convert list elements to names
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
        if (names.isNotEmpty) {
          // Show up to 3 for compact display
          return names.take(3).join(', ');
        }
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onBackground,
        ),
        title: Text(
          'Fixers',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _fixers.length,
              itemBuilder: (ctx, i) {
                final f = _fixers[i] as Map;
                final name = fixerDisplayName(f);
                final avatar = fixerAvatarUrl(f);
                final skills = _skillsOf(f);
                final rating = fixerRating(f);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8EEE8),
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
                                    color: const Color(0xFFF1592A),
                                    child: const Icon(Icons.person, color: Colors.white),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFFF1592A),
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
                                      color: Colors.amber.withOpacity(0.15),
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
                                          style: GoogleFonts.urbanist(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (skills.isNotEmpty)
                              Text(
                                skills,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.urbanist(
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
