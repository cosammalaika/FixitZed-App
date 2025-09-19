import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/home_service.dart';
import '../services/favorites_service.dart';

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  final _svc = HomeService();
  bool _loading = true;
  List<dynamic> _services = const [];
  Set<String> _fav = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _svc.fetchServices();
    final fav = (await FavoritesService.all()).toSet();
    if (!mounted) return;
    setState(() {
      _services = data;
      _fav = fav;
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
        title: Text('Services', style: GoogleFonts.urbanist(color: Theme.of(context).colorScheme.onBackground, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _services.length,
              itemBuilder: (ctx, i) {
                final s = _services[i] as Map;
                final id = (s['id'] ?? s['uuid'] ?? '$i').toString();
                final title = (s['name'] ?? s['title'] ?? 'Service').toString();
                final subtitle = (s['description'] ?? s['summary'] ?? '').toString();
                final img = (s['image'] ?? s['image_url'] ?? '').toString();
                final liked = _fav.contains(id);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: img.isNotEmpty
                            ? Image(
                                image: img.startsWith('http')
                                    ? NetworkImage(img) as ImageProvider
                                    : AssetImage(img),
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.handyman_rounded, color: Colors.grey),
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
                                  child: Text(title, style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
                                ),
                                IconButton(
                                  icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red : Colors.grey),
                                  onPressed: () async {
                                    await FavoritesService.toggle(id);
                                    final fav = (await FavoritesService.all()).toSet();
                                    if (!mounted) return;
                                    setState(() => _fav = fav);
                                  },
                                ),
                              ],
                            ),
                            if (subtitle.isNotEmpty)
                              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.urbanist(color: Colors.black54)),
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
