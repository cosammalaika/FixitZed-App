import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/screens/profile/booking_detail_screen.dart';
import 'package:fixitzed_app/services/service_request_service.dart';

class NotificationBookingDetailScreen extends StatefulWidget {
  const NotificationBookingDetailScreen({super.key});

  @override
  State<NotificationBookingDetailScreen> createState() =>
      _NotificationBookingDetailScreenState();
}

class _NotificationBookingDetailScreenState
    extends State<NotificationBookingDetailScreen> {
  final _service = ServiceRequestService();
  Map<String, dynamic>? _request;
  int? _requestId;
  bool _loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _requestId = _parseId(ModalRoute.of(context)?.settings.arguments);
    if (_requestId == null) {
      _loading = false;
      return;
    }
    _load();
  }

  int? _parseId(dynamic args) {
    if (args is Map) {
      final value = args['id'] ?? args['request_id'] ?? args['requestId'];
      return _parseId(value);
    }
    if (args is int) return args;
    if (args is num) return args.toInt();
    if (args is String) return int.tryParse(args.trim());
    return null;
  }

  Future<void> _load() async {
    final id = _requestId;
    if (id == null) return;

    setState(() => _loading = true);
    final request = await _service.getRequest(id);
    if (!mounted) return;
    setState(() {
      _request = request;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_request == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          title: Text(
            'Booking Detail',
            style: GoogleFonts.urbanist(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Unable to load this booking right now.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _requestId == null ? null : _load,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BookingDetailScreen(request: _request!);
  }
}
