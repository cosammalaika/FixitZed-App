import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/core/booking_status.dart';
import 'package:fixitzed_app/core/date_utils.dart';
import 'package:fixitzed_app/state/auth_controller.dart';
import 'package:fixitzed_app/state/my_bookings_controller.dart';
import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/screens/payment_sheet.dart';
import 'package:fixitzed_app/widgets/skeletons.dart';
import 'package:fixitzed_app/widgets/auth_required.dart';

import 'package:fixitzed_app/screens/profile/booking_detail_screen.dart';

class MyBookingScreen extends ConsumerWidget {
  const MyBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.fx;
    final authState = ref.watch(authControllerProvider);

    if (authState.isInitializing) {
      return Scaffold(
        appBar: _appBar(theme),
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!authState.isAuthenticated) {
      return _GuestBookingsView(
        onAuthenticate: () async {
          final ok = await ensureAuthenticated(
            context,
            title: 'Sign in to view bookings',
            message:
                'Booking history is private to your account. You can keep browsing services as a guest.',
            actionLabel: 'View bookings',
          );
          if (ok) {
            await ref.read(myBookingsControllerProvider.notifier).refresh();
          }
        },
      );
    }

    final bookingsAsync = ref.watch(myBookingsControllerProvider);

    return Scaffold(
      appBar: _appBar(theme),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: bookingsAsync.when(
        loading: () => const BookingListSkeleton(),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 48, color: colors.textMuted),
                const SizedBox(height: 16),
                Text(
                  'Unable to load your bookings.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(color: colors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.read(myBookingsControllerProvider.notifier).refresh(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
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
        ),
        data: (state) {
          Widget content;
          if (state.requests.isEmpty) {
            content = ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 120),
              children: [
                Center(
                  child: Text(
                    'No bookings yet',
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            );
          } else {
            content = ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: state.requests.length,
              itemBuilder: (ctx, i) {
                final r = state.requests[i];
                final service = (r['service'] is Map)
                    ? r['service'] as Map
                    : null;
                final fixer = (r['fixer'] is Map) ? r['fixer'] as Map : null;
                final title =
                    (service != null
                            ? (service['name'] ?? service['title'])
                            : r['service_name'] ?? 'Service')
                        .toString();
                final rawStatus = r['status'];
                final scheduledRaw =
                    r['scheduled_at'] ?? r['scheduledAt'] ?? r['schedule'];
                final scheduledDt = parseAppDate(scheduledRaw);
                final scheduledLabel = scheduledDt != null
                    ? formatAppDateTime(scheduledDt)
                    : null;
                final rid = (r['id'] as num?)?.toInt();
                final pay = rid != null ? state.payments[rid] : null;
                final payStatus = (pay?['status'] ?? '')
                    .toString()
                    .toLowerCase();
                final payAmount = pay?['amount'];
                final parsedStatus = parseBookingStatus(rawStatus);
                final label = bookingStatusLabel(parsedStatus);
                final hasDue =
                    rid != null &&
                    payAmount != null &&
                    payStatus != 'paid' &&
                    parsedStatus != BookingStatus.completed;
                return InkWell(
                  onTap: () async {
                    var requestData = Map<String, dynamic>.from(r);
                    if (rid != null) {
                      final detail = await ref
                          .read(serviceRequestServiceProvider)
                          .getRequest(rid);
                      if (detail != null && detail.isNotEmpty) {
                        requestData = {...requestData, ...detail};
                      }
                    }
                    final refresh = await showBookingDetailSheet(
                      context,
                      requestData,
                    );
                    if (refresh == true) {
                      await ref
                          .read(myBookingsControllerProvider.notifier)
                          .refresh();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colors.surfaceTint,
                          child: Icon(
                            Icons.event_available_rounded,
                            color: colors.brand,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.urbanist(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (scheduledLabel != null)
                                Text(
                                  'Scheduled: $scheduledLabel',
                                  style: GoogleFonts.urbanist(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              if (fixer != null)
                                Text(
                                  'Fixer: ${_fixerName(fixer)}',
                                  style: GoogleFonts.urbanist(
                                    color: colors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        hasDue
                            ? ElevatedButton(
                                onPressed: () async {
                                  final paid =
                                      await Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PaymentScreen(requestId: rid),
                                          fullscreenDialog: true,
                                        ),
                                      );
                                  if (paid == true) {
                                    await ref
                                        .read(
                                          myBookingsControllerProvider.notifier,
                                        )
                                        .refresh();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.brand,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Pay'),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusBg(parsedStatus),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  label,
                                  style: GoogleFonts.urbanist(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _statusFg(parsedStatus),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                );
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(myBookingsControllerProvider.notifier).refresh(),
            child: content,
          );
        },
      ),
    );
  }

  PreferredSizeWidget _appBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      title: Text(
        'My Bookings',
        style: GoogleFonts.urbanist(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
    );
  }

  Color _statusBg(BookingStatus status) {
    switch (status) {
      case BookingStatus.accepted:
        return const Color(0x1A2E7D32);
      case BookingStatus.cancelled:
        return const Color(0x1AD32F2F);
      case BookingStatus.completed:
        return const Color(0x1A1976D2);
      case BookingStatus.pending:
      case BookingStatus.unknown:
        return const Color(0x1AF1592A);
    }
  }

  Color _statusFg(BookingStatus status) {
    switch (status) {
      case BookingStatus.accepted:
        return const Color(0xFF2E7D32);
      case BookingStatus.cancelled:
        return const Color(0xFFD32F2F);
      case BookingStatus.completed:
        return const Color(0xFF1976D2);
      case BookingStatus.pending:
      case BookingStatus.unknown:
        return const Color(0xFFF1592A);
    }
  }

  String _fixerName(Map fixer) {
    String fromMap(Map m) {
      final first = (m['first_name'] ?? m['firstName'] ?? '').toString().trim();
      final last = (m['last_name'] ?? m['lastName'] ?? '').toString().trim();
      if (first.isNotEmpty || last.isNotEmpty) {
        return [first, last].where((e) => e.isNotEmpty).join(' ');
      }
      final name =
          (m['name'] ??
                  m['full_name'] ??
                  m['display_name'] ??
                  m['username'] ??
                  m['company_name'] ??
                  m['business_name'] ??
                  '')
              .toString()
              .trim();
      return name.isNotEmpty ? name : '';
    }

    if (fixer['user'] is Map) {
      final u = Map<String, dynamic>.from(fixer['user'] as Map);
      final nm = fromMap(u);
      if (nm.isNotEmpty) return nm;
    }
    final direct = fromMap(fixer);
    return direct.isNotEmpty ? direct : 'Pending assignment';
  }
}

class _GuestBookingsView extends StatelessWidget {
  const _GuestBookingsView({required this.onAuthenticate});

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
          'My Bookings',
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
                child: Icon(Icons.event_note_outlined, color: brand, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign in to track bookings',
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can browse services without an account. Sign in when you are ready to request service and track every booking.',
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
