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
  late final TextEditingController _searchCtrl;
  bool _loading = true;
  List<Map<String, dynamic>> _allServices = const [];
  List<Map<String, dynamic>> _services = const [];
  Set<String> _fav = {};
  Map<String, dynamic>? _category;
  String? _categoryName;
  bool _initialized = false;
  String _searchTerm = '';
  List<Map<String, dynamic>> _categoryOptions = const [];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      if (args.containsKey('category') ||
          args.containsKey('query') ||
          args.containsKey('categories')) {
        final rawCategory = args['category'];
        if (rawCategory is Map) {
          _category = Map<String, dynamic>.from(rawCategory as Map);
          _categoryName =
              (_category!['name'] ?? _category!['title'] ?? 'Services').toString();
        } else if (rawCategory is Map<String, dynamic>) {
          _category = Map<String, dynamic>.from(rawCategory);
          _categoryName =
              (_category!['name'] ?? _category!['title'] ?? 'Services').toString();
        }

        final query = args['query'];
        if (query is String && query.trim().isNotEmpty) {
          _searchTerm = query.trim();
          _searchCtrl.text = _searchTerm;
        }

        final categories = args['categories'];
        if (categories is List) {
          _categoryOptions = categories
              .whereType<Map>()
              .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
              .toList();
        }
      } else {
        _category = Map<String, dynamic>.from(args);
        _categoryName =
            (_category!['name'] ?? _category!['title'] ?? 'Services').toString();
      }
    }
    if (_categoryName == null) {
      _categoryName = 'Services';
    }
    _initialized = true;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _svc.fetchServices();
    final fav = (await FavoritesService.all()).toSet();
    if (!mounted) return;
    final services = data
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();

    if (_categoryOptions.isEmpty) {
      _categoryOptions = _deriveCategoryOptions(services);
    }

    setState(() {
      _allServices = services;
      _fav = fav;
    });
    _applyFilters();
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      setState(() {
                        _searchTerm = value.trim();
                      });
                      _applyFilters();
                    },
                    onSubmitted: (_) => _applyFilters(),
                    decoration: InputDecoration(
                      hintText: 'Search services',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _FilterButton(
                  onTap: _openFilterSheet,
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _services.length,
              itemBuilder: (ctx, i) {
                final s = _services[i];
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

class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FilterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.tune_rounded),
      ),
    );
  }
}
