import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/payment_service.dart';
import '../payment_sheet.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> request;
  const BookingDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
        title: Text(
          'Booking Detail',
          style: GoogleFonts.urbanist(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: BookingDetailContent(request: request),
    );
  }
}

class BookingDetailContent extends StatelessWidget {
  final Map<String, dynamic> request;
  final ScrollController? scrollController;
  final EdgeInsets padding;
  const BookingDetailContent({super.key, required this.request, this.scrollController, EdgeInsets? padding})
      : padding = padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 24);

  @override
  Widget build(BuildContext context) {
    final r = request;
    final service = (r['service'] is Map) ? r['service'] as Map : null;
    final fixer = (r['fixer'] is Map) ? r['fixer'] as Map : null;
    final title =
        (service != null ? (service['name'] ?? service['title']) : r['service_name'] ?? 'Service').toString();
    final status = (r['status'] ?? 'pending').toString();
    final dt = (r['scheduled_at'] ?? r['scheduledAt'] ?? r['schedule'])?.toString();
    final coupon = (r['coupon_code'] ?? r['coupon'] ?? '').toString();
    final price = _toDouble(r['price'] ?? r['amount'] ?? r['total']);
    final discount = _toDouble(r['discount'] ?? r['discount_amount']);
    final total = _toDouble(r['total'] ?? ((price ?? 0) - (discount ?? 0)));

    return SingleChildScrollView(
      controller: scrollController,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.urbanist(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          if (dt != null)
            Text(
              'Scheduled: $dt',
              style: GoogleFonts.urbanist(color: Colors.black54),
            ),
          const SizedBox(height: 6),
          _chip(
            'Status: ${_formatStatus(status)}',
            _statusColor(status),
          ),
          const SizedBox(height: 16),
          if (fixer != null)
            _tile(
              'Fixer',
              (fixer['name'] ?? fixer['full_name'] ?? fixer['username'] ?? 'Unknown').toString(),
              Icons.engineering_rounded,
            ),
          if (r['location'] != null)
            _tile('Location', r['location'].toString(), Icons.place_outlined),
          if (coupon.isNotEmpty) _tile('Coupon', coupon, Icons.sell_outlined),
          const SizedBox(height: 12),
          if (price != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _row('Price', price),
                  const SizedBox(height: 6),
                  if (discount != null)
                    _row('Discount', -discount, negative: true),
                  const Divider(height: 16),
                  _row(
                    'Total',
                    total ?? (price - (discount ?? 0)),
                    highlight: true,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _PayNowSection(request: r),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, IconData icon) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: const Color(0xFFF1592A)),
        title: Text(
          label,
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(value),
      );

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, color: color),
        ),
      );

  String _formatStatus(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'accepted':
        return 'Accepted';
      case 'awaiting_payment':
        return 'Awaiting Payment';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      default:
        return s.isEmpty
            ? 'Pending'
            : s
                .split('_')
                .map((part) => part.isEmpty
                    ? part
                    : part[0].toUpperCase() + part.substring(1))
                .join(' ');
    }
  }

  Color _statusColor(String s) {
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

  Widget _row(
    String label,
    double? amount, {
    bool negative = false,
    bool highlight = false,
  }) {
    final style = GoogleFonts.urbanist(
      fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
      color: highlight ? const Color(0xFF2E7D32) : null,
    );
    final val = amount == null
        ? '-'
        : (negative
              ? '-${amount.toStringAsFixed(2)}'
              : amount.toStringAsFixed(2));
    return Row(
      children: [
        Text(label),
        const Spacer(),
        Text(val, style: style),
      ],
    );
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class _PayNowSection extends StatefulWidget {
  final Map<String, dynamic> request;
  const _PayNowSection({required this.request});
  @override
  State<_PayNowSection> createState() => _PayNowSectionState();
}

class _PayNowSectionState extends State<_PayNowSection> {
  bool _loading = false;
  Map<String, dynamic>? _payment;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = (widget.request['id'] as num?)?.toInt();
    if (id == null) return;
    final p = await PaymentService().get(id);
    if (!mounted) return;
    setState(() => _payment = p);
  }

  @override
  Widget build(BuildContext context) {
    final id = (widget.request['id'] as num?)?.toInt();
    if (id == null) return const SizedBox();
    final status = (widget.request['status'] ?? '').toString();
    if (status == 'completed') return const SizedBox();
    final amount = _toDouble(_payment?['amount']);
    final paid = ((_payment?['status'] ?? '').toString().toLowerCase() == 'paid');
    if (paid) return const SizedBox();
    if (amount == null) return const SizedBox();

    return Row(
      children: [
        Expanded(child: Text('Amount due: ${amount.toStringAsFixed(2)}')),
        ElevatedButton(
          onPressed: () async {
            final paid = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (ctx) => PaymentSheet(requestId: id),
            );
            if (paid == true) {
              _load();
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1592A), foregroundColor: Colors.white),
          child: const Text('Pay Now'),
        ),
      ],
    );
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

Future<bool?> showBookingDetailSheet(
  BuildContext context,
  Map<String, dynamic> request,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        minChildSize: 0.6,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (sheetCtx, controller) {
          final bottom = MediaQuery.of(sheetCtx).viewInsets.bottom;
          return BookingDetailContent(
            request: request,
            scrollController: controller,
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 24),
          );
        },
      );
    },
  );
}
