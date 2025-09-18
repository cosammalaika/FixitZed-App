import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/home_service.dart';
import '../core/api.dart';
import 'profile_screen.dart';
import '../services/notification_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
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
      _hasUnread = anyUnread || notifs.isNotEmpty;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Widget _greeting() {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
              ? (_avatarUrl!.startsWith('http')
                    ? NetworkImage(_avatarUrl!) as ImageProvider
                    : AssetImage(_avatarUrl!))
              : const AssetImage('assets/images/logo-sm.png'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${_greetName.isEmpty ? 'there' : _greetName}',
                style: GoogleFonts.urbanist(fontSize: 16),
              ),
              Text(
                _greetLocation.isEmpty ? 'Welcome' : _greetLocation,
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        Stack(
          children: [
            GestureDetector(
              onTap: () async {
                await Navigator.of(context).pushNamed('/notifications');
                if (mounted) _loadData(); // refresh unread badge after return
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
            if (_hasUnread)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _search() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search...',
        filled: true,
        fillColor: Colors.grey.shade100,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: const Icon(Icons.tune_rounded),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

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
                return [_offerCard(const Color(0xFFF1592A))];
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
          children: List.generate((_coupons.isEmpty ? 1 : _coupons.length), (
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

  Widget _category(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Color(0xFFF1592A), size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.urbanist()),
      ],
    );
  }

  Widget _categories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: GoogleFonts.urbanist(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (_categoryList.isEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _category(Icons.cleaning_services_rounded, 'Cleaning'),
              _category(Icons.build_rounded, 'Repairing'),
              _category(Icons.format_paint_rounded, 'Painting'),
              _category(Icons.grid_view_rounded, 'More'),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) {
              if (i >= _categoryList.length) {
                return _category(Icons.build_rounded, 'More');
              }
              final c = _categoryList[i] as Map;
              final label = (c['name'] ?? c['title'] ?? 'Category').toString();
              return _category(Icons.handyman_rounded, label);
            }),
          ),
      ],
    );
  }

  Widget _popularCard(String title, String asset) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: asset.isNotEmpty
                ? Image(
                    image: asset.startsWith('http')
                        ? NetworkImage(asset) as ImageProvider
                        : AssetImage(asset),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  )
                : Container(color: Colors.grey.shade300),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              title,
              style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _popular() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Popular Services',
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'View All',
              style: GoogleFonts.urbanist(
                color: Color(0xFFF1592A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: Row(
            children: () {
              if (_services.isEmpty) {
                return [
                  Expanded(child: _popularCard('House Cleaning', '')),
                  const SizedBox(width: 12),
                  Expanded(child: _popularCard('Handyman', '')),
                ];
              }
              final items = <Widget>[];
              for (var i = 0; i < 2 && i < _services.length; i++) {
                final s = _services[i] as Map;
                final title = (s['name'] ?? s['title'] ?? 'Service').toString();
                final img = (s['image'] ?? s['image_url'] ?? '').toString();
                if (items.isNotEmpty) items.add(const SizedBox(width: 12));
                items.add(Expanded(child: _popularCard(title, img)));
              }
              if (items.length == 1) {
                items
                  ..add(const SizedBox(width: 12))
                  ..add(Expanded(child: _popularCard('More Services', '')));
              }
              return items;
            }(),
          ),
        ),
      ],
    );
  }

  int _tabIndex = 0;

  Widget _bottomNav() {
    const brand = Color(0xFFF1592A);
    final items = [
      {
        'icon': _tabIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
        'label': 'Home',
      },
      {
        'icon': _tabIndex == 1
            ? Icons.calendar_today_rounded
            : Icons.calendar_month_outlined,
        'label': 'Bookings',
      },
      {
        'icon': _tabIndex == 2
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        'label': 'Favorites',
      },
      {
        'icon': _tabIndex == 3
            ? Icons.chat_bubble_rounded
            : Icons.chat_bubble_outline_rounded,
        'label': 'Chat',
      },
      {
        'icon': _tabIndex == 4
            ? Icons.person_rounded
            : Icons.person_outline_rounded,
        'label': 'Profile',
      },
    ];

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final sel = i == _tabIndex;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _tabIndex = i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: sel
                    ? BoxDecoration(
                        color: const Color(0x1AF1592A),
                        borderRadius: BorderRadius.circular(20),
                      )
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[i]['icon'] as IconData,
                      color: sel ? brand : Colors.black38,
                      size: sel ? 26 : 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i]['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? brand : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        ],
                      ),
                    )),
      ),
    );
  }
}
