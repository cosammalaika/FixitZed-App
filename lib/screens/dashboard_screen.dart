import 'dart:async';

import 'package:fixitzed_app/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api.dart';
import '../data/models/bookings_snapshot.dart';
import '../data/models/dashboard_snapshot.dart';
import '../data/models/user_summary.dart';
import '../state/bookings_controller.dart';
import '../state/dashboard_controller.dart';
import '../state/user_controller.dart';
import 'booking_sheet.dart';
import 'dashboard_widgets.dart';
import 'favorites_screen.dart';
import 'payment_sheet.dart';
import 'profile/my_booking_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _tabIndex = 0;
  int? _activePaymentPrompt;
  bool _paymentDialogVisible = false;

  bool _didSetupListener = false;

  void initState() {
    super.initState();
  }

  void _handleBookingUpdates(
    AsyncValue<BookingsSnapshot>? previous,
    AsyncValue<BookingsSnapshot> next,
  ) {
    next.whenData((snapshot) async {
      if (!mounted || _paymentDialogVisible) return;
      final due = _findOutstandingBooking(snapshot);
      if (due == null) return;
      if (_activePaymentPrompt == due.requestId) return;

      _activePaymentPrompt = due.requestId;
      _paymentDialogVisible = true;

      final paid = await _showPayNowSheet(due.requestId);
      _paymentDialogVisible = false;
      _activePaymentPrompt = null;

      if (paid) {
        await Future.wait([
          ref.read(bookingsControllerProvider.notifier).refresh(silent: true),
          ref.read(dashboardControllerProvider.notifier).refresh(silent: true),
        ]);
      }
    });
  }

  _PaymentDue? _findOutstandingBooking(BookingsSnapshot snapshot) {
    for (final booking in snapshot.bookings) {
      final id = (booking['id'] as num?)?.toInt();
      if (id == null) continue;
      final status = (booking['status'] ?? '').toString().toLowerCase();
      if (status == 'completed') continue;

      final payment = snapshot.payments[id];
      if (payment == null) continue;
      final paymentStatus = (payment['status'] ?? '').toString().toLowerCase();
      if (paymentStatus == 'paid') continue;

      final amountRaw = payment['amount'];
      final amount = amountRaw is num
          ? amountRaw.toDouble()
          : double.tryParse(amountRaw?.toString() ?? '');

      return _PaymentDue(
        requestId: id,
        booking: booking,
        payment: payment,
        amount: amount,
      );
    }
    return null;
  }

  Future<bool> _showPayNowSheet(int requestId) async {
    final paid = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(requestId: requestId),
        fullscreenDialog: true,
      ),
    );
    return paid ?? false;
  }

  Future<void> _openBookingSheet({Map<String, dynamic>? service}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => BookingSheet(initialService: service),
    );
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(dashboardControllerProvider.notifier).refresh(),
      ref.read(bookingsControllerProvider.notifier).refresh(),
      ref.read(userControllerProvider.notifier).refresh(),
    ]);
  }

  Widget build(BuildContext context) {
    // ✅ register the listener once during build
    if (!_didSetupListener) {
      _didSetupListener = true;

      ref.listen<AsyncValue<BookingsSnapshot>>(
        bookingsControllerProvider,
        _handleBookingUpdates, // (prev, next)
      );

      // replace fireImmediately: trigger once with current value
      Future.microtask(() {
        if (!mounted) return;
        final current = ref.read(bookingsControllerProvider);
        _handleBookingUpdates(null, current);
      });
    }

    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        bottomNavigationBar: DashboardBottomNav(
          currentIndex: _tabIndex,
          onTap: (index) => setState(() => _tabIndex = index),
          onBookTap: () => _openBookingSheet(),
        ),
        body: SafeArea(
          child: switch (_tabIndex) {
            1 => const MyBookingScreen(),
            2 => const FavoritesScreen(),
            3 => const ProfileScreen(),
            _ => _HomeTab(onRefresh: _onRefresh, onBookTap: _openBookingSheet),
          },
        ),
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab({required this.onRefresh, required this.onBookTap});

  final Future<void> Function() onRefresh;
  final Future<void> Function({Map<String, dynamic>? service}) onBookTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final userState = ref.watch(userControllerProvider);

    return dashboardState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _ErrorState(
        message: 'We couldn\'t load the dashboard right now.',
        detail: error?.toString(),
        onRetry: () {
          ref.read(dashboardControllerProvider.notifier).refresh();
        },
      ),
      data: (snapshot) {
        final userSummary = userState.when(
          data: (user) => user ?? snapshot.user,
          error: (_, __) => snapshot.user,
          loading: () => snapshot.user,
        );

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardGreeting(
                  name: userSummary?.displayName ?? 'there',
                  location: userSummary?.location ?? 'Welcome',
                  avatarUrl: userSummary?.avatarUrl,
                  hasUnread: snapshot.hasUnreadNotifications,
                  onNotificationsTap: () async {
                    await Navigator.of(context).pushNamed('/notifications');
                    ref
                        .read(dashboardControllerProvider.notifier)
                        .refresh(silent: true);
                  },
                ),
                const SizedBox(height: 16),
                _BookingHero(onBookTap: onBookTap),
                const SizedBox(height: 20),
                const DashboardSearchField(),
                const SizedBox(height: 20),
                _QuickCategories(categories: snapshot.categories),
                const SizedBox(height: 24),
                _ServiceSpotlight(
                  onBookTap: onBookTap,
                  services: snapshot.services,
                ),
                const SizedBox(height: 24),
                TopFixersStrip(
                  fixers: snapshot.fixers,
                  isLoading: dashboardState.isLoading,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BookingHero extends StatelessWidget {
  const _BookingHero({required this.onBookTap});

  final Future<void> Function({Map<String, dynamic>? service}) onBookTap;

  @override
  Widget build(BuildContext context) {
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
                  onPressed: onBookTap,
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
}

class _QuickCategories extends StatelessWidget {
  const _QuickCategories({required this.categories});

  final List<dynamic> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
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
              final cat = items[i];
              final name = (cat is Map && cat['name'] != null)
                  ? cat['name'].toString()
                  : (cat is Map && cat['title'] != null)
                  ? cat['title'].toString()
                  : 'Category';
              return GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, '/services', arguments: cat),
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
}

class _ServiceSpotlight extends StatelessWidget {
  const _ServiceSpotlight({required this.services, required this.onBookTap});

  final List<dynamic> services;
  final Future<void> Function({Map<String, dynamic>? service}) onBookTap;

  @override
  Widget build(BuildContext context) {
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
          final desc = (map['description'] ?? map['summary'] ?? '').toString();
          final image = Api.resolveImageUrl(map['image'] ?? map['icon']);
          return GestureDetector(
            onTap: () => onBookTap(service: map.isEmpty ? null : map),
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
                          desc.isEmpty ? 'Tap to book quickly' : desc,
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
}

class _PaymentDue {
  const _PaymentDue({
    required this.requestId,
    required this.booking,
    required this.payment,
    required this.amount,
  });

  final int requestId;
  final Map<String, dynamic> booking;
  final Map<String, dynamic> payment;
  final double? amount;
}

Map<String, dynamic> _normalizeMap(dynamic value) {
  if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String? detail;
  final VoidCallback onRetry;

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
