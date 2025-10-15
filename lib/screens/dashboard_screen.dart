import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api.dart';
import '../state/dashboard_controller.dart';
import '../state/fixers_providers.dart';
import '../state/service_providers.dart';
import '../utils/service_utils.dart';
import 'dashboard_widgets.dart';
import 'favorites_screen.dart';
import 'payment_sheet.dart';
import 'profile/my_booking_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _billPromptShown = false;
  bool _checkingBills = false;
  int _tabIndex = 0;
  bool _dashboardListenerAttached = false;

  Widget _greeting(DashboardState state) => DashboardGreeting(
    name: state.name,
    location: state.location,
    avatarUrl: state.avatarUrl,
    hasUnread: state.hasUnread,
    onNotificationsTap: () async {
      await Navigator.of(context).pushNamed('/notifications');
      if (!mounted) return;
      ref.read(dashboardControllerProvider.notifier).refresh();
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
                  label: const Text('Book a service'),
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
                child: const Text('Track bookings'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickCategories(List<dynamic> categories) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final normalizedCategories = categories
        .whereType<Map>()
        .map((cat) => cat.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
    final items = categories.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Popular categories',
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
              Map<String, dynamic> category = {};
              if (rawCat is Map<String, dynamic>) {
                category = Map<String, dynamic>.from(rawCat);
              } else if (rawCat is Map) {
                category = rawCat.map(
                  (key, value) => MapEntry(key.toString(), value),
                );
              }
              if (category.isEmpty && rawCat != null) {
                category = {'name': rawCat.toString()};
              }
              final name = (category['name'] ?? category['title'] ?? 'Category')
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

  Widget _serviceSpotlight(List<dynamic> services) {
    if (services.isEmpty) return const SizedBox.shrink();
    final items = services.take(4).toList();
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
          return GestureDetector(
            onTap: () => _openBookingSheet(service: map.isEmpty ? null : map),
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

  Future<void> _checkPendingBills() async {
    if (_billPromptShown || _checkingBills || !mounted) return;
    _checkingBills = true;
    try {
      final requestService = ref.read(serviceRequestServiceProvider);
      final paymentService = ref.read(paymentServiceProvider);
      final list = await requestService.listRequests();
      for (final r in list) {
        final id = (r['id'] as num?)?.toInt();
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
          await _showPayNowSheet(r, parsedAmount);
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
    Map<String, dynamic> request,
    double amount,
  ) async {
    final id = (request['id'] as num?)?.toInt();
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
    if (!_dashboardListenerAttached) {
      _dashboardListenerAttached = true;
      ref.listen<AsyncValue<DashboardState>>(dashboardControllerProvider, (
        previous,
        next,
      ) {
        next.whenOrNull(
          data: (_) {
            if (!mounted) return;
            _checkPendingBills();
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
              ),
              const MyBookingScreen(),
              const FavoritesScreen(),
              const ProfileScreen(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab({
    required DashboardState state,
    required bool isInitialLoading,
    required String? errorText,
    required AsyncValue<List<dynamic>> topFixers,
  }) {
    if (isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorText != null) {
      return _ErrorState(
        message: 'We couldn\'t load the dashboard right now.',
        detail: errorText,
        onRetry: () =>
            ref.read(dashboardControllerProvider.notifier).refresh(),
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
          _quickCategories(state.categories),
          const SizedBox(height: 24),
          _serviceSpotlight(state.services),
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
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
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
              onPressed: onRetry,
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
        ),
      ),
    );
  }
}
