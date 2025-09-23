import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../services/home_service.dart';
import '../core/api.dart';
import 'profile_screen.dart';
import '../services/notification_service.dart';
import '../services/favorites_service.dart';
import 'dashboard_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Color orange = const Color(0xFFF1592A);
  final PageController _pageCtrl = PageController();
  int _page = 0;

  // Data
  final _svc = HomeService();
  String _greetName = '';
  String _greetLocation = '';
  String? _avatarUrl;
  List<dynamic> _categoryList = const [];
  List<dynamic> _services = const [];
  bool _loading = true;
  Map<String, dynamic>? _coupon; // first/featured
  List<Map<String, dynamic>> _coupons = const [];
  bool _hasUnread = false;
  Timer? _carouselTimer;
  Future<List<dynamic>>? _fixersFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
    _fixersFuture = _svc.fetchFixers();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final meF = _svc.fetchMe();
    final catF = _svc.fetchCategories();
    final srvF = _svc.fetchServices();
    final me = await meF;
    final cats = await catF;
    final srvs = await srvF;
    final list = await _svc.fetchCoupons();
    // Fetch notifications to know if there are unread
    final notifs = await NotificationService().fetch(page: 1);

    if (!mounted) return;
    setState(() {
      if (me != null) {
        final raw = (me['user'] is Map) ? me['user'] as Map : me;
        final name = raw['name'] ?? raw['full_name'] ?? raw['username'];
        if (name is String && name.trim().isNotEmpty) _greetName = name.trim();

        final city = (raw['city'] ?? '').toString().trim();
        final country = (raw['country'] ?? '').toString().trim();
        final address = (raw['address'] ?? raw['location'] ?? '')
            .toString()
            .trim();
        String loc = '';
        if (city.isNotEmpty && country.isNotEmpty)
          loc = '$city, $country';
        else if (address.isNotEmpty)
          loc = address;
        else if (city.isNotEmpty)
          loc = city;
        if (loc.isNotEmpty) _greetLocation = loc;

        String? avatar =
            (raw['profile_photo_path'] ??
                    raw['avatar'] ??
                    raw['photo'] ??
                    raw['profile_photo_url'] ??
                    raw['profile_image'] ??
                    raw['image'])
                ?.toString();
        if (avatar != null && avatar.trim().isNotEmpty) {
          avatar = avatar.trim();
          if (!avatar.startsWith('http')) {
            final base = Api.baseUrl;
            final origin = base.endsWith('/api')
                ? base.substring(0, base.length - 4)
                : base;
            final path = avatar.startsWith('/') ? avatar.substring(1) : avatar;
            _avatarUrl = path.startsWith('storage/')
                ? '$origin/$path'
                : '$origin/storage/$path';
          } else {
            _avatarUrl = avatar;
          }
        }
      }
      _categoryList = cats;
      _services = srvs;
      _coupons = list;
      _coupon = list.isNotEmpty ? list.first : null;
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
    });
    _startAutoCarousel();
  }

  void _startAutoCarousel() {
    _carouselTimer?.cancel();
    final count = _coupons.isEmpty ? 3 : _coupons.length;
    if (count <= 1) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      final next = (_page + 1) % count;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _page = next);
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
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

  Widget _offerCard(Color color, {Map<String, dynamic>? coupon}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  (() {
                    final c = coupon ?? _coupon;
                    if (c == null) return '40%';
                    final dp = c['discount_percent'];
                    final da = c['discount_amount'];
                    if (dp != null) return '${dp.toString()}%';
                    if (da != null) return da.toString();
                    return '40%';
                  })(),
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  (coupon ?? _coupon) != null
                      ? (((coupon ?? _coupon)!['title']) ??
                            "Today's Special Offer")
                      : "Today's Special Offer",
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (coupon ?? _coupon) != null
                      ? (((coupon ?? _coupon)!['description']) ??
                            'Get discount for every order, only\nvalid for today')
                      : 'Get discount for every order, only\nvalid for today',
                  style: GoogleFonts.urbanist(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: Icon(Icons.handyman_rounded, color: Colors.white, size: 72),
          ),
        ],
      ),
    );
  }

  Widget _offersCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Special Offer',
          style: GoogleFonts.urbanist(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: PageView(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _page = i),
            children: () {
              if (_coupons.isEmpty) {
                return [
                  _offerCard(const Color(0xFFF1592A)),
                  _offerCard(const Color(0xFFFA7A50)),
                  _offerCard(const Color(0xFFE65100)),
                ];
              }
              final palette = [
                const Color(0xFFF1592A),
                orange,
                const Color(0xFFFA7A50), // lighter orange accent
                const Color(0xFFE65100), // deep orange accent
              ];
              return List.generate(_coupons.length, (i) {
                final color = palette[i % palette.length];
                return _offerCard(color, coupon: _coupons[i]);
              });
            }(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate((_coupons.isEmpty ? 3 : _coupons.length), (
            i,
          ) {
            final active = i == _page;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? Color(0xFFF1592A) : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _categories() => CategoriesBlock(categories: _categoryList);

  Widget _favoriteButton(String keyId) {
    return FutureBuilder<bool>(
      future: FavoritesService.isFavorite(keyId),
      builder: (ctx, snap) {
        final liked = snap.data == true;
        return InkWell(
          onTap: () async {
            await FavoritesService.toggle(keyId);
            if (!mounted) return;
            setState(() {});
          },
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              color: liked ? Colors.red : Colors.grey,
              size: 18,
            ),
          ),
        );
      },
    );
  }

  Widget _popular() => PopularServicesBlock(
    services: _services,
    favoriteBuilder: (id) => _favoriteButton(id),
  );

  Widget _topFixers() => TopFixersStrip(fixersFuture: _fixersFuture);

  int _tabIndex = 0;

  Widget _bottomNav() => DashboardBottomNav(
    currentIndex: _tabIndex,
    onTap: (i) => setState(() => _tabIndex = i),
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
          child: _tabIndex == 4
              ? const ProfileScreen()
              : (_loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _greeting(),
                            const SizedBox(height: 16),
                            _search(),
                            const SizedBox(height: 20),
                            _offersCarousel(),
                            const SizedBox(height: 20),
                            _categories(),
                            const SizedBox(height: 20),
                            _popular(),
                            const SizedBox(height: 20),
                            _topFixers(),
                          ],
                        ),
                      )),
        ),
      ),
    );
  }
}
