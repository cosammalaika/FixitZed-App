import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/services/home_service.dart';
import 'package:fixitzed_app/services/favorites_service.dart';
import 'package:fixitzed_app/utils/service_utils.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _svc = HomeService();
  bool _loading = true;
  List<Map<String, dynamic>> _favoriteServices = const [];
  Set<String> _favIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final services = await _svc.fetchServices();
    final fav = (await FavoritesService.all()).toSet();
    final favList = <Map<String, dynamic>>[];
    for (var i = 0; i < services.length; i++) {
      final s = services[i];
      if (s is Map) {
        final id = (s['id'] ?? s['uuid'] ?? '$i').toString();
        if (fav.contains(id)) {
          favList.add(Map<String, dynamic>.from(s));
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _favIds = fav;
      _favoriteServices = favList;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          'Favorites',
          style: GoogleFonts.urbanist(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_favoriteServices.isEmpty
              ? _emptyState(context)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _favoriteServices.length,
                    itemBuilder: (ctx, i) {
                      final s = _favoriteServices[i];
                      final id = (s['id'] ?? s['uuid'] ?? '$i').toString();
                      final title = (s['name'] ?? s['title'] ?? 'Service').toString();
                      final description =
                          (s['description'] ?? s['summary'] ?? '')
                              .toString()
                              .trim();
                      final category = serviceCategoryLabel(s);
                      final subtitle = category ??
                          (description.isEmpty
                              ? 'Tap to book quickly'
                              : description);
                      final img = (s['image'] ?? s['image_url'] ?? '').toString();
                      final liked = _favIds.contains(id);
                      return GestureDetector(
                        onTap: () => showBookingSheet(context, service: s),
                        child: Container(
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
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.handyman_rounded,
                                          color: Colors.grey,
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
                                            title,
                                            style: GoogleFonts.urbanist(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            liked
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: liked ? Colors.red : Colors.grey,
                                          ),
                                          onPressed: () async {
                                            await FavoritesService.toggle(id);
                                            await _load();
                                          },
                                        ),
                                      ],
                                    ),
                                    if (subtitle.isNotEmpty)
                                      Text(
                                        subtitle,
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
                        ),
                      );
                    },
                  ),
                )),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No favorites yet',
              style: GoogleFonts.urbanist(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the heart on any service to add it here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
