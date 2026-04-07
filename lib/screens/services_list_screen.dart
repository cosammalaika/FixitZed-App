import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fixitzed_app/repositories/categories_repository.dart';
import 'package:fixitzed_app/repositories/services_repository.dart';
import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/repositories/favorites_repository.dart';
import 'package:fixitzed_app/services/chooser_availability_service.dart';
import 'package:fixitzed_app/utils/service_utils.dart';
import 'package:fixitzed_app/widgets/skeletons.dart';
import 'package:fixitzed_app/screens/widgets/service_list_tile.dart';
import 'package:fixitzed_app/utils/app_snack.dart';
import 'package:fixitzed_app/widgets/auth_required.dart';

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen>
    with WidgetsBindingObserver {
  late final ServicesRepository _servicesRepository;
  late final CategoriesRepository _categoriesRepository;
  late final FavoritesRepository _favoritesRepository;
  late final ProviderContainer _container;
  late final TextEditingController _searchCtrl;
  bool _loading = true;
  List<Map<String, dynamic>> _allServices = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _services = const <Map<String, dynamic>>[];
  Set<String> _fav = {};
  final FixerAvailabilityResolver _availabilityResolver =
      FixerAvailabilityResolver();
  Map<String, FixerAvailability> _availabilityByServiceId =
      const <String, FixerAvailability>{};
  String _availabilityCacheKey = '';
  bool _resolvingAvailability = false;
  Map<String, dynamic>? _category;
  String? _categoryName;
  bool _initialized = false;
  String _searchTerm = '';
  List<Map<String, dynamic>> _categoryOptions = const <Map<String, dynamic>>[];
  late final VoidCallback _favListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
                (e) => e.map((key, value) => MapEntry(key.toString(), value)),
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
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _favoritesRepository.removeListener(_favListener);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _availabilityResolver.invalidateCache();
      _availabilityCacheKey = '';
      if (_allServices.isNotEmpty) {
        _ensureChooserAvailability(_allServices, forceRefresh: true);
      }
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _availabilityResolver.invalidateCache();
      _availabilityCacheKey = '';
    }
    if (mounted && _services.isEmpty) {
      setState(() {
        _loading = true;
      });
    }
    final data = await _servicesRepository.getServices(
      forceRefresh: forceRefresh,
    );
    final fav = await isAuthenticated()
        ? await _favoritesRepository.getFavoriteIds()
        : <String>{};
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
    _ensureChooserAvailability(services, forceRefresh: forceRefresh);
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
      _ensureChooserAvailability(services);
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

  bool _isSameCategory(Map<String, dynamic>? a, Map<String, dynamic>? b) {
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
        onRefresh: () => _load(forceRefresh: true),
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
                  final canonicalId = _serviceIdFromMap(s);
                  final id = canonicalId.isNotEmpty
                      ? canonicalId
                      : serviceId(s, fallbackIndex: i);
                  final title = (s['name'] ?? s['title'] ?? 'Service')
                      .toString();
                  final description = (s['description'] ?? s['summary'] ?? '')
                      .toString()
                      .trim();
                  final category = serviceCategoryLabel(s);
                  final subtitle =
                      category ??
                      (description.isEmpty
                          ? 'Tap to book quickly'
                          : description);
                  final img = (s['image'] ?? s['image_url'] ?? '').toString();
                  final liked = _fav.contains(id);
                  final availability = _availabilityForService(s, id);
                  return GestureDetector(
                    onTap: () async {
                      if (availability == ServiceAvailability.unknown) {
                        AppSnack.show('Checking fixer availability...');
                      }
                      if (availability == ServiceAvailability.unavailable) {
                        AppSnack.show(
                          'No fixers available for this service right now.',
                          actionLabel: 'Browse',
                          onAction: () => AppSnack
                              .scaffoldMessengerKey
                              .currentState
                              ?.hideCurrentSnackBar(),
                        );
                        return;
                      }
                      await _openServiceWithAvailabilityGuard(s, id: id);
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
                                    _AvailabilityPill(
                                      availability: availability,
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        liked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: liked ? Colors.red : Colors.grey,
                                      ),
                                      onPressed: () async {
                                        final allowed = await ensureAuthenticated(
                                          context,
                                          title: 'Sign in to save favorites',
                                          message:
                                              'You can browse every service as a guest. Sign in to keep a personal favorites list.',
                                          actionLabel: 'Save favorites',
                                        );
                                        if (!allowed || !mounted) return;

                                        final previous = Set<String>.from(_fav);
                                        final optimistic = Set<String>.from(
                                          _fav,
                                        );
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
                                          setState(
                                            () =>
                                                _fav = _favoritesRepository.ids,
                                          );
                                        } catch (_) {
                                          if (!mounted) return;
                                          setState(() => _fav = previous);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Could not update favorites right now.',
                                              ),
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
      final key =
          '${subcategory['id'] ?? ''}-${(subcategory['name'] ?? '').toString().toLowerCase()}';
      if (seen.add(key)) {
        options.add(subcategory);
      }
    }
    return options;
  }

  String _safeJson(dynamic value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  String _serviceIdFromMap(Map<dynamic, dynamic> service) {
    final id = service['id'] ?? service['uuid'] ?? service['service_id'];
    if (id != null) {
      final normalized = id is num
          ? id.toInt().toString()
          : id.toString().trim();
      if (normalized.isNotEmpty) return normalized;
    }
    final slug =
        (service['slug'] ?? service['service_slug'] ?? service['serviceCode'])
            ?.toString()
            .trim()
            .toLowerCase();
    if (slug != null && slug.isNotEmpty) return 'slug:$slug';
    final name =
        (service['name'] ?? service['title'] ?? service['service_name'])
            ?.toString()
            .trim()
            .toLowerCase();
    if (name != null && name.isNotEmpty) return 'name:$name';
    return '';
  }

  String _availabilityKey(List<Map<String, dynamic>> services) {
    final ids =
        services
            .map(_serviceIdFromMap)
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ids.join(',');
  }

  void _ensureChooserAvailability(
    List<Map<String, dynamic>> services, {
    bool forceRefresh = false,
  }) {
    if (services.isEmpty) return;
    final key = _availabilityKey(services);
    final hasUnresolved = services.any((service) {
      final id = _serviceIdFromMap(service);
      if (id.isEmpty) return false;
      final state = _availabilityByServiceId[id] ?? FixerAvailability.unknown;
      return state == FixerAvailability.unknown ||
          state == FixerAvailability.checking;
    });
    if (!forceRefresh &&
        key == _availabilityCacheKey &&
        (_resolvingAvailability || !hasUnresolved)) {
      return;
    }
    _availabilityCacheKey = key;
    final snapshot = _availabilityResolver.stateForServices(services);
    if (mounted) {
      setState(() {
        _availabilityByServiceId = <String, FixerAvailability>{
          ..._availabilityByServiceId,
          ...snapshot,
        };
      });
    }
    unawaited(
      _resolveChooserAvailability(
        services,
        key: key,
        forceRefresh: forceRefresh,
      ),
    );
  }

  Future<void> _resolveChooserAvailability(
    List<Map<String, dynamic>> services, {
    required String key,
    bool forceRefresh = false,
  }) async {
    _resolvingAvailability = true;
    try {
      final availability = await _availabilityResolver.verifyServices(
        services,
        forceRefresh: forceRefresh,
        maxConcurrent: 4,
        source: 'services_list',
      );
      if (!mounted || key != _availabilityCacheKey) return;
      setState(() {
        final merged = <String, FixerAvailability>{..._availabilityByServiceId};
        availability.forEach((id, state) {
          final current = merged[id];
          if (!forceRefresh &&
              current == FixerAvailability.none &&
              state == FixerAvailability.available) {
            return;
          }
          merged[id] = state;
        });
        _availabilityByServiceId = merged;
      });

      assert(() {
        for (final service in services) {
          final id = _serviceIdFromMap(service);
          final name = (service['name'] ?? service['title'] ?? '')
              .toString()
              .toLowerCase();
          if (id == '87' || name.contains('ac installation')) {
            final result = availability[id] ?? FixerAvailability.unknown;
            debugPrint(
              'Services list availability service_id=$id result=$result raw=${_safeJson(service)}',
            );
          }
        }
        return true;
      }());
    } catch (error, stackTrace) {
      if (!mounted || key != _availabilityCacheKey) return;
      setState(() {
        final merged = <String, FixerAvailability>{..._availabilityByServiceId};
        for (final service in services) {
          final id = _serviceIdFromMap(service);
          if (id.isEmpty) continue;
          merged[id] = FixerAvailability.none;
        }
        _availabilityByServiceId = merged;
        _availabilityCacheKey = '';
      });
      assert(() {
        debugPrint(
          'Services list availability failed key=$key error=$error stack=$stackTrace',
        );
        return true;
      }());
    } finally {
      _resolvingAvailability = false;
    }
  }

  ServiceAvailability _availabilityForService(
    Map<dynamic, dynamic> service,
    String id,
  ) {
    final chooserAvailability = _availabilityByServiceId[id];
    ServiceAvailability resolved = ServiceAvailability.unknown;
    if (chooserAvailability == FixerAvailability.available) {
      resolved = ServiceAvailability.available;
    } else if (chooserAvailability == FixerAvailability.none) {
      resolved = ServiceAvailability.unavailable;
    }
    assert(() {
      final name = (service['name'] ?? service['title'] ?? '')
          .toString()
          .toLowerCase();
      if (id == '87' || name.contains('ac installation')) {
        debugPrint(
          'Services list rendered availability service_id=$id status=$resolved chooser_status=${chooserAvailability ?? FixerAvailability.unknown} raw=${_safeJson(service)}',
        );
      }
      return true;
    }());
    return resolved;
  }

  Future<void> _openServiceWithAvailabilityGuard(
    Map<String, dynamic> service, {
    required String id,
  }) async {
    if (_serviceIdFromMap(service).isEmpty) {
      await showServiceDetailsSheet(context, service: service);
      return;
    }
    final before = _availabilityByServiceId[id] ?? FixerAvailability.unknown;
    if (before == FixerAvailability.none) {
      AppSnack.show('No fixers available for this service right now.');
      return;
    }

    final eligibleCount = await _availabilityResolver.fetchEligibleFixerCount(
      service,
      forceRefresh: true,
      source: 'services_list_tap_guard',
    );
    if (!mounted) return;
    final after = eligibleCount > 0
        ? FixerAvailability.available
        : FixerAvailability.none;
    setState(() {
      _availabilityByServiceId = <String, FixerAvailability>{
        ..._availabilityByServiceId,
        id: after,
      };
    });

    assert(() {
      final name = (service['name'] ?? service['title'] ?? '')
          .toString()
          .toLowerCase();
      if (id == '87' || name.contains('ac installation')) {
        debugPrint(
          'Services list tap guard service_id=$id before=$before after=$after eligible_fixers=$eligibleCount raw=${_safeJson(service)}',
        );
      }
      return true;
    }());

    if (eligibleCount <= 0) {
      AppSnack.show('No fixers available for this service right now.');
      return;
    }
    await showServiceDetailsSheet(context, service: service);
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
                          ? const Icon(
                              Icons.check_rounded,
                              color: Color(0xFFF1592A),
                            )
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
                    final label = (cat['name'] ?? cat['title'] ?? 'Category')
                        .toString();
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
        label = 'Checking...';
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
