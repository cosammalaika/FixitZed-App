import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/state/fixers_providers.dart';
import 'package:fixitzed_app/widgets/fixer_list_item.dart';
import 'package:fixitzed_app/widgets/skeletons.dart';

class FixersListScreen extends ConsumerWidget {
  const FixersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixersAsync = ref.watch(allFixersProvider);
    final colors = Theme.of(context).fx;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          'Fixers',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: fixersAsync.when(
        loading: () => const FixerListSkeleton(),
        error: (err, _) => Center(
          child: Text(
            'Unable to load fixers',
            style: GoogleFonts.urbanist(
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No fixers yet',
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final fixer = items[i];
              if (fixer is Map) {
                return FixerListItem(fixer: fixer);
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}
