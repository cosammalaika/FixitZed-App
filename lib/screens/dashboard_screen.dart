import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/state/dashboard_controller.dart';
import 'package:fixitzed_app/state/fixers_providers.dart';
import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/repositories/services_repository.dart';
import 'package:fixitzed_app/utils/service_utils.dart';
import 'package:fixitzed_app/utils/app_snack.dart';
import 'package:fixitzed_app/screens/dashboard_widgets.dart';
import 'package:fixitzed_app/screens/favorites_screen.dart';
import 'package:fixitzed_app/screens/payment_sheet.dart';
import 'package:fixitzed_app/screens/profile/my_booking_screen.dart';
import 'package:fixitzed_app/screens/profile_screen.dart';
import 'package:fixitzed_app/widgets/skeletons.dart';

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

  int? _readyCount(Map<dynamic, dynamic> service) {
    final val =
        service['opted_in_fixers_count'] ??
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
    final raw =
        service['has_fixers'] ??
        service['hasFixers'] ??
        service['has_ready_fixers'] ??
        service['hasReadyFixers'] ??
        service['has_opted_in_fixers'] ??
        service['hasOptedInFixers'];
    if (raw is bool) return raw;
    if (raw is num) return raw > 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  bool _hasFixers(Map<dynamic, dynamic> service) {
    final readyCount = _readyCount(service);
    return readyCount != null
        ? readyCount > 0
        : (_hasReadyFlag(service) ?? false);
  }

  void _showUnavailableSnackBar() {
    AppSnack.show(
      'No fixer opted in yet',
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

  Widget _greeting(DashboardState state) => DashboardGreeting(
    name: state.name,
    location: state.location,
    avatarUrl: state.avatarUrl,
    hasUnread: state.hasUnread,
    onNotificationsTap: () async {
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1592A), Color(0xFFFFA26C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF1592A).withValues(alpha: 0.18),
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
                    foregroundColor: const Color(0xFFF1592A),
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
    final ref = _ref;
    if (ref == null) return;
    await ref.read(dashboardControllerProvider.notifier).refresh();
  }

  Widget _quickCategories(
    List<dynamic> categories, {
    required Future<void> Function() onRetry,
  }) {
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
                  color: const Color(0xFFF1592A),
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
                    color: const Color(0x1AF1592A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    name,
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF1592A),
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
    final cached = _servicesRepo?.getCachedServices() ?? const <dynamic>[];
    final source = cached.isNotEmpty ? cached : services;
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
                  color: const Color(0xFFF1592A),
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
          final hasFixers = _hasFixers(map);
          return GestureDetector(
            onTap: () {
              if (!hasFixers) {
                _showUnavailableSnackBar();
                return;
              }
              _openBookingSheet(service: map.isEmpty ? null : map);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
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
                      color: const Color(0x1AF1592A),
                      borderRadius: BorderRadius.circular(16),
                      image: image.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(image),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: image.isEmpty
                        ? const Icon(
                            Icons.build_rounded,
                            color: Color(0xFFF1592A),
                          )
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
                          style: GoogleFonts.urbanist(color: Colors.black54),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AvailabilityPill(available: hasFixers),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black38,
                  ),
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
    onTap: (i) => setState(() => _tabIndex = i),
    onBookTap: () async {
      await _openBookingSheet();
    },
  );

  Future<void> _checkPendingBills(WidgetRef ref) async {
    if (_billPromptShown || _checkingBills || !mounted) return;
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
        final state = dashboardAsync.valueOrNull ?? const DashboardState();
        final isInitialLoading =
            dashboardAsync.isLoading && dashboardAsync.valueOrNull == null;
        final errorText =
            state.error ??
            dashboardAsync.whenOrNull(error: (err, _) => err.toString());
        final topFixers = ref.watch(topFixersProvider);

        if (state.isInactive) {
          return _InactiveAccountView(
            onContactSupport: () =>
                Navigator.pushNamed(context, '/profile/help'),
            onLogout: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/auth', (route) => false),
          );
        }

        _ensureServicesRepo(ref);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: Colors.white,
            bottomNavigationBar: _bottomNav(),
            body: SafeArea(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _buildHomeTab(
                    state: state,
                    isInitialLoading: isInitialLoading,
                    errorText: errorText,
                    topFixers: topFixers,
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
    required bool isInitialLoading,
    required String? errorText,
    required AsyncValue<List<dynamic>> topFixers,
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
          _greeting(state),
          const SizedBox(height: 16),
          _bookingHero(),
          const SizedBox(height: 20),
          _searchField(state.categories),
          const SizedBox(height: 20),
          _quickCategories(
            state.categories,
            onRetry: onRetry,
          ),
          const SizedBox(height: 24),
          _serviceSpotlight(
            state.services,
            onRetry: onRetry,
          ),
          const SizedBox(height: 24),
          TopFixersStrip(fixers: topFixers),
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
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.black38),
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
            style: GoogleFonts.urbanist(color: Colors.black54),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => onRetry(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF1592A),
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
          color: const Color(0xFFFDF6F2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1592A).withOpacity(0.12)),
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
    const accent = Color(0xFFF1592A);
    return Scaffold(
      backgroundColor: const Color(0xFFFDF6F2),
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
                    color: accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
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
                    color: const Color(0xFF1F1F1F),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your account is currently inactive. Please contact support or try again later.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    color: const Color(0xFF4A4A4A),
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
                      side: const BorderSide(color: accent),
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
  final bool available;
  const _AvailabilityPill({required this.available});

  @override
  Widget build(BuildContext context) {
    final bg = available
        ? Colors.green.withOpacity(0.12)
        : Colors.black.withOpacity(0.06);
    final text = available ? Colors.green.shade800 : Colors.black54;
    final label = available ? 'Available' : 'No fixers';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            size: 14,
            color: text,
          ),
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
