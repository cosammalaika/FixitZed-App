import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/repositories/favorites_repository.dart';
import 'package:fixitzed_app/screens/widgets/service_list_tile.dart';
import 'package:fixitzed_app/services/chooser_availability_service.dart';
import 'package:fixitzed_app/state/home_catalog_controller.dart';
import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/utils/app_snack.dart';
import 'package:fixitzed_app/utils/home_flow_log.dart';
import 'package:fixitzed_app/utils/service_utils.dart';
import 'package:fixitzed_app/widgets/auth_required.dart';
import 'package:fixitzed_app/widgets/skeletons.dart';

class ServicesListScreen extends ConsumerStatefulWidget {
  const ServicesListScreen({super.key});

  @override
  ConsumerState<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends ConsumerState<ServicesListScreen>
    with WidgetsBindingObserver {
  late final FavoritesRepository _favoritesRepository;
  late final FixerAvailabilityResolver _availabilityResolver;
  late final TextEditingController _searchCtrl;
  late final VoidCallback _favListener;

  Set<String> _fav = <String>{};
  Map<String, FixerAvailability> _availabilityByServiceId =
      const <String, FixerAvailability>{};
  String _availabilityCacheKey = '';
  bool _resolvingAvailability = false;
  bool _availabilityFrameScheduled = false;
  List<Map<String, dynamic>>? _pendingAvailabilityServices;
  bool _pendingAvailabilityForceRefresh = false;
  Map<String, dynamic>? _category;
  String? _categoryName;
  String _searchTerm = '';
  bool _initialized = false;
  List<Map<String, dynamic>> _categoryOptionsFromArgs =
      const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _favoritesRepository = ref.read(favoritesRepositoryProvider);
    _availabilityResolver = ref.read(fixerAvailabilityResolverProvider);
    _searchCtrl = TextEditingController();
    _fav = _favoritesRepository.ids;
    _favListener = () {
      if (!mounted) return;
      setState(() => _fav = _favoritesRepository.ids);
    };
    _favoritesRepository.addListener(_favListener);
    HomeFlowLog.log('services_screen', 'screen_entry');
    unawaited(_syncFavorites());
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
        }

        final query = args['query'];
        if (query is String && query.trim().isNotEmpty) {
          _searchTerm = query.trim();
          _searchCtrl.text = _searchTerm;
        }

