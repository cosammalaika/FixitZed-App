import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/utils/service_utils.dart';

class DashboardGreeting extends StatefulWidget {
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
  State<DashboardGreeting> createState() => _DashboardGreetingState();
}

class _DashboardGreetingState extends State<DashboardGreeting> {
  String? _failedAvatarUrl;

  @override
  void didUpdateWidget(covariant DashboardGreeting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _failedAvatarUrl = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = (widget.avatarUrl ?? '').trim();
    final hasAvatar = avatar.isNotEmpty && avatar.toLowerCase() != 'null';
    final colors = Theme.of(context).fx;
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: colors.surfaceRaised,
          child: ClipOval(child: _buildAvatarImage(avatar, hasAvatar)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${widget.name.isEmpty ? 'there' : widget.name}',
                style: GoogleFonts.urbanist(fontSize: 16),
              ),
              Text(
                widget.location.isEmpty ? 'Welcome' : widget.location,
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
              onTap: widget.onNotificationsTap,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (Theme.of(context).brightness == Brightness.light)
                      BoxShadow(
                        color: colors.shadow,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (widget.hasUnread)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: colors.surface, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarImage(String avatar, bool hasAvatar) {
    const size = 48.0;
    if (!hasAvatar || avatar == _failedAvatarUrl) {
      return Image.asset(
        'assets/images/logo-sm.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }

    if (!avatar.startsWith('http://') && !avatar.startsWith('https://')) {
      return Image.asset(avatar, width: size, height: size, fit: BoxFit.cover);
    }

    return Image.network(
      avatar,
      width: size,
      height: size,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) {
          return child;
        }
        return const SizedBox(
          width: size,
          height: size,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (_, error, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _failedAvatarUrl == avatar) return;
          setState(() => _failedAvatarUrl = avatar);
        });
        return Image.asset(
          'assets/images/logo-sm.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      },
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
    final colors = theme.fx;
    return TextField(
      controller: _controller,
      style: TextStyle(color: theme.colorScheme.onSurface),
      cursorColor: colors.brand,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: colors.brand, width: 1.2),
        ),
      ),
    );
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final options = widget.categories;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).fx.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final maxSheetHeight = MediaQuery.of(ctx).size.height * 0.75;
        final colors = Theme.of(ctx).fx;
        return SafeArea(
          child: SizedBox(
            height: maxSheetHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
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
                  Expanded(
                    child: ListView(
                      children: [
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
                            final label =
                                (cat['name'] ?? cat['title'] ?? 'Category')
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
                              style: GoogleFonts.urbanist(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
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
    final colors = Theme.of(context).fx;
    final brand = colors.brand;
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
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            if (Theme.of(context).brightness == Brightness.light)
              BoxShadow(
                color: colors.shadow,
                blurRadius: 20,
                offset: const Offset(0, -4),
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
                              color: colors.surfaceTint,
                              borderRadius: BorderRadius.circular(20),
                            )
                          : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            items[i]['icon'] as IconData,
                            color: sel ? brand : colors.textMuted,
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
                              color: sel ? brand : colors.textMuted,
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
                              color: brand,
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
                          Text(
                            'Book',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: brand,
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

class CategoryIconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const CategoryIconLabel({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).fx;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceSubtle,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.handyman_rounded, color: colors.brand, size: 28),
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
    final colors = Theme.of(context).fx;
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
                if (categories.isEmpty) {
                  return [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.category_outlined, color: colors.brand),
                          const SizedBox(height: 8),
                          Text(
                            'No categories available right now.',
                            style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Pull to refresh the dashboard once services are added.',
                            style: GoogleFonts.urbanist(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                }
                final items = <Widget>[];
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
    final colors = Theme.of(context).fx;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
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
                      : Container(color: colors.skeletonBase),
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
    final colors = Theme.of(context).fx;
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
                  color: colors.brand,
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
                return [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.miscellaneous_services_rounded,
                            color: colors.brand,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No services yet',
                            style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Check back after services are published.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.urbanist(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              }
              final items = <Widget>[];
              for (var i = 0; i < 2 && i < services.length; i++) {
                final s = services[i] as Map;
                final id = serviceId(s, fallbackIndex: i);
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
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.more_horiz_rounded, color: colors.brand),
                            const SizedBox(height: 8),
                            Text(
                              'More services coming soon',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.urbanist(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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
