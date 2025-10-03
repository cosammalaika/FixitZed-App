import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/service_request_service.dart';
import '../../services/payment_service.dart';
import '../payment_sheet.dart';
import '../../core/date_utils.dart';

import 'booking_detail_screen.dart';

class MyBookingScreen extends StatefulWidget {
  const MyBookingScreen({super.key});

  @override
  State<MyBookingScreen> createState() => _MyBookingScreenState();
}

class _MyBookingScreenState extends State<MyBookingScreen>
    with WidgetsBindingObserver {
  final _req = ServiceRequestService();
  bool _loading = true;
  List<Map<String, dynamic>> _requests = const [];
  final Map<int, Map<String, dynamic>> _payments = {};
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final list = await _req.listRequests();
      final pays = <int, Map<String, dynamic>>{};
      for (final r in list) {
        final id = (r['id'] as num?)?.toInt();
        if (id == null) continue;
        try {
          final p = await PaymentService().get(id);
          if (p != null) pays[id] = p;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _requests = list;
        _payments
          ..clear()
          ..addAll(pays);
      _loading = false;
    });
  } finally {
    _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
        title: Text(
          'My Bookings',
          style: GoogleFonts.urbanist(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _requests.length,
                itemBuilder: (ctx, i) {
                  final r = _requests[i];
                  final service = (r['service'] is Map)
                      ? r['service'] as Map
                      : null;
                  final fixer = (r['fixer'] is Map) ? r['fixer'] as Map : null;
                  final title =
                      (service != null
                              ? (service['name'] ?? service['title'])
                              : r['service_name'] ?? 'Service')
                          .toString();
                  final status = (r['status'] ?? 'pending').toString();
                  final scheduledRaw =
                      r['scheduled_at'] ?? r['scheduledAt'] ?? r['schedule'];
                  final scheduledDt = parseAppDate(scheduledRaw);
                  final scheduledLabel =
                      scheduledDt != null ? formatAppDateTime(scheduledDt) : null;
                  final rid = (r['id'] as num?)?.toInt();
                  final pay = rid != null ? _payments[rid] : null;
                  final payStatus = (pay?['status'] ?? '')
                      .toString()
                      .toLowerCase();
                  final payAmount = pay?['amount'];
                  final hasDue =
                      rid != null &&
                      payAmount != null &&
                      payStatus != 'paid' &&
                      status != 'completed';
                  return InkWell(
                    onTap: () async {
                      final refresh = await showBookingDetailSheet(
                        context,
                        Map<String, dynamic>.from(r),
                      );
                      if (refresh == true) _load();
                    },
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
                                  style: GoogleFonts.urbanist(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (scheduledLabel != null)
                                  Text(
                                    'Scheduled: $scheduledLabel',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.black54,
                                    ),
                                  ),
                                if (fixer != null)
                                  Text(
                                    'Fixer: ${_fixerName(fixer)}',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          hasDue
                              ? ElevatedButton(
                                  onPressed: () async {
                                    if (rid == null) return;
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
                                    if (paid == true) _load();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF1592A),
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
                                    color: _statusBg(status),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusText(status),
                                    style: GoogleFonts.urbanist(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _statusFg(status),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'accepted':
        return const Color(0x1A2E7D32);
      case 'cancelled':
      case 'canceled':
        return const Color(0x1AD32F2F);
      case 'completed':
        return const Color(0x1A1976D2);
      case 'awaiting_payment':
        return const Color(0x1AF1592A);
      default:
        return const Color(0x1AF1592A); // pending
    }
  }

  Color _statusFg(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'accepted':
        return const Color(0xFF2E7D32);
      case 'awaiting_payment':
        return const Color(0xFFF1592A);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFD32F2F);
      case 'completed':
        return const Color(0xFF1976D2);
      default:
        return const Color(0xFFF1592A);
    }
  }

  String _statusText(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'accepted':
        return 'Accepted';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      case 'awaiting_payment':
        return 'Awaiting Payment';
      default:
        return 'Pending';
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
