import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/date_utils.dart';
import '../../state/bookings_controller.dart';
import '../payment_sheet.dart';
import 'booking_detail_screen.dart';

class MyBookingScreen extends ConsumerWidget {
  const MyBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsState = ref.watch(bookingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'My Bookings',
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: bookingsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorState(
          message: 'Could not load your bookings.',
          detail: error?.toString(),
          onRetry: () =>
              ref.read(bookingsControllerProvider.notifier).refresh(),
        ),
        data: (snapshot) {
          final bookings = snapshot.bookings;
          if (bookings.isEmpty) {
            return Center(
              child: Text(
                'No bookings yet',
                style: GoogleFonts.urbanist(color: Colors.black54),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(bookingsControllerProvider.notifier).refresh(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: bookings.length,
              itemBuilder: (ctx, i) {
                final booking = bookings[i];
                return _BookingCard(
                  booking: booking,
                  payment: snapshot.payments[(booking['id'] as num?)?.toInt()],
                  onPay: () async {
                    final id = (booking['id'] as num?)?.toInt();
                    if (id == null) return;
                    final paid =
                        await Navigator.of(
                          context,
                          rootNavigator: true,
                        ).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(requestId: id),
                            fullscreenDialog: true,
                          ),
                        );
                    if (paid == true && context.mounted) {
                      await ref
                          .read(bookingsControllerProvider.notifier)
                          .refresh();
                    }
                  },
                  onTap: () async {
                    final refresh = await showBookingDetailSheet(
                      context,
                      Map<String, dynamic>.from(booking),
                    );
                    if (refresh == true) {
                      await ref
                          .read(bookingsControllerProvider.notifier)
                          .refresh();
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.payment,
    required this.onPay,
    required this.onTap,
  });

  final Map<String, dynamic> booking;
  final Map<String, dynamic>? payment;
  final VoidCallback onPay;
  final VoidCallback onTap;

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = booking['service'] is Map
        ? booking['service'] as Map
        : null;
    final fixer = booking['fixer'] is Map ? booking['fixer'] as Map : null;
    final title =
        (service != null
                ? (service['name'] ?? service['title'])
                : booking['service_name'] ?? 'Service')
            .toString();
    final status = (booking['status'] ?? 'pending').toString();
    final scheduledRaw =
        booking['scheduled_at'] ??
        booking['scheduledAt'] ??
        booking['schedule'];
    final scheduledDt = parseAppDate(scheduledRaw);
    final scheduledLabel = scheduledDt != null
        ? formatAppDateTime(scheduledDt)
        : null;
    final id = (booking['id'] as num?)?.toInt();
    final paymentStatus = (payment?['status'] ?? '').toString().toLowerCase();
    final amount = payment?['amount'];
    final hasDue =
        id != null &&
        amount != null &&
        paymentStatus != 'paid' &&
        status.toLowerCase() != 'completed';

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0x1AF1592A),
              child: Icon(
                Icons.event_available_rounded,
                color: Color(0xFFF1592A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  if (scheduledLabel != null)
                    Text(
                      'Scheduled: $scheduledLabel',
                      style: GoogleFonts.urbanist(color: Colors.black54),
                    ),
                  if (fixer != null)
                    Text(
                      'Fixer: ${_fixerName(fixer)}',
                      style: GoogleFonts.urbanist(color: Colors.black54),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: GoogleFonts.urbanist(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasDue)
              ElevatedButton(
                onPressed: onPay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1592A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Pay'),
              ),
          ],
        ),
      ),
    );
  }
}

String _fixerName(Map fixer) {
  final user = fixer['user'] is Map ? fixer['user'] as Map : null;
  final first = (user?['first_name'] ?? fixer['first_name'] ?? '')
      .toString()
      .trim();
  final last = (user?['last_name'] ?? fixer['last_name'] ?? '')
      .toString()
      .trim();
  final name = [first, last].where((s) => s.isNotEmpty).join(' ');
  return name.isEmpty
      ? (user?['username'] ?? fixer['name'] ?? 'Fixer').toString()
      : name;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String? detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.black38),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1592A),
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
    );
  }
}
