import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/state/dashboard_controller.dart';
import 'package:fixitzed_app/state/profile_controller.dart';
import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/repositories/services_repository.dart';
import 'package:fixitzed_app/utils/service_utils.dart';
import 'package:fixitzed_app/utils/app_snack.dart';
import 'package:fixitzed_app/screens/dashboard_widgets.dart';
import 'package:fixitzed_app/screens/favorites_screen.dart';
import 'package:fixitzed_app/screens/payment_sheet.dart';
import 'package:fixitzed_app/screens/profile/my_booking_screen.dart';
import 'package:fixitzed_app/screens/profile_screen.dart';
import 'package:fixitzed_app/services/chooser_availability_service.dart';
import 'package:fixitzed_app/services/auth_service.dart';
import 'package:fixitzed_app/widgets/skeletons.dart';
import 'package:fixitzed_app/widgets/auth_required.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  WidgetRef? _ref;
  bool _billPromptShown = false;
  bool _checkingBills = false;
  int _tabIndex = 0;
  bool _dashboardListenerAttached = false;
  ServicesRepository? _servicesRepo;
  final FixerAvailabilityResolver _availabilityResolver =
      FixerAvailabilityResolver();
  Map<String, FixerAvailability> _quickPickAvailability =
      const <String, FixerAvailability>{};
  String _quickPickAvailabilityKey = '';
  bool _resolvingQuickPickAvailability = false;
  bool _quickPickAvailabilityFrameScheduled = false;
  List<dynamic>? _pendingQuickPickServices;
  bool _pendingQuickPickForceRefresh = false;

  int? _parseId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopServiceSync();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _availabilityResolver.invalidateCache();
      _quickPickAvailabilityKey = '';
      if (mounted) {
        setState(() {
          _quickPickAvailability = const <String, FixerAvailability>{};
        });
      }
      final r = _ref;
      if (r != null) {
        r.read(servicesControllerProvider).startForegroundSync();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopServiceSync();
    }
  }

  void _showUnavailableSnackBar() {
    AppSnack.show(
      'No fixers available for this service right now.',
      actionLabel: 'Browse',
      onAction: () =>
          AppSnack.scaffoldMessengerKey.currentState?.hideCurrentSnackBar(),
    );
  }

  void _ensureServicesRepo(WidgetRef ref) {
    if (_servicesRepo != null) return;
    _servicesRepo = ref.read(servicesRepositoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(servicesControllerProvider).startForegroundSync();
    });
  }

  void _stopServiceSync() {
    final r = _ref;
    if (r != null) {
      r.read(servicesControllerProvider).stopSync();
    }
  }

  String _safeJson(dynamic value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  String _serviceId(Map<dynamic, dynamic> service) {
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
        services.map(_serviceId).where((id) => id.isNotEmpty).toSet().toList()
          ..sort();
    return ids.join(',');
  }

  void _ensureQuickPickAvailability(
    List<dynamic> services, {
    bool forceRefresh = false,
  }) {
    final normalized = services
        .whereType<Map>()
        .map(_normalizeMap)
        .where((service) => service.isNotEmpty)
        .toList();
    if (normalized.isEmpty) return;
    final key = _availabilityKey(normalized);
    final hasUnresolved = normalized.any((service) {
      final id = _serviceId(service);
      if (id.isEmpty) return false;
      final state = _quickPickAvailability[id] ?? FixerAvailability.unknown;
      return state == FixerAvailability.unknown ||
          state == FixerAvailability.checking;
    });
    if (!forceRefresh &&
        key == _quickPickAvailabilityKey &&
        (_resolvingQuickPickAvailability || !hasUnresolved)) {
      return;
    }
    _quickPickAvailabilityKey = key;
    final snapshot = _availabilityResolver.stateForServices(normalized);
    if (mounted) {
      setState(() {
        _quickPickAvailability = <String, FixerAvailability>{
          ..._quickPickAvailability,
          ...snapshot,
        };
      });
    }
    unawaited(
      _resolveQuickPickAvailability(
        normalized,
        key: key,
        forceRefresh: forceRefresh,
      ),
    );
  }

  void _scheduleQuickPickAvailability(
    List<dynamic> services, {
    bool forceRefresh = false,
  }) {
    _pendingQuickPickServices = services;
    _pendingQuickPickForceRefresh =
        _pendingQuickPickForceRefresh || forceRefresh;
    if (_quickPickAvailabilityFrameScheduled) return;
    _quickPickAvailabilityFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _quickPickAvailabilityFrameScheduled = false;
      if (!mounted) return;
      final pending = _pendingQuickPickServices;
      final pendingForceRefresh = _pendingQuickPickForceRefresh;
      _pendingQuickPickServices = null;
      _pendingQuickPickForceRefresh = false;
      if (pending == null || pending.isEmpty) return;
      _ensureQuickPickAvailability(pending, forceRefresh: pendingForceRefresh);
    });
  }

  Future<void> _resolveQuickPickAvailability(
    List<Map<String, dynamic>> services, {
    required String key,
    bool forceRefresh = false,
  }) async {
    _resolvingQuickPickAvailability = true;
    try {
      final availability = await _availabilityResolver.verifyServices(
        services,
        forceRefresh: forceRefresh,
        maxConcurrent: 4,
        source: 'dashboard_quick_picks',
      );
      if (!mounted || key != _quickPickAvailabilityKey) return;
      setState(() {
        final merged = <String, FixerAvailability>{..._quickPickAvailability};
        availability.forEach((id, state) {
          final current = merged[id];
          if (!forceRefresh &&
              current == FixerAvailability.none &&
              state == FixerAvailability.available) {
            return;
          }
          merged[id] = state;
        });
        _quickPickAvailability = merged;
      });

      assert(() {
        for (final service in services) {
          final id = _serviceId(service);
          final name = (service['name'] ?? service['title'] ?? '')
              .toString()
              .toLowerCase();
          if (id == '87' || name.contains('ac installation')) {
            final result = availability[id] ?? FixerAvailability.unknown;
            debugPrint(
              'Dashboard quick-picks availability service_id=$id result=$result raw=${_safeJson(service)}',
            );
          }
        }
        return true;
      }());
    } catch (error, stackTrace) {
      if (!mounted || key != _quickPickAvailabilityKey) return;
      setState(() {
        final merged = <String, FixerAvailability>{..._quickPickAvailability};
        for (final service in services) {
          final id = _serviceId(service);
          if (id.isEmpty) continue;
          merged[id] = FixerAvailability.none;
        }
        _quickPickAvailability = merged;
        _quickPickAvailabilityKey = '';
      });
      assert(() {
        debugPrint(
          'Dashboard quick-picks availability failed key=$key error=$error stack=$stackTrace',
        );
        return true;
      }());
    } finally {
      _resolvingQuickPickAvailability = false;
    }
  }

  Future<void> _openServiceWithAvailabilityGuard(
    Map<String, dynamic> service,
  ) async {
    final id = _serviceId(service);
    if (id.isEmpty) {
      await showServiceDetailsSheet(context, service: service);
      return;
    }
    final before = _quickPickAvailability[id] ?? FixerAvailability.unknown;
    if (before == FixerAvailability.none) {
      _showUnavailableSnackBar();
      return;
    }

    final verifiedCount = await _availabilityResolver.fetchEligibleFixerCount(
      service,
      forceRefresh: true,
      source: 'dashboard_tap_guard',
    );
    if (!mounted) return;
    final after = verifiedCount > 0
        ? FixerAvailability.available
        : FixerAvailability.none;
    setState(() {
      _quickPickAvailability = <String, FixerAvailability>{
        ..._quickPickAvailability,
        id: after,
      };
    });

    assert(() {
      final name = (service['name'] ?? service['title'] ?? '')
          .toString()
          .toLowerCase();
      if (id == '87' || name.contains('ac installation')) {
        debugPrint(
          'Dashboard tap guard service_id=$id before=$before after=$after eligible_fixers=$verifiedCount raw=${_safeJson(service)}',
        );
      }
      return true;
    }());

    if (verifiedCount <= 0) {
      _showUnavailableSnackBar();
      return;
    }
    await showServiceDetailsSheet(context, service: service);
  }

  Widget _greeting(
    DashboardState state, {
    ProfileState? profile,
  }) => DashboardGreeting(
    name: (profile?.name ?? '').trim().isNotEmpty ? profile!.name : state.name,
    location: (profile?.location ?? '').trim().isNotEmpty
        ? profile!.location
        : state.location,
    avatarUrl: (profile?.avatarUrl ?? '').trim().isNotEmpty
        ? profile!.avatarUrl
        : state.avatarUrl,
    hasUnread: state.hasUnread,
    onNotificationsTap: () async {
      final allowed = await ensureAuthenticated(
        context,
        title: 'Sign in to view notifications',
        message:
            'Notifications are tied to your bookings, payments and account activity.',
        actionLabel: 'View notifications',
      );
      if (!allowed || !mounted) return;
      await Navigator.of(context).pushNamed('/notifications');
      if (!mounted) return;
      final ref = _ref;
      if (ref == null) return;
      await ref.read(dashboardControllerProvider.notifier).refresh();
    },
  );

  Widget _searchField(List<dynamic> categories) {
    final normalizedCategories = categories
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (cat) => cat.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();

    return DashboardSearchField(
      categories: normalizedCategories,
      onSubmitted: (term) {
        final query = term.trim();
        if (query.isEmpty) return;
        Navigator.pushNamed(
          context,
          '/services',
          arguments: {'query': query, 'categories': normalizedCategories},
        );
      },
      onFilterSelected: (category) {
        if (category == null) {
          Navigator.pushNamed(
            context,
            '/services',
            arguments: {'categories': normalizedCategories},
          );
        } else {
          Navigator.pushNamed(
            context,
            '/services',
            arguments: {
              'category': category,
              'categories': normalizedCategories,
            },
          );
        }
      },
    );
  }

  Future<void> _openBookingSheet({Map<String, dynamic>? service}) async {
    await showBookingSheet(context, service: service);
  }

  Widget _bookingHero() {
    final colors = Theme.of(context).fx;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: colors.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.brand.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need something fixed?',
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Book a trusted fixer in seconds and track every job from this screen.',
            style: GoogleFonts.urbanist(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openBookingSheet,
                  icon: const Icon(Icons.flash_on_rounded),
                  label: const Text('Request a service'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: colors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/profile/bookings'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Track requests'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _refreshDashboard() async {
    _availabilityResolver.invalidateCache();
    if (mounted) {
      setState(() {
        _quickPickAvailability = const <String, FixerAvailability>{};
        _quickPickAvailabilityKey = '';
      });
    }
    final ref = _ref;
    if (ref == null) return;
    await ref.read(dashboardControllerProvider.notifier).refresh();
  }

  Widget _quickCategories(
    List<dynamic> categories, {
    required Future<void> Function() onRetry,
    required bool isLoading,
    required bool hasResolved,
  }) {
    final colors = Theme.of(context).fx;
    if (isLoading || (!hasResolved && categories.isEmpty)) {
      return const PopularSubcategoriesSkeleton();
    }
    if (categories.isEmpty) {
      if (kDebugMode) {
        debugPrint('Dashboard: categories response empty, showing empty state');
      }
      return _EmptyState(
        message: 'No categories available right now',
        detail: 'We\'ll refresh in a moment.',
        onRetry: onRetry,
        compact: true,
      );
    }
    final normalizedCategories = categories
        .whereType<Map>()
        .map((cat) => cat.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
    final items = normalizedCategories.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Popular subcategories',
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/services'),
              child: Text(
                'View All',
                style: GoogleFonts.urbanist(
                  color: colors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final rawCat = items[i];
              var category = <String, dynamic>{};
              category = Map<String, dynamic>.from(rawCat);
              if (category.isEmpty) {
                category = {'name': rawCat.toString()};
              }
              final name =
                  (category['name'] ?? category['title'] ?? 'Subcategory')
                      .toString();
              return GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/services',
                  arguments: {
                    'category': category,
                    'categories': normalizedCategories,
                  },
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    name,
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w600,
                      color: colors.brand,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _serviceSpotlight(
    List<dynamic> services, {
    required Future<void> Function() onRetry,
  }) {
    final colors = Theme.of(context).fx;
    final cached = _servicesRepo?.getCachedServices() ?? const <dynamic>[];
    final source = cached.isNotEmpty ? cached : services;
    _scheduleQuickPickAvailability(source);
    if (source.isEmpty) {
      if (kDebugMode) {
        debugPrint('Dashboard: services response empty, showing empty state');
      }
      return _EmptyState(
        message: 'No services available right now',
        detail: 'Try again in a bit or refresh now.',
        onRetry: onRetry,
        compact: true,
      );
    }
    final items = source.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Quick picks for you',
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/services'),
              child: Text(
                'View All',
                style: GoogleFonts.urbanist(
                  color: colors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((service) {
          final map = _normalizeMap(service);
          final name = (map['name'] ?? map['title'] ?? 'Service').toString();
          final desc = (map['description'] ?? map['summary'] ?? '')
              .toString()
              .trim();
          final category = serviceCategoryLabel(map);
          final subtitle =
              category ?? (desc.isEmpty ? 'Tap to book quickly' : desc);
          final image = Api.resolveImageUrl(map['image'] ?? map['icon']);
          final id = _serviceId(map);
          final availability =
              _quickPickAvailability[id] ?? FixerAvailability.unknown;
          return GestureDetector(
            onTap: () async {
              if (map.isEmpty) {
                await _openBookingSheet();
                return;
              }
              if (availability == FixerAvailability.checking) {
                AppSnack.show('Checking fixer availability...');
              }
              await _openServiceWithAvailabilityGuard(map);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  if (Theme.of(context).brightness == Brightness.light)
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.surfaceTint,
                      borderRadius: BorderRadius.circular(16),
                      image: image.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(image),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: image.isEmpty
                        ? Icon(Icons.build_rounded, color: colors.brand)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.urbanist(
                            color: colors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AvailabilityPill(availability: availability),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  Widget _bottomNav() => DashboardBottomNav(
    currentIndex: _tabIndex,
    onTap: (i) async {
      if (i == 0) {
        setState(() => _tabIndex = i);
        return;
      }

      final allowed = await ensureAuthenticated(
        context,
        title: _authTitleForTab(i),
        message: _authMessageForTab(i),
        actionLabel: _authActionForTab(i),
      );
      if (!allowed || !mounted) return;
      setState(() => _tabIndex = i);
    },
    onBookTap: () async {
      await _openBookingSheet();
    },
  );

  String _authTitleForTab(int index) {
    return switch (index) {
      1 => 'Sign in to view bookings',
      2 => 'Sign in to save favorites',
      3 => 'Sign in to manage your account',
      _ => 'Sign in required',
    };
  }

  String _authMessageForTab(int index) {
    return switch (index) {
      1 => 'Your booking history is private and available after sign in.',
      2 => 'Create an account to save services and find them later.',
      3 =>
        'Profile, settings and account deletion are available after sign in.',
      _ => 'Sign in or create an account to continue.',
    };
  }

  String _authActionForTab(int index) {
    return switch (index) {
      1 => 'View bookings',
      2 => 'Save favorites',
      3 => 'Manage account',
      _ => 'Continue',
    };
  }

  Future<void> _checkPendingBills(WidgetRef ref) async {
    if (_billPromptShown || _checkingBills || !mounted) return;
    if (!(await isAuthenticated())) return;
    _checkingBills = true;
    try {
      final requestService = ref.read(serviceRequestServiceProvider);
      final paymentService = ref.read(paymentServiceProvider);
      final list = await requestService.listRequests();
      for (final r in list) {
        final id = _parseId(r['id']);
        final status = (r['status'] ?? '').toString();
        if (id == null || status == 'completed') continue;
        final payment = await paymentService.get(id);
        if (payment == null) continue;
        final paid =
            ((payment['status'] ?? '').toString().toLowerCase() == 'paid');
        final amount = payment['amount'];
        if (!paid && amount != null) {
          final parsedAmount = (amount is num)
              ? amount.toDouble()
              : double.tryParse(amount.toString()) ?? 0;
          if (!mounted) return;
          _billPromptShown = true;
          await _showPayNowSheet(ref, r, parsedAmount);
          break;
        }
      }
    } catch (_) {
      // Ignore errors; dashboard content remains usable.
    } finally {
      _checkingBills = false;
    }
  }

  Future<void> _showPayNowSheet(
    WidgetRef ref,
    Map<String, dynamic> request,
    double amount,
  ) async {
    final id = _parseId(request['id']);
    if (id == null) return;
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(requestId: id),
        fullscreenDialog: true,
      ),
    );
    if (paid == true && mounted) {
      _billPromptShown = false;
      await ref.read(dashboardControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        _ref = ref;
        if (!_dashboardListenerAttached) {
          _dashboardListenerAttached = true;
          ref.listen<AsyncValue<DashboardState>>(dashboardControllerProvider, (
            previous,
            next,
          ) {
            next.whenOrNull(
              data: (_) {
                if (!mounted) return;
                _checkPendingBills(ref);
              },
            );
          });
        }

        final dashboardAsync = ref.watch(dashboardControllerProvider);
        final state = dashboardAsync.value ?? const DashboardState();
        final isInitialLoading =
            dashboardAsync.isLoading && dashboardAsync.value == null;
        final errorText =
            state.error ??
            dashboardAsync.whenOrNull(error: (err, _) => err.toString());
        final profileState = ref.watch(profileControllerProvider).value;

        if (state.isInactive) {
          return _InactiveAccountView(
            onContactSupport: () =>
                Navigator.pushNamed(context, '/profile/help'),
            onLogout: () async {
              await AuthService().logout();
              if (!mounted) return;
              await Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/home', (route) => false);
            },
          );
        }

        _ensureServicesRepo(ref);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value:
              (Theme.of(context).brightness == Brightness.dark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark)
                  .copyWith(statusBarColor: Colors.transparent),
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            bottomNavigationBar: _bottomNav(),
            body: SafeArea(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _buildHomeTab(
                    state: state,
                    profile: profileState,
                    isInitialLoading: isInitialLoading,
                    errorText: errorText,
                    onRetry: _refreshDashboard,
                  ),
                  const MyBookingScreen(),
                  const FavoritesScreen(),
                  const ProfileScreen(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeTab({
    required DashboardState state,
    required ProfileState? profile,
    required bool isInitialLoading,
    required String? errorText,
    required Future<void> Function() onRetry,
  }) {
    if (isInitialLoading) {
      return const DashboardSkeleton();
    }
    if (errorText != null) {
      return _ErrorState(
        message: 'We couldn\'t load the dashboard right now.',
        detail: errorText,
        onRetry: onRetry,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _greeting(state, profile: profile),
          const SizedBox(height: 16),
          _bookingHero(),
          const SizedBox(height: 20),
          _searchField(state.categories),
          const SizedBox(height: 20),
          _quickCategories(
            state.categories,
            onRetry: onRetry,
            isLoading: state.areCategoriesLoading,
            hasResolved: state.hasResolvedCategories,
          ),
          const SizedBox(height: 24),
          _serviceSpotlight(state.services, onRetry: onRetry),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String? detail;
  final Future<void> Function() onRetry;
  final bool compact;

  const _ErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).fx;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wifi_off_rounded, size: 48, color: colors.textMuted),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        if (detail != null && detail!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            detail!,
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(color: colors.textSecondary),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => onRetry(),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.brand,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    );

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceTint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.brand.withValues(alpha: 0.12)),
        ),
        child: content,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: content,
      ),
    );
  }
}

class _EmptyState extends _ErrorState {
  const _EmptyState({
    required super.message,
    super.detail,
    required super.onRetry,
    super.compact = true,
  });
}

class _InactiveAccountView extends StatelessWidget {
  final VoidCallback onContactSupport;
  final VoidCallback onLogout;
  const _InactiveAccountView({
    required this.onContactSupport,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).fx;
    final accent = colors.brand;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: accent,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Account inactive',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your account is currently inactive. Please contact support or try again later.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onContactSupport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Contact Support'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Log out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  final FixerAvailability availability;
  const _AvailabilityPill({required this.availability});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).fx;
    late final Color bg;
    late final Color text;
    late final String label;
    late final IconData icon;
    switch (availability) {
      case FixerAvailability.available:
        bg = colors.successContainer;
        text = colors.success;
        label = 'Available';
        icon = Icons.check_circle_rounded;
        break;
      case FixerAvailability.none:
        bg = colors.warningContainer;
        text = colors.warning;
        label = 'No fixers';
        icon = Icons.warning_amber_rounded;
        break;
      case FixerAvailability.checking:
        bg = colors.surfaceSubtle;
        text = colors.textMuted;
        label = 'Checking...';
        icon = Icons.more_horiz_rounded;
        break;
      case FixerAvailability.unknown:
        bg = colors.surfaceSubtle;
        text = colors.textMuted;
        label = 'Checking...';
        icon = Icons.more_horiz_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
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
