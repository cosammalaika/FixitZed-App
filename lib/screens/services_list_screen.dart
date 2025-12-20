import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fixitzed_app/repositories/categories_repository.dart';
import 'package:fixitzed_app/repositories/services_repository.dart';
import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/repositories/favorites_repository.dart';
import 'package:fixitzed_app/utils/service_utils.dart';
import 'package:fixitzed_app/widgets/skeletons.dart';
import 'package:fixitzed_app/screens/widgets/service_list_tile.dart';
import 'package:fixitzed_app/utils/app_snack.dart';

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  late final ServicesRepository _servicesRepository;
  late final CategoriesRepository _categoriesRepository;
  late final FavoritesRepository _favoritesRepository;
  late final ProviderContainer _container;
  late final TextEditingController _searchCtrl;
  bool _loading = true;
  List<Map<String, dynamic>> _allServices = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _services = const <Map<String, dynamic>>[];
  Set<String> _fav = {};
  final Set<String> _availabilityLog = <String>{};
  Map<String, dynamic>? _category;
  String? _categoryName;
  bool _initialized = false;
  String _searchTerm = '';
  List<Map<String, dynamic>> _categoryOptions = const <Map<String, dynamic>>[];
  late final VoidCallback _favListener;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _servicesRepository = _container.read(servicesRepositoryProvider);
    _categoriesRepository = _container.read(categoriesRepositoryProvider);
    _favoritesRepository = _container.read(favoritesRepositoryProvider);
    _searchCtrl = TextEditingController();
    _categoryOptions = const <Map<String, dynamic>>[];
    _favListener = () {
      if (!mounted) return;
      setState(() {
        _fav = _favoritesRepository.ids;
      });
    };
    _favoritesRepository.addListener(_favListener);
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
          _category = Map<String, dynamic>.from(rawCategory);
          _categoryName =
              (_category!['name'] ?? _category!['title'] ?? 'Services')
                  .toString();
        } else if (rawCategory is Map<String, dynamic>) {
          _category = Map<String, dynamic>.from(rawCategory);
          _categoryName =
              (_category!['name'] ?? _category!['title'] ?? 'Services')
                  .toString();
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
              .map<Map<String, dynamic>>(
                (e) =>
                    e.map((key, value) => MapEntry(key.toString(), value)),
              )
              .toList();
        }
      } else {
        _category = Map<String, dynamic>.from(args);
        _categoryName =
            (_category!['name'] ?? _category!['title'] ?? 'Services')
                .toString();
      }
    }
    _categoryName ??= 'Services';
    _initialized = true;
    _primeFromCache();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _favoritesRepository.removeListener(_favListener);
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted && _services.isEmpty) {
      setState(() {
        _loading = true;
      });
    }
    final data = await _servicesRepository.getServices();
    final fav = await _favoritesRepository.getFavoriteIds();
    if (!mounted) return;
    final services = data
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();

    for (final service in services) {
      final sub = service['subcategory'];
      if (sub is Map) {
        final subId = sub['id'];
        final subName = sub['name'] ?? sub['title'];
        service.putIfAbsent('subcategory_id', () => subId);
        if (subName is String && subName.trim().isNotEmpty) {
          service.putIfAbsent('subcategory_name', () => subName.trim());
        }
      }
    }

    setState(() {
      _allServices = services;
      _fav = fav;
      if (_categoryOptions.isEmpty) {
        _categoryOptions = _deriveCategoryOptions(services);
      }
    });
    _applyFilters();
  }

  void _primeFromCache() {
    final cachedServices = _servicesRepository.cached ?? const <dynamic>[];
    if (cachedServices.isNotEmpty) {
      final services = cachedServices
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
      _allServices = services;
      _services = services;
      if (_categoryOptions.isEmpty) {
        _categoryOptions = _deriveCategoryOptions(services);
      }
      _loading = false;
    }
    if (_categoryOptions.isEmpty) {
      final cachedCategories =
          _categoriesRepository.cachedSubcategories ?? const <dynamic>[];
      _categoryOptions = cachedCategories
          .whereType<Map>()
          .map<Map<String, dynamic>>(
            (e) => e.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
    }
  }

  int? _extractSubcategoryId(Map source) {
    final dynamic subField = source['subcategory'] is Map
        ? (source['subcategory'] as Map)['id']
        : source['subcategory_id'] ?? source['id'];
    final dynamic id =
        subField ?? source['subcategory_id'] ?? source['subcategoryId'];
    if (id == null) return null;
    if (id is num) return id.toInt();
    if (id is String) return int.tryParse(id);
    return null;
  }

  bool _isSameCategory(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (a == null || b == null) return false;
    final aId = _extractSubcategoryId(a);
    final bId = _extractSubcategoryId(b);
    if (aId != null && bId != null) return aId == bId;
    final aName = (a['name'] ?? a['title'] ?? '').toString().toLowerCase();
    final bName = (b['name'] ?? b['title'] ?? '').toString().toLowerCase();
    if (aName.isEmpty || bName.isEmpty) return false;
    return aName == bName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          _categoryName ?? 'Services',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
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
                      _searchTerm = value.trim();
                      _applyFilters();
                    },
                    onSubmitted: (_) => _applyFilters(),
                    decoration: InputDecoration(
                      hintText: 'Search services',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchTerm.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Clear search',
                              onPressed: () {
                                if (_searchTerm.isEmpty) return;
                                _searchCtrl.clear();
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  _searchTerm = '';
                                });
                                _applyFilters();
                              },
                            ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _FilterButton(onTap: _openFilterSheet),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const ServicesListSkeleton()
            : _services.isEmpty
            ? _EmptyServicesState(
                searchQuery: _searchTerm,
                categoryLabel: _categoryName,
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _services.length,
                itemBuilder: (ctx, i) {
                  final s = _services[i];
                  final id = serviceId(s, fallbackIndex: i);
                  final title = (s['name'] ?? s['title'] ?? 'Service')
                      .toString();
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
                  final liked = _fav.contains(id);
                  final availability = _availabilityForService(s, id);
                  return GestureDetector(
                    onTap: () {
                      if (availability == ServiceAvailability.unavailable) {
                        AppSnack.show(
                          'No fixer opted in yet',
                          actionLabel: 'Browse',
                          onAction: () => AppSnack.scaffoldMessengerKey.currentState?.hideCurrentSnackBar(),
                        );
                        return;
                      }
                      showBookingSheet(context, service: s);
                    },
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: GoogleFonts.urbanist(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (subtitle.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                                right: 8,
                                              ),
                                              child: Text(
                                                subtitle,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.urbanist(
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _AvailabilityPill(availability: availability),
                                    IconButton(
                                      icon: Icon(
                                        liked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: liked ? Colors.red : Colors.grey,
                                      ),
                                      onPressed: () async {
                                        final previous = Set<String>.from(_fav);
                                        final optimistic = Set<String>.from(_fav);
                                        if (optimistic.contains(id)) {
                                          optimistic.remove(id);
                                        } else {
                                          optimistic.add(id);
                                        }
                                        if (mounted) {
                                          setState(() => _fav = optimistic);
                                        }
                                        try {
                                          await _favoritesRepository.toggle(id);
                                          if (!mounted) return;
                                          setState(() => _fav = _favoritesRepository.ids);
                                        } catch (_) {
                                          if (!mounted) return;
                                          setState(() => _fav = previous);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Could not update favorites right now.'),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
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
      ),
    );
  }

  void _applyFilters() {
    var filtered = List<Map<String, dynamic>>.from(_allServices);

    if (_category != null) {
      final targetId = _extractSubcategoryId(_category!);
      final targetName = (_category!['name'] ?? _category!['title'])
          ?.toString()
          .toLowerCase();
      filtered = filtered.where((service) {
        final cat = service['subcategory'];
        final serviceCatId = _extractSubcategoryId(service);
        if (targetId != null &&
            serviceCatId != null &&
            targetId == serviceCatId) {
          return true;
        }
        if (targetName != null && targetName.isNotEmpty) {
          final serviceCatName = (() {
            if (cat is Map) {
              return (cat['name'] ?? cat['title'] ?? '').toString();
            }
            return (service['subcategory_name'] ?? '').toString();
          })().toLowerCase();
          if (serviceCatName.contains(targetName)) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    if (_searchTerm.isNotEmpty) {
      final term = _searchTerm.toLowerCase();
      filtered = filtered.where((service) {
        final parts = [
          service['name'],
          service['title'],
          service['description'],
          service['summary'],
          service['service_name'],
          service['subcategory_name'],
          service['keywords'],
          service['tags'],
        ];
        final match = parts.any(
          (value) =>
              value != null && value.toString().toLowerCase().contains(term),
        );
        if (match) return true;
        final subcategory = service['subcategory'];
        if (subcategory is Map) {
          final nested = (subcategory['name'] ?? subcategory['title'] ?? '')
              .toString()
              .toLowerCase();
          if (nested.contains(term)) return true;
        }
        return false;
      }).toList();
    }

    setState(() {
      _services = filtered;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _deriveCategoryOptions(
    List<Map<String, dynamic>> services,
  ) {
    final seen = <String>{};
    final options = <Map<String, dynamic>>[];
    for (final service in services) {
      Map<String, dynamic>? subcategory;
      final rawSubcategory = service['subcategory'];
      if (rawSubcategory is Map) {
        subcategory = rawSubcategory.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      } else {
        final id = service['subcategory_id'] ?? service['subcategoryId'];
        final name = (service['subcategory_name'] ?? '').toString();
        if (id != null || name.isNotEmpty) {
          subcategory = {
            if (id != null) 'id': id,
            'name': name.isNotEmpty ? name : 'Subcategory',
          };
        }
      }
      if (subcategory == null) continue;
      final key = '${subcategory['id'] ?? ''}-${(subcategory['name'] ?? '').toString().toLowerCase()}';
      if (seen.add(key)) {
        options.add(subcategory);
      }
    }
    return options;
  }

  int? _readyCount(Map<dynamic, dynamic> service) {
    final val = service['opted_in_fixers_count'] ??
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
    final raw = service['has_ready_fixers'] ??
        service['hasReadyFixers'] ??
        service['has_fixers'] ??
        service['hasFixers'] ??
        service['has_opted_in_fixers'] ??
        service['hasOptedInFixers'];
    if (raw is bool) return raw;
    if (raw is num) return raw > 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  ServiceAvailability _availabilityForService(
    Map<dynamic, dynamic> service,
    String id,
  ) {
    final readyCount = _readyCount(service);
    final hasFixers = readyCount != null
        ? readyCount > 0
        : (_hasReadyFlag(service) ?? false);
    assert(() {
      if (_availabilityLog.add(id)) {
        debugPrint(
          'Service availability: ${service['name'] ?? service['title'] ?? 'service'} -> opted_in_fixers_count=${readyCount ?? 'n/a'}; hasFixers=$hasFixers',
        );
      }
      return true;
    }());
    return hasFixers
        ? ServiceAvailability.available
        : ServiceAvailability.unavailable;
  }

  Future<void> _openFilterSheet() async {
    final options = _categoryOptions.isNotEmpty
        ? _categoryOptions
        : _deriveCategoryOptions(_allServices);
    final selection = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Filter services',
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (_) {
                    final allSelected = _category == null;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.grid_view_rounded),
                      title: const Text('All subcategories'),
                      trailing: allSelected
                          ? const Icon(Icons.check_rounded,
                              color: Color(0xFFF1592A))
                          : null,
                      selected: allSelected,
                      selectedTileColor: const Color(0x1AF1592A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop({'__all': true});
                        FocusScope.of(context).unfocus();
                      },
                    );
                  },
                ),
                if (options.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No subcategories available yet. Try refreshing the list.',
                      style: GoogleFonts.urbanist(color: Colors.black54),
                    ),
                  )
                else
                  ...options.map((cat) {
                    final label =
                        (cat['name'] ?? cat['title'] ?? 'Category').toString();
                    final selected = _isSameCategory(_category, cat);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.label_rounded),
                        title: Text(label),
                        selected: selected,
                        selectedTileColor: const Color(0x1AF1592A),
                        trailing: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Color(0xFFF1592A),
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop(cat);
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selection == null) return;

    if (selection.containsKey('__all')) {
      setState(() {
        _category = null;
        _categoryName = 'Services';
      });
    } else {
      setState(() {
        _category = selection;
        _categoryName =
            (_category!['name'] ?? _category!['title'] ?? 'Services')
                .toString();
      });
    }
    _applyFilters();
  }
}

class _AvailabilityPill extends StatelessWidget {
  final ServiceAvailability availability;
  const _AvailabilityPill({required this.availability});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;

    switch (availability) {
      case ServiceAvailability.available:
        bg = Colors.green.withOpacity(0.12);
        text = Colors.green.shade800;
        label = 'Fixers available';
        break;
      case ServiceAvailability.unavailable:
        bg = Colors.orange.withOpacity(0.12);
        text = Colors.orange.shade800;
        label = 'No fixers yet';
        break;
      case ServiceAvailability.unknown:
      default:
        bg = Colors.black.withOpacity(0.06);
        text = Colors.black54;
        label = 'Availability unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.urbanist(
          color: text,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
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
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.tune_rounded),
      ),
    );
  }
}

class _EmptyServicesState extends StatelessWidget {
  final String searchQuery;
  final String? categoryLabel;
  const _EmptyServicesState({
    required this.searchQuery,
    required this.categoryLabel,
  });

  @override
  Widget build(BuildContext context) {
    String message;
    if (searchQuery.isNotEmpty) {
      message = 'No services found for "$searchQuery".';
    } else if (categoryLabel != null &&
        categoryLabel!.toLowerCase() != 'services') {
      message = 'No services available under "$categoryLabel" yet.';
    } else {
      message = 'No services available at the moment. Please check back soon.';
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 160),
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.content_paste_off_rounded,
                size: 56,
                color: Color(0xFFC6CBD1),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