        final categories = args['categories'];
        if (categories is List) {
          _categoryOptionsFromArgs = categories
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
    unawaited(
      ref.read(homeCatalogControllerProvider.notifier).ensureLoaded(
        reason: 'services_screen_open',
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _favoritesRepository.removeListener(_favListener);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    unawaited(
      ref.read(homeCatalogControllerProvider.notifier).handleAppResumed(),
    );
    final services = _normalizedServices(
      ref.read(homeCatalogControllerProvider).services.items,
    );
    if (services.isNotEmpty) {
      _ensureChooserAvailability(services);
    }
  }

  Future<void> _syncFavorites() async {
    if (!await isAuthenticated()) return;
    final fav = await _favoritesRepository.getFavoriteIds();
    if (!mounted) return;
    setState(() => _fav = fav);
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

  List<Map<String, dynamic>> _normalizedServices(List<dynamic> rawServices) {
    final services = rawServices
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

    return services;
  }

  List<Map<String, dynamic>> _filteredServices(
    List<Map<String, dynamic>> services,
  ) {
    var filtered = List<Map<String, dynamic>>.from(services);

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

    return filtered;
  }

  List<Map<String, dynamic>> _resolvedCategoryOptions(
    HomeCatalogState catalog,
    List<Map<String, dynamic>> services,
  ) {
    if (_categoryOptionsFromArgs.isNotEmpty) {
      return List<Map<String, dynamic>>.from(_categoryOptionsFromArgs);
    }

    final catalogOptions = catalog.categories.items
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (e) => e.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
    if (catalogOptions.isNotEmpty) {
      return catalogOptions;
    }

    return deriveSubcategoryOptions(services);
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
    final needsRefresh =
        forceRefresh || services.any(_availabilityResolver.needsRefreshForService);
    if (!forceRefresh &&
        key == _availabilityCacheKey &&
        (_resolvingAvailability || !needsRefresh)) {
      return;
    }

    _availabilityCacheKey = key;
    final snapshot = _availabilityResolver.stateForServices(
      services,
      allowStale: true,
    );
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

  void _scheduleChooserAvailability(
    List<Map<String, dynamic>> services, {
    bool forceRefresh = false,
  }) {
    _pendingAvailabilityServices = services;
    _pendingAvailabilityForceRefresh =
        _pendingAvailabilityForceRefresh || forceRefresh;
    if (_availabilityFrameScheduled) return;
    _availabilityFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _availabilityFrameScheduled = false;
      if (!mounted) return;
      final pending = _pendingAvailabilityServices;
      final pendingForceRefresh = _pendingAvailabilityForceRefresh;
      _pendingAvailabilityServices = null;
      _pendingAvailabilityForceRefresh = false;
      if (pending == null || pending.isEmpty) return;
      _ensureChooserAvailability(pending, forceRefresh: pendingForceRefresh);
    });
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
        _availabilityByServiceId = <String, FixerAvailability>{
          ..._availabilityByServiceId,
          ...availability,
        };
      });
    } finally {
      _resolvingAvailability = false;
    }
  }

  ServiceAvailability _availabilityForService(
    Map<dynamic, dynamic> service,
    String id,
  ) {
    final validatedCount = _availabilityResolver.eligibleFixerCountForService(
      Map<String, dynamic>.from(service),
      allowStale: true,
    );
    if (validatedCount != null) {
      return validatedCount > 0
          ? ServiceAvailability.available
          : ServiceAvailability.unavailable;
    }

    final chooserAvailability =
        _availabilityByServiceId[id] ??
        _availabilityResolver.stateForService(service, allowStale: true);
    if (chooserAvailability == FixerAvailability.available) {
      return ServiceAvailability.available;
    }
    if (chooserAvailability == FixerAvailability.none) {
      return ServiceAvailability.unavailable;
    }
    return ServiceAvailability.unknown;
  }

  int? _availabilityCountForService(Map<String, dynamic> service) {
    return _availabilityResolver.eligibleFixerCountForService(
      service,
      allowStale: true,
    );
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
    final needsRefresh = _availabilityResolver.needsRefreshForService(service);
    if (before == FixerAvailability.none && !needsRefresh) {
      AppSnack.show('No fixers available for this service right now.');
      return;
    }

    final eligibleCount = await _availabilityResolver.fetchEligibleFixerCount(
      service,
      forceRefresh: needsRefresh,
      source: 'services_list_tap_guard',
    );
    if (!mounted) return;

    final after = eligibleCount == null
        ? FixerAvailability.unknown
        : eligibleCount > 0
        ? FixerAvailability.available
        : FixerAvailability.none;
    setState(() {
      _availabilityByServiceId = <String, FixerAvailability>{
        ..._availabilityByServiceId,
        id: after,
      };
    });

    if (eligibleCount != null && eligibleCount <= 0) {
      AppSnack.show('No fixers available for this service right now.');
      return;
    }

    await showServiceDetailsSheet(context, service: service);
  }

  Future<void> _manualRefresh() async {
    HomeFlowLog.log('services_screen', 'manual_refresh');
    await ref.read(homeCatalogControllerProvider.notifier).refresh(
      reason: 'services_list_pull_to_refresh',
    );
    final refreshedServices = _normalizedServices(
      ref.read(homeCatalogControllerProvider).services.items,
    );
    if (refreshedServices.isNotEmpty) {
      _ensureChooserAvailability(refreshedServices, forceRefresh: true);
    }
  }

  Future<void> _openFilterSheet(List<Map<String, dynamic>> options) async {
    final selection = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      backgroundColor: Theme.of(context).fx.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colors = Theme.of(ctx).fx;
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
                      color: colors.border,
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
                          ? Icon(Icons.check_rounded, color: colors.brand)
                          : null,
                      selected: allSelected,
                      selectedTileColor: colors.surfaceTint,
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
                      style: GoogleFonts.urbanist(color: colors.textSecondary),
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
                        selectedTileColor: colors.surfaceTint,
                        trailing: selected
                            ? Icon(Icons.check_rounded, color: colors.brand)
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
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(homeCatalogControllerProvider);
    final services = _normalizedServices(catalog.services.items);
    final filteredServices = _filteredServices(services);
    final categoryOptions = _resolvedCategoryOptions(catalog, services);

    if (services.isNotEmpty) {
      _scheduleChooserAvailability(services);
    }

    final showInitialLoading =
        catalog.services.isInitialLoading && services.isEmpty;
    final showOffline = services.isEmpty && catalog.services.isOfflineState;
    final showFailure = services.isEmpty && catalog.services.isFailureState;
    final showBackendEmpty =
        services.isEmpty &&
        !showInitialLoading &&
        !showOffline &&
        !showFailure;

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
                      setState(() => _searchTerm = value.trim());
                    },
                    decoration: InputDecoration(
                      hintText: 'Search services',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchTerm.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchCtrl.clear();
                                FocusScope.of(context).unfocus();
                                setState(() => _searchTerm = '');
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
                _FilterButton(onTap: () => _openFilterSheet(categoryOptions)),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        child: showInitialLoading
            ? const ServicesListSkeleton()
            : showOffline
            ? const _OfflineServicesState()
            : showFailure
            ? _FailureServicesState(
                detail: catalog.services.error?.userMessage,
                onRetry: _manualRefresh,
              )
            : showBackendEmpty
            ? _EmptyServicesState(searchQuery: '', categoryLabel: _categoryName)
            : filteredServices.isEmpty
            ? _EmptyServicesState(
                searchQuery: _searchTerm,
                categoryLabel: _categoryName,
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filteredServices.length,
                itemBuilder: (ctx, i) {
                  final service = filteredServices[i];
                  final canonicalId = _serviceIdFromMap(service);
                  final id = canonicalId.isNotEmpty
                      ? canonicalId
                      : serviceId(service, fallbackIndex: i);
                  final title = (service['name'] ?? service['title'] ?? 'Service')
                      .toString();
                  final description =
                      (service['description'] ?? service['summary'] ?? '')
                          .toString()
                          .trim();
                  final category = serviceCategoryLabel(service);
                  final subtitle =
                      category ??
                      (description.isEmpty
                          ? 'Tap to book quickly'
                          : description);
                  final img =
                      (service['image'] ?? service['image_url'] ?? '').toString();
                  final liked = _fav.contains(id);
                  final availability = _availabilityForService(service, id);
                  final availabilityCount =
                      _availabilityCountForService(service);
                  final colors = Theme.of(context).fx;

                  return GestureDetector(
                    onTap: () => _openServiceWithAvailabilityGuard(
                      service,
                      id: id,
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surfaceSubtle,
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
                                      color: colors.surfaceRaised,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.handyman_rounded,
                                      color: colors.textMuted,
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
                                                  color: colors.textSecondary,
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
                                      fixerCount: availabilityCount,
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        liked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: liked
                                            ? colors.danger
                                            : colors.textMuted,
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
                                        final optimistic = Set<String>.from(_fav);
                                        if (optimistic.contains(id)) {
                                          optimistic.remove(id);
                                        } else {
                                          optimistic.add(id);
                                        }
                                        setState(() => _fav = optimistic);

                                        try {
                                          await _favoritesRepository.toggle(id);
                                          if (!mounted) return;
                                          setState(
                                            () => _fav = _favoritesRepository.ids,
                                          );
                                        } catch (_) {
                                          if (!mounted) return;
                                          setState(() => _fav = previous);
                                          ScaffoldMessenger.of(context).showSnackBar(
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
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({
    required this.availability,
    this.fixerCount,
  });

  final ServiceAvailability availability;
  final int? fixerCount;

  @override
  Widget build(BuildContext context) {
    if (availability == ServiceAvailability.unknown) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).fx;
    late final Color bg;
    late final Color text;
    late final String label;
    late final IconData icon;

    switch (availability) {
      case ServiceAvailability.available:
        bg = colors.successContainer;
        text = colors.success;
        label = 'Available';
        icon = Icons.check_circle_rounded;
        break;
      case ServiceAvailability.unavailable:
        bg = colors.warningContainer;
        text = colors.warning;
        label = 'No fixers';
        icon = Icons.warning_amber_rounded;
        break;
      case ServiceAvailability.unknown:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onTap});

  final VoidCallback onTap;

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

class _OfflineServicesState extends StatelessWidget {
  const _OfflineServicesState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 160),
        Center(
          child: Column(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 56,
                color: Color(0xFFC6CBD1),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'You are offline. Services will refresh automatically once your connection is back.',
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

class _FailureServicesState extends StatelessWidget {
  const _FailureServicesState({
    required this.detail,
    required this.onRetry,
  });

  final String? detail;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 140),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: Color(0xFFC6CBD1),
                ),
                const SizedBox(height: 18),
                Text(
                  'We could not load services right now.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (detail != null && detail!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    detail!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(
                      color: Theme.of(context).fx.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => onRetry(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyServicesState extends StatelessWidget {
  const _EmptyServicesState({
    required this.searchQuery,
    required this.categoryLabel,
  });

  final String searchQuery;
  final String? categoryLabel;

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
