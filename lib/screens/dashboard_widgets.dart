import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/widgets/fixer_list_item.dart';

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
                      color: Colors.black.withValues(alpha: 0.06),
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

class DashboardSearchField extends StatefulWidget {
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<Map<String, dynamic>?>? onFilterSelected;
  final List<Map<String, dynamic>> categories;

  const DashboardSearchField({
    super.key,
    this.onSubmitted,
    this.onFilterSelected,
    this.categories = const [],
  });

  @override
  State<DashboardSearchField> createState() => _DashboardSearchFieldState();
}

class _DashboardSearchFieldState extends State<DashboardSearchField> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _controller,
      style: TextStyle(color: theme.colorScheme.onSurface),
      cursorColor: const Color(0xFFF1592A),
      textInputAction: TextInputAction.search,
      onSubmitted: (value) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;
        FocusScope.of(context).unfocus();
        widget.onSubmitted?.call(trimmed);
      },
      decoration: InputDecoration(
        hintText: 'Search services, categories...',
        hintStyle: TextStyle(color: theme.hintColor),
        filled: true,
        fillColor: theme.cardColor,
        prefixIcon: Icon(Icons.search_rounded, color: theme.hintColor),
        suffixIcon: IconButton(
          icon: Icon(Icons.tune_rounded, color: theme.hintColor),
          onPressed: () => _openFilterSheet(context),
          tooltip: 'Filter',
        ),
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

  Future<void> _openFilterSheet(BuildContext context) async {
    final options = widget.categories;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Filter by category',
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.grid_view_rounded),
                  title: const Text('All services'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    FocusScope.of(context).unfocus();
                    widget.onFilterSelected?.call(null);
                  },
                ),
                if (options.isNotEmpty)
                  ...options.map((cat) {
                    final label = (cat['name'] ?? cat['title'] ?? 'Category')
                        .toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.label_rounded),
                      title: Text(label),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        FocusScope.of(context).unfocus();
                        widget.onFilterSelected?.call(cat);
                      },
                    );
                  }),
                if (options.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No categories available yet. Try refreshing the dashboard.',
                      style: GoogleFonts.urbanist(color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DashboardBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onBookTap;
  const DashboardBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onBookTap,
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
          children:
              List.generate(items.length, (i) {
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
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: sel ? brand : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })
                // Insert a prominent center 'Book' button between item 1 and 2
                ..insert(
                  2,
                  GestureDetector(
                    onTap: onBookTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 76,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1592A),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.event_available_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Book',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF1592A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class TopFixersStrip extends StatelessWidget {
  final AsyncValue<List<dynamic>> fixers;
  const TopFixersStrip({super.key, required this.fixers});

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
        fixers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Center(child: Text('Unable to load top fixers right now.')),
          data: (items) {
            final mapped = items
                .whereType<Object>()
                .map<Map<String, dynamic>>((item) {
                  if (item is Map<String, dynamic>) {
                    return Map<String, dynamic>.from(item);
                  }
                  if (item is Map) {
                    return item.map(
                      (key, value) => MapEntry(key.toString(), value),
                    );
                  }
                  return <String, dynamic>{};
                })
                .where((map) => map.isNotEmpty)
                .toList();

            if (mapped.isEmpty) {
              return const Center(child: Text('No fixers yet'));
            }

            final displayCount = mapped.length > 5 ? 5 : mapped.length;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: displayCount,
              itemBuilder: (ctx, i) {
                return FixerListItem(fixer: mapped[i]);
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
        SizedBox(
          height: 96,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: () {
                final items = <Widget>[];
                if (categories.isEmpty) {
                  const data = [
                    {
                      'icon': Icons.cleaning_services_rounded,
                      'name': 'Cleaning',
                    },
                    {'icon': Icons.build_rounded, 'name': 'Repairing'},
                    {'icon': Icons.format_paint_rounded, 'name': 'Painting'},
                    {'icon': Icons.grid_view_rounded, 'name': 'More'},
                  ];
                  for (final c in data) {
                    if (items.isNotEmpty) items.add(const SizedBox(width: 16));
                    items.add(
                      CategoryIconLabel(
                        icon: c['icon'] as IconData,
                        label: c['name'] as String,
                      ),
                    );
                  }
                } else {
                  for (var i = 0; i < categories.length; i++) {
                    final c = categories[i] as Map;
                    final label = (c['name'] ?? c['title'] ?? 'Category')
                        .toString();
                    if (items.isNotEmpty) items.add(const SizedBox(width: 16));
                    items.add(
                      CategoryIconLabel(
                        icon: Icons.handyman_rounded,
                        label: label,
                      ),
                    );
                  }
                }
                return items;
              }(),
            ),
          ),
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
