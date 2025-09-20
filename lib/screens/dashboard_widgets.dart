import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api.dart';
import '../core/fixer_utils.dart';

class DashboardGreeting extends StatelessWidget {
  final String name;
  final String location;
  final String? avatarUrl;
  final bool hasUnread;
  final VoidCallback onNotificationsTap;

  const DashboardGreeting({
    super.key,
    required this.name,
    required this.location,
    required this.avatarUrl,
    required this.hasUnread,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
              ? (avatarUrl!.startsWith('http')
                    ? NetworkImage(avatarUrl!) as ImageProvider
                    : AssetImage(avatarUrl!))
              : const AssetImage('assets/images/logo-sm.png'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${name.isEmpty ? 'there' : name}',
                style: GoogleFonts.urbanist(fontSize: 16),
              ),
              Text(
                location.isEmpty ? 'Welcome' : location,
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
              onTap: onNotificationsTap,
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
            if (hasUnread)
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
}

class DashboardSearchField extends StatelessWidget {
  const DashboardSearchField({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      style: TextStyle(color: theme.colorScheme.onSurface),
      cursorColor: const Color(0xFFF1592A),
      decoration: InputDecoration(
        hintText: 'Search...',
        hintStyle: TextStyle(color: theme.hintColor),
        filled: true,
        fillColor: theme.cardColor,
        prefixIcon: Icon(Icons.search, color: theme.hintColor),
        suffixIcon: Icon(Icons.tune_rounded, color: theme.hintColor),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Color(0xFFF1592A), width: 1.2),
        ),
      ),
    );
  }
}

class DashboardBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const DashboardBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    final items = [
      {
        'icon': currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
        'label': 'Home',
      },
      {
        'icon': currentIndex == 1
            ? Icons.calendar_today_rounded
            : Icons.calendar_month_outlined,
        'label': 'Bookings',
      },
      {
        'icon': currentIndex == 2
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        'label': 'Favorites',
      },
      {
        'icon': currentIndex == 3
            ? Icons.chat_bubble_rounded
            : Icons.chat_bubble_outline_rounded,
        'label': 'Chat',
      },
      {
        'icon': currentIndex == 4
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
            final sel = i == currentIndex;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
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
}

class TopFixersStrip extends StatelessWidget {
  final Future<List<dynamic>>? fixersFuture;
  const TopFixersStrip({super.key, required this.fixersFuture});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Top Rated Fixers',
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pushNamed('/fixers'),
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
        FutureBuilder<List<dynamic>>(
          future: fixersFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = (snap.data ?? const []);
            if (items.isEmpty) {
              return const Center(child: Text('No fixers yet'));
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length.clamp(0, 5),
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (ctx, i) {
                final f = items[i] as Map;
                final name = fixerDisplayName(f);
                final avatarRaw =
                    (f['avatar'] ??
                            f['photo'] ??
                            f['image_url'] ??
                            f['profile_photo_path'] ??
                            f['profile_image'])
                        ?.toString();
                final avatar = Api.resolveImageUrl(avatarRaw);
                final services = (f['services'] ?? []) as List;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    CircleAvatar(
                      backgroundColor: Color(0xFFF1592A),
                      radius: 28,
                      backgroundImage: avatar.isNotEmpty
                          ? NetworkImage(avatar)
                          : const AssetImage('assets/images/logo-sm.png'),
                    ),
                    const SizedBox(width: 12),

                    // Name + Services
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.urbanist(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: List.generate(
                              services.length > 3 ? 3 : services.length,
                              (j) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF1592A,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  (services[j]['name'] ??
                                          services[j]['title'] ??
                                          "Service")
                                      .toString(),
                                  style: GoogleFonts.urbanist(
                                    fontSize: 12,
                                    color: const Color(0xFFF1592A),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class CategoryIconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const CategoryIconLabel({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.handyman_rounded,
            color: Color(0xFFF1592A),
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.urbanist()),
      ],
    );
  }
}

class CategoriesBlock extends StatelessWidget {
  final List<dynamic> categories;
  const CategoriesBlock({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
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
        if (categories.isEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              CategoryIconLabel(
                icon: Icons.cleaning_services_rounded,
                label: 'Cleaning',
              ),
              CategoryIconLabel(icon: Icons.build_rounded, label: 'Repairing'),
              CategoryIconLabel(
                icon: Icons.format_paint_rounded,
                label: 'Painting',
              ),
              CategoryIconLabel(icon: Icons.grid_view_rounded, label: 'More'),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) {
              if (i >= categories.length) {
                return const CategoryIconLabel(
                  icon: Icons.build_rounded,
                  label: 'More',
                );
              }
              final c = categories[i] as Map;
              final label = (c['name'] ?? c['title'] ?? 'Category').toString();
              return CategoryIconLabel(
                icon: Icons.handyman_rounded,
                label: label,
              );
            }),
          ),
      ],
    );
  }
}

class PopularCard extends StatelessWidget {
  final String id;
  final String title;
  final String imageUrl;
  final Widget favoriteButton;
  const PopularCard({
    super.key,
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.favoriteButton,
  });

  @override
  Widget build(BuildContext context) {
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: imageUrl.isNotEmpty
                      ? Image(
                          image: imageUrl.startsWith('http')
                              ? NetworkImage(imageUrl) as ImageProvider
                              : AssetImage(imageUrl),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : Container(color: Colors.grey.shade300),
                ),
                Positioned(right: 8, top: 8, child: favoriteButton),
              ],
            ),
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
}

class PopularServicesBlock extends StatelessWidget {
  final List<dynamic> services;
  final Widget Function(String id) favoriteBuilder;
  const PopularServicesBlock({
    super.key,
    required this.services,
    required this.favoriteBuilder,
  });

  @override
  Widget build(BuildContext context) {
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
            GestureDetector(
              onTap: () => Navigator.of(context).pushNamed('/services'),
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
          height: 180,
          child: Row(
            children: () {
              if (services.isEmpty) {
                return const [
                  Expanded(
                    child: PopularCard(
                      id: 'demo-house',
                      title: 'House Cleaning',
                      imageUrl: '',
                      favoriteButton: SizedBox.shrink(),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: PopularCard(
                      id: 'demo-handyman',
                      title: 'Handyman',
                      imageUrl: '',
                      favoriteButton: SizedBox.shrink(),
                    ),
                  ),
                ];
              }
              final items = <Widget>[];
              for (var i = 0; i < 2 && i < services.length; i++) {
                final s = services[i] as Map;
                final id = (s['id'] ?? s['uuid'] ?? '$i').toString();
                final title = (s['name'] ?? s['title'] ?? 'Service').toString();
                final img = (s['image'] ?? s['image_url'] ?? '').toString();
                if (items.isNotEmpty) items.add(const SizedBox(width: 12));
                items.add(
                  Expanded(
                    child: PopularCard(
                      id: id,
                      title: title,
                      imageUrl: img,
                      favoriteButton: favoriteBuilder(id),
                    ),
                  ),
                );
              }
              if (items.length == 1) {
                items
                  ..add(const SizedBox(width: 12))
                  ..add(
                    const Expanded(
                      child: PopularCard(
                        id: 'demo-more',
                        title: 'More Services',
                        imageUrl: '',
                        favoriteButton: SizedBox.shrink(),
                      ),
                    ),
                  );
              }
              return items;
            }(),
          ),
        ),
      ],
    );
  }
}
