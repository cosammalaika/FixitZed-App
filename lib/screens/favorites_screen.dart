import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/repositories/favorites_repository.dart';
import 'package:fixitzed_app/repositories/services_repository.dart';
import 'package:fixitzed_app/state/auth_controller.dart';
import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/utils/service_utils.dart';
import 'package:fixitzed_app/widgets/auth_required.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _favoriteServices = const [];
  Set<String> _favIds = {};
  FavoritesRepository? _favoritesRepository;
  ServicesRepository? _servicesRepository;
  late final VoidCallback _favListener;

  @override
  void initState() {
    super.initState();
    _favListener = () => _load();
  }

  Future<void> _load() async {
    _favoritesRepository ??= ref.read(favoritesRepositoryProvider);
    _servicesRepository ??= ref.read(servicesRepositoryProvider);
    final favRepo = _favoritesRepository!;
    final servicesRepo = _servicesRepository!;
    if (mounted) setState(() => _loading = true);
    final favList = await favRepo.getFavoriteServices(servicesRepo);
    final favIds = await favRepo.getFavoriteIds();
    if (!mounted) return;
    setState(() {
      _favIds = favIds;
      _favoriteServices = favList;
      _loading = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _favoritesRepository ??= ref.read(favoritesRepositoryProvider);
    _favoritesRepository?.removeListener(_favListener);
    _favoritesRepository?.addListener(_favListener);
    unawaited(_load());
  }

  @override
  void dispose() {
    _favoritesRepository?.removeListener(_favListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    if (authState.isInitializing) {
      return Scaffold(
        appBar: _appBar(theme),
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!authState.isAuthenticated) {
      return _GuestFavoritesView(
        onAuthenticate: () async {
          final ok = await ensureAuthenticated(
            context,
            title: 'Sign in to save favorites',
            message:
                'You can browse all services as a guest. Sign in to save services and come back to them later.',
            actionLabel: 'Save favorites',
          );
          if (ok) {
            await _load();
          }
        },
      );
    }

    return Scaffold(
      appBar: _appBar(theme),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_favoriteServices.isEmpty
                ? _emptyState(context)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _favoriteServices.length,
                      itemBuilder: (ctx, i) {
                        final s = _favoriteServices[i];
                        final id = serviceId(s, fallbackIndex: i);
                        final title = (s['name'] ?? s['title'] ?? 'Service')
                            .toString();
                        final description =
                            (s['description'] ?? s['summary'] ?? '')
                                .toString()
                                .trim();
                        final category = serviceCategoryLabel(s);
                        final subtitle =
                            category ??
                            (description.isEmpty
                                ? 'Tap to book quickly'
                                : description);
                        final img = (s['image'] ?? s['image_url'] ?? '')
                            .toString();
                        final liked = _favIds.contains(id);
                        final colors = Theme.of(context).fx;
                        return GestureDetector(
                          onTap: () =>
                              showServiceDetailsSheet(context, service: s),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: img.isNotEmpty
                                      ? Image(
                                          image: img.startsWith('http')
                                              ? NetworkImage(img)
                                                    as ImageProvider
                                              : AssetImage(img),
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 56,
                                          height: 56,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: colors.surfaceRaised,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.handyman_rounded,
                                            color: colors.textMuted,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: GoogleFonts.urbanist(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              liked
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: liked
                                                  ? colors.danger
                                                  : colors.textMuted,
                                            ),
                                            onPressed: () async {
                                              final repo = ref.read(
                                                favoritesRepositoryProvider,
                                              );
                                              await repo.toggle(id);
                                              await _load();
                                            },
                                          ),
                                        ],
                                      ),
                                      if (subtitle.isNotEmpty)
                                        Text(
                                          subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.urbanist(
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )),
    );
  }

  PreferredSizeWidget _appBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      title: Text(
        'Favorites',
        style: GoogleFonts.urbanist(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _emptyState(BuildContext context) {
    final colors = Theme.of(context).fx;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 64,
              color: colors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No favorites yet',
              style: GoogleFonts.urbanist(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the heart on any service to add it here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestFavoritesView extends StatelessWidget {
  const _GuestFavoritesView({required this.onAuthenticate});

  final VoidCallback onAuthenticate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.fx;
    final brand = colors.brand;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          'Favorites',
          style: GoogleFonts.urbanist(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colors.surfaceTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_border_rounded,
                  color: brand,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Save services after signing in',
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Explore services freely as a guest. Create an account when you want a personal favorites list.',
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAuthenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Sign in or create account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
