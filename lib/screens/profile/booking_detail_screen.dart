import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BookingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> request;
  const BookingDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    final service = (r['service'] is Map) ? r['service'] as Map : null;
    final fixer = (r['fixer'] is Map) ? r['fixer'] as Map : null;
    String title =
        (service != null
                ? (service['name'] ?? service['title'])
                : r['service_name'] ?? 'Service')
            .toString();
    final status = (r['status'] ?? 'pending').toString();
    final dt = (r['scheduled_at'] ?? r['scheduledAt'] ?? r['schedule'])
        ?.toString();
    final coupon = (r['coupon_code'] ?? r['coupon'] ?? '').toString();
    final price = _toDouble(r['price'] ?? r['amount'] ?? r['total']);
    final discount = _toDouble(r['discount'] ?? r['discount_amount']);
    final total = _toDouble(r['total'] ?? ((price ?? 0) - (discount ?? 0)));

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
              'Status: ${status[0].toUpperCase()}${status.substring(1)}',
              _statusColor(status),
            ),
            const SizedBox(height: 16),
            if (fixer != null)
              _tile(
                'Fixer',
                (fixer['name'] ??
                        fixer['full_name'] ??
                        fixer['username'] ??
                        'Unknown')
                    .toString(),
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
          ],
        ),
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

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
      case 'accepted':
        return const Color(0xFF2E7D32);
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
