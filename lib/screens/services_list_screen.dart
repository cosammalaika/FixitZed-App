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
  Map<String, dynamic>? _category;
  String? _categoryName;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _category = Map<String, dynamic>.from(args);
      _categoryName = (_category!['name'] ?? _category!['title'] ?? 'Services').toString();
    }
    _initialized = true;
    _load();
  }

  Future<void> _load() async {
    final data = await _svc.fetchServices();
    final fav = (await FavoritesService.all()).toSet();
    if (!mounted) return;
    final services = data
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();

    List<Map<String, dynamic>> filtered = services;
    if (_category != null) {
      final targetId = _extractCategoryId(_category!);
      final targetName = (_category!['name'] ?? _category!['title'])?.toString().toLowerCase();
      filtered = services.where((s) {
        final cat = s['category'];
        final serviceCatId = _extractCategoryId(s);
        if (targetId != null && serviceCatId != null && targetId == serviceCatId) {
          return true;
        }
        if (targetName != null && targetName.isNotEmpty) {
          final serviceCatName = (() {
            if (cat is Map) return (cat['name'] ?? cat['title'] ?? '').toString();
            return (s['category_name'] ?? '').toString();
          })()
              .toLowerCase();
          if (serviceCatName.contains(targetName)) return true;
        }
        return false;
      }).toList();
    }
    setState(() {
      _services = filtered;
      _fav = fav;
      _loading = false;
    });
  }

  int? _extractCategoryId(Map<dynamic, dynamic> source) {
    final dynamic catField = source['category'] is Map ? (source['category'] as Map)['id'] : source['category_id'] ?? source['id'];
    final dynamic id = catField ?? source['category_id'] ?? source['categoryId'];
    if (id == null) return null;
    if (id is num) return id.toInt();
    if (id is String) return int.tryParse(id);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onBackground),
        title: Text(
          _categoryName ?? 'Services',
          style: GoogleFonts.urbanist(color: Theme.of(context).colorScheme.onBackground, fontWeight: FontWeight.w700),
        ),
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
