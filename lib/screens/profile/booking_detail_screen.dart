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

  const BookingDetailContent({
    super.key,
    required this.request,
    this.scrollController,
    EdgeInsets? padding,
  }) : padding = padding ?? const EdgeInsets.fromLTRB(20, 16, 20, 28);

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFFF1592A);
    final r = request;
    final service = (r['service'] is Map) ? Map<String, dynamic>.from(r['service'] as Map) : null;
    final fixer = (r['fixer'] is Map) ? Map<String, dynamic>.from(r['fixer'] as Map) : null;
    final serviceName =
        (service != null ? (service['name'] ?? service['title']) : r['service_name'] ?? 'Service').toString();
    final status = (r['status'] ?? 'pending').toString();
    final scheduled = (r['scheduled_at'] ?? r['scheduledAt'] ?? r['schedule'])?.toString();
    final location = (r['location'] ?? '').toString();
    final coupon = (r['coupon_code'] ?? r['coupon'] ?? '').toString();
    final fixerName = fixer != null
        ? (fixer['name'] ?? fixer['full_name'] ?? fixer['username'] ?? 'Unknown').toString()
        : 'Pending assignment';
    final price = _toDouble(r['price'] ?? r['amount'] ?? r['total']);
    final discount = _toDouble(r['discount'] ?? r['discount_amount']);
    final total = _toDouble(r['total'] ?? ((price ?? 0) - (discount ?? 0)));

    return SingleChildScrollView(
      controller: scrollController,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerCard(
            serviceName: serviceName,
            scheduled: scheduled,
            status: status,
            fixerName: fixerName,
            brand: brand,
          ),
          const SizedBox(height: 20),
          _infoSection(
            title: 'Booking details',
            children: [
              _infoTile(Icons.place_rounded, 'Location', location.isEmpty ? '—' : location),
              if (coupon.isNotEmpty)
                _infoTile(Icons.sell_rounded, 'Coupon', coupon.toUpperCase()),
            ],
          ),
          if (price != null) ...[
            const SizedBox(height: 20),
            _priceBreakdown(price: price, discount: discount, total: total ?? price, brand: brand),
          ],
          const SizedBox(height: 20),
          _PayNowSection(request: r, brand: brand),
        ],
      ),
    );
  }

  Widget _headerCard({
    required String serviceName,
    required String status,
    required String fixerName,
    required Color brand,
    String? scheduled,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brand, const Color(0xFFFFA26C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: brand.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style:
                          GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                    if (scheduled != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          scheduled,
                          style: GoogleFonts.urbanist(color: Colors.white.withOpacity(0.85)),
                        ),
                      ),
                  ],
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 18),
          _headerHighlight(label: 'Fixer', value: fixerName),
        ],
      ),
    );
  }

  Widget _headerHighlight({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _infoSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFFF1592A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.urbanist(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceBreakdown({
    required double price,
    double? discount,
    required double total,
    required Color brand,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Price summary', style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 14),
          _priceRow('Subtotal', price),
          if (discount != null && discount > 0)
            _priceRow('Discount', -discount, highlightColor: const Color(0xFFD32F2F)),
          const Divider(height: 24),
          _priceRow('Total due', total, isTotal: true, highlightColor: brand),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double amount,
      {bool isTotal = false, Color highlightColor = Colors.black87}) {
    return Row(
      children: [
        Text(label, style: GoogleFonts.urbanist(fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500)),
        const Spacer(),
        Text(
          '${amount >= 0 ? '' : '-'}${amount.abs().toStringAsFixed(2)}',
          style: GoogleFonts.urbanist(
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
            color: isTotal ? highlightColor : null,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final formatted = _formatStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        formatted,
        style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatStatus(String value) {
    if (value.isEmpty) return 'Pending';
    return value
        .split('_')
        .map((part) => part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
        .join(' ');
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
  final Color brand;
  const _PayNowSection({required this.request, required this.brand});
  @override
  State<_PayNowSection> createState() => _PayNowSectionState();
}

class _PayNowSectionState extends State<_PayNowSection> {
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.brand.withOpacity(0.12), widget.brand.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: widget.brand.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment', style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Amount due: K${amount.toStringAsFixed(2)}',
            style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final paid = await Navigator.of(context, rootNavigator: true).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => PaymentScreen(requestId: id),
                    fullscreenDialog: true,
                  ),
                );
                if (paid == true) {
                  _load();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Pay now'),
            ),
          ),
        ],
      ),
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
  final theme = Theme.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: Colors.black.withOpacity(0.4),
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        minChildSize: 0.55,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (sheetCtx, controller) {
          final bottom = MediaQuery.of(sheetCtx).viewInsets.bottom;
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BookingDetailContent(
              request: request,
              scrollController: controller,
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 28),
            ),
          );
        },
      );
    },
  );
}
