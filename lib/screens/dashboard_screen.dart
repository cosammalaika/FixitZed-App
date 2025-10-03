import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/home_service.dart';
import '../core/api.dart';
import 'profile_screen.dart';
import 'profile/my_booking_screen.dart';
import '../services/notification_service.dart';
import 'dashboard_widgets.dart';
import 'favorites_screen.dart';
import 'booking_sheet.dart';
import '../services/service_request_service.dart';
import '../services/payment_service.dart';
import 'payment_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final Color orange = const Color(0xFFF1592A);
  // Data
  final _svc = HomeService();
  String _greetName = '';
  String _greetLocation = '';
  String? _avatarUrl;
  List<dynamic> _categoryList = const [];
  List<dynamic> _services = const [];
  bool _loading = true;
  bool _hasUnread = false;
  Future<List<dynamic>>? _fixersFuture;

  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fixersFuture = _svc.fetchFixers();
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      if (mounted) {
        setState(() => _loading = true);
      }
      final meF = _svc.fetchMe();
      final catF = _svc.fetchCategories();
      final srvF = _svc.fetchServices();
      final me = await meF;
      final cats = await catF;
      final srvs = await srvF;
      // Fetch notifications to know if there are unread
      final notifs = await NotificationService().fetch(page: 1);

      if (!mounted) return;
      setState(() {
        if (me != null) {
          final raw = (me['user'] is Map) ? me['user'] as Map : me;
        final first = (raw['first_name'] ?? '').toString().trim();
        final last = (raw['last_name'] ?? '').toString().trim();
        final combined = [first, last].where((s) => s.isNotEmpty).join(' ');
        if (combined.isNotEmpty) {
          _greetName = combined;
        } else {
          final name = raw['name'] ?? raw['full_name'] ?? raw['username'];
          if (name is String && name.trim().isNotEmpty) {
            _greetName = name.trim();
          }
        }

        final city = (raw['city'] ?? '').toString().trim();
        final country = (raw['country'] ?? '').toString().trim();
        final address = (raw['address'] ?? raw['location'] ?? '')
            .toString()
            .trim();
        String loc = '';
        if (city.isNotEmpty && country.isNotEmpty) {
          loc = '$city, $country';
        } else if (address.isNotEmpty) {
          loc = address;
        } else if (city.isNotEmpty) {
          loc = city;
        }
        if (loc.isNotEmpty) {
          _greetLocation = loc;
        }

        final avatarRaw = (raw['profile_photo_path'] ??
                raw['avatar'] ??
                raw['photo'] ??
                raw['profile_photo_url'] ??
                raw['profile_image'] ??
                raw['image'])
            ?.toString();
        final resolvedAvatar = Api.resolveImageUrl(avatarRaw);
        _avatarUrl = resolvedAvatar.isEmpty ? null : resolvedAvatar;
      }
        _categoryList = cats;
        _services = srvs;
      // unread detection compatible with various API shapes
      bool anyUnread = false;
      for (final n in notifs) {
        final readVal = n['read'] ?? n['read_at'] ?? n['is_read'];
        bool read;
        if (readVal is bool) {
          read = readVal;
        } else if (readVal is num) {
          read = readVal != 0; // 1 => read, 0 => unread
        } else if (readVal is String) {
          final v = readVal.trim().toLowerCase();
          read = v.isNotEmpty && v != '0' && v != 'false';
        } else {
          read = false;
        }
        if (!read) {
          anyUnread = true;
          break;
        }
      }
      // Show badge only when there are truly unread notifications
        _hasUnread = anyUnread;
        _loading = false;
        _fixersFuture ??= _svc.fetchFixers();
      });
      // After data + notifications, check for pending bills and prompt nicely
      await _checkPendingBills();
    } finally {
      _refreshing = false;
    }
  }

  bool _billPromptShown = false;
  Future<void> _checkPendingBills() async {
    if (_billPromptShown) return;
    try {
      final list = await ServiceRequestService().listRequests();
      for (final r in list) {
        final id = (r['id'] as num?)?.toInt();
        final status = (r['status'] ?? '').toString();
        if (id == null || status == 'completed') continue;
        final p = await PaymentService().get(id);
        if (p == null) continue;
        final paid = ((p['status'] ?? '').toString().toLowerCase() == 'paid');
        final amount = p['amount'];
        if (!paid && amount != null) {
          if (!mounted) return;
          _billPromptShown = true;
          await _showPayNowSheet(
            r,
            (amount is num)
                ? amount.toDouble()
                : double.tryParse(amount.toString()) ?? 0,
          );
          break;
        }
      }
    } catch (_) {}
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
      await _loadData();
    }
  }

  Widget _greeting() => DashboardGreeting(
    name: _greetName,
    location: _greetLocation,
    avatarUrl: _avatarUrl,
    hasUnread: _hasUnread,
    onNotificationsTap: () async {
      await Navigator.of(context).pushNamed('/notifications');
      if (mounted) _loadData();
    },
  );

  Widget _search() => const DashboardSearchField();
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

  Widget _quickCategories() {
    if (_categoryList.isEmpty) return const SizedBox.shrink();
    final items = _categoryList.take(8).toList();
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
              final name = (cat['name'] ?? cat['title'] ?? 'Category')
                  .toString();
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

  Widget _serviceSpotlight() {
    if (_services.isEmpty) return const SizedBox.shrink();
    final items = _services.take(4).toList();
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

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  int _tabIndex = 0;

  Widget _bottomNav() => DashboardBottomNav(
    currentIndex: _tabIndex,
    onTap: (i) => setState(() => _tabIndex = i),
    onBookTap: () async {
      await _openBookingSheet();
    },
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Android: white icons
        statusBarBrightness: Brightness.dark, // iOS: white icons
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: _bottomNav(),
        body: SafeArea(
          child: () {
            if (_tabIndex == 3) return const ProfileScreen();
            if (_tabIndex == 1) return const MyBookingScreen();
            if (_tabIndex == 2) return const FavoritesScreen();
            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _greeting(),
                  const SizedBox(height: 16),
                  _bookingHero(),
                  const SizedBox(height: 20),
                  _search(),
                  const SizedBox(height: 20),
                  _quickCategories(),
                  const SizedBox(height: 24),
                  _serviceSpotlight(),
                  const SizedBox(height: 24),
                  TopFixersStrip(
                    fixersFuture: _fixersFuture ?? _svc.fetchFixers(),
                  ),
                ],
              ),
            );
          }(),
        ),
      ),
    );
  }
}
