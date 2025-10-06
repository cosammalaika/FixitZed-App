import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/fixers_providers.dart';
import '../widgets/fixer_list_item.dart';

class FixersListScreen extends ConsumerWidget {
  const FixersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixersAsync = ref.watch(allFixersProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onBackground,
        ),
        title: Text(
          'Fixers',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: fixersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Unable to load fixers',
            style: GoogleFonts.urbanist(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
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
                  color: Colors.black54,
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
