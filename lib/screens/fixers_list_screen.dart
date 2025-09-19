import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final data = await _svc.fetchFixers();
    if (!mounted) return;
    setState(() {
      _fixers = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onBackground),
        title: Text('Fixers', style: GoogleFonts.urbanist(color: Theme.of(context).colorScheme.onBackground, fontWeight: FontWeight.w700)),
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
                final name = (f['name'] ?? f['full_name'] ?? f['username'] ?? 'Fixer').toString();
                final avatar = (f['avatar'] ?? f['photo'] ?? f['image_url'] ?? '').toString();
                final skills = (f['skills'] ?? f['services'] ?? '').toString();
                final ratingRaw = f['rating'] ?? f['avg_rating'] ?? f['average_rating'];
                final rating = ratingRaw == null ? null : double.tryParse(ratingRaw.toString());
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(radius: 26, backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar.isEmpty ? const Icon(Icons.person) : null),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(name, style: GoogleFonts.urbanist(fontWeight: FontWeight.w700))),
                                if (rating != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                        const SizedBox(width: 2),
                                        Text(rating.toStringAsFixed(1), style: GoogleFonts.urbanist(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (skills.isNotEmpty)
                              Text(skills, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.urbanist(color: Colors.black54)),
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
