import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/core/booking_cancellation.dart';
import 'package:fixitzed_app/services/payment_service.dart';
import 'package:fixitzed_app/services/service_request_service.dart';
import 'package:fixitzed_app/screens/payment_sheet.dart';
import 'package:fixitzed_app/core/date_utils.dart';
import 'package:fixitzed_app/screens/profile/e_receipt_screen.dart';
import 'package:fixitzed_app/utils/phone_formatter.dart';
import 'package:url_launcher/url_launcher.dart';

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
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          'Booking Detail',
          style: GoogleFonts.urbanist(
            color: theme.colorScheme.onSurface,
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

class BookingDetailContent extends StatefulWidget {
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
  State<BookingDetailContent> createState() => _BookingDetailContentState();
}

class _BookingDetailContentState extends State<BookingDetailContent> {
  late Map<String, dynamic> _requestData;
  Map<String, dynamic>? _payment;
  bool _paymentLoading = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _requestData = Map<String, dynamic>.from(widget.request);
    _loadPayment();
  }

  @override
  void didUpdateWidget(covariant BookingDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.request, widget.request)) {
      _requestData = Map<String, dynamic>.from(widget.request);
      _loadPayment();
    }
  }

  bool _canCancelBooking({required String status}) {
    return isCustomerCancelableBookingStatus(status);
  }

  bool _hasFixerAssigned(
    Map<String, dynamic> request,
    Map<String, dynamic>? fixer,
  ) {
    if (fixer != null && fixer.isNotEmpty) return true;
    for (final key in const [
      'fixer_id',
      'fixerId',
      'assigned_fixer_id',
      'assignedFixerId',
    ]) {
      final value = request[key];
      if (value is num && value > 0) return true;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty && trimmed != '0') return true;
      }
    }
    return false;
  }

  Widget _buildPendingActions({
    required BuildContext context,
    required Color brand,
    required bool hasFixer,
  }) {
    final colors = Theme.of(context).fx;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.surface, colors.surfaceTint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: brand.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need to cancel?',
            style: GoogleFonts.urbanist(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: brand,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFixer
                ? 'The assigned fixer will be notified once you cancel this booking.'
                : 'Cancel this request before it moves further in the booking process.',
            style: GoogleFonts.urbanist(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _cancelling ? null : () => _cancelBooking(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.danger,
                side: BorderSide(color: colors.danger, width: 1.1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _cancelling
                    ? const SizedBox(
                        key: ValueKey('cancel-progress'),
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Cancel booking',
                        key: ValueKey('cancel-label'),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(BuildContext context) async {
    final id = (_requestData['id'] as num?)?.toInt();
    if (id == null) return;

    final result = await showModalBottomSheet<CancelRequestResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CancelBookingSheet(
        onSubmit: (reasonKey, note) async {
          if (mounted) {
            setState(() => _cancelling = true);
          }
          final response = await ServiceRequestService().cancelRequest(
            id,
            reasonKey: reasonKey,
            note: note,
          );
          if (mounted) {
            setState(() => _cancelling = false);
          }
          return response;
        },
      ),
    );

    if (!mounted || result == null || !result.success) return;

    final updatedRequest = result.request;
    if (updatedRequest != null && updatedRequest.isNotEmpty) {
      setState(() {
        _requestData = {..._requestData, ...updatedRequest};
      });
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _loadPayment() async {
    final id = (_requestData['id'] as num?)?.toInt();
    if (id == null) return;
    setState(() => _paymentLoading = true);
    final payment = await PaymentService().get(id);
    if (!mounted) return;
    setState(() {
      _payment = payment;
      _paymentLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).fx.brand;
    final r = _requestData;
    final service = (r['service'] is Map)
        ? Map<String, dynamic>.from(r['service'] as Map)
        : null;
    final fixer = (r['fixer'] is Map)
        ? Map<String, dynamic>.from(r['fixer'] as Map)
        : (r['assigned_fixer'] is Map)
        ? Map<String, dynamic>.from(r['assigned_fixer'] as Map)
        : null;
    final serviceName =
        (service != null
                ? (service['name'] ?? service['title'])
                : r['service_name'] ?? 'Service')
            .toString();
    final status = (r['status'] ?? 'pending').toString();
    final scheduledDt = parseAppDate(
      r['scheduled_at'] ?? r['scheduledAt'] ?? r['schedule'],
    );
    final scheduled = scheduledDt != null
        ? formatAppDateTime(scheduledDt)
        : null;
    final location = (r['location'] ?? '').toString();
    final coupon = (r['coupon_code'] ?? r['coupon'] ?? '').toString();
    final hasFixer = _hasFixerAssigned(r, fixer);
    final displayStatus = _effectiveStatus(status, hasFixer);
    final fixerName = _resolveFixerName(request: r, fixer: fixer);
    final fixerContact = hasFixer
        ? _resolveFixerContact(request: r, fixer: fixer)
        : null;
    final fixerContactDisplay = fixerContact == null
        ? null
        : formatZambianNumberForDisplay(fixerContact);
    final price = _toDouble(r['price'] ?? r['amount'] ?? r['total']);
    final discount = _toDouble(r['discount'] ?? r['discount_amount']);
    final total = _toDouble(r['total'] ?? ((price ?? 0) - (discount ?? 0)));
    final canCancel = _canCancelBooking(status: status);
    final isCancelled = isCancelledBookingStatus(status);

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerCard(
            serviceName: serviceName,
            scheduled: scheduled,
            status: displayStatus,
            fixerName: fixerName,
            brand: brand,
          ),
          const SizedBox(height: 20),
          _infoSection(
            title: 'Booking details',
            children: [
              _infoTile(
                Icons.place_rounded,
                'Location',
                location.isEmpty ? '—' : location,
              ),
              if (fixerContact != null)
                _infoTile(
                  Icons.phone_rounded,
                  'Fixer contact',
                  fixerContactDisplay ?? fixerContact,
                  trailing: TextButton.icon(
                    onPressed: () => _callNumber(fixerContact),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call'),
                  ),
                ),
              if (coupon.isNotEmpty)
                _infoTile(Icons.sell_rounded, 'Coupon', coupon.toUpperCase()),
            ],
          ),
          if (isCancelled) ...[
            const SizedBox(height: 20),
            _buildCancellationDetails(),
          ],
          if (price != null) ...[
            const SizedBox(height: 20),
            _priceBreakdown(
              price: price,
              discount: discount,
              total: total ?? price,
              brand: brand,
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: 20),
            _buildPendingActions(
              context: context,
              brand: brand,
              hasFixer: hasFixer,
            ),
          ],
          const SizedBox(height: 20),
          _buildPaymentAction(context: context, brand: brand, status: status),
        ],
      ),
    );
  }

  Widget _buildPaymentAction({
    required BuildContext context,
    required Color brand,
    required String status,
  }) {
    final id = (_requestData['id'] as num?)?.toInt();
    if (id == null) return const SizedBox();

    if (_paymentLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final amount = _toDouble(_payment?['amount']);
    final paymentStatus = (_payment?['status'] ?? '').toString().toLowerCase();
    final isPaid = paymentStatus == 'paid';
    final statusLower = status.toLowerCase();

    if (statusLower == 'completed' && isPaid) {
      return _ReceiptActions(
        request: _requestData,
        payment: _payment!,
        brand: brand,
      );
    }

    if (isPaid ||
        amount == null ||
        statusLower == 'completed' ||
        isCancelledBookingStatus(statusLower)) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            brand.withValues(alpha: 0.12),
            brand.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: brand.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment',
            style: GoogleFonts.urbanist(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Amount due: K${amount.toStringAsFixed(2)}',
            style: GoogleFonts.urbanist(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final paid = await Navigator.of(context, rootNavigator: true)
                    .push<bool>(
                      MaterialPageRoute(
                        builder: (_) => PaymentScreen(requestId: id),
                        fullscreenDialog: true,
                      ),
                    );
                if (paid == true) {
                  await _loadPayment();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Pay now'),
            ),
          ),
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
            color: brand.withValues(alpha: 0.2),
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
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.handyman_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    if (scheduled != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          scheduled,
                          style: GoogleFonts.urbanist(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
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
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection({required String title, required List<Widget> children}) {
    final colors = Theme.of(context).fx;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.urbanist(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoTile(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    final colors = Theme.of(context).fx;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.urbanist(
                    color: colors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing],
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
    final colors = Theme.of(context).fx;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price summary',
            style: GoogleFonts.urbanist(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _priceRow('Subtotal', price),
          if (discount != null && discount > 0)
            _priceRow('Discount', -discount, highlightColor: colors.danger),
          const Divider(height: 24),
          _priceRow('Total due', total, isTotal: true, highlightColor: brand),
        ],
      ),
    );
  }

  Widget _priceRow(
    String label,
    double amount, {
    bool isTotal = false,
    Color? highlightColor,
  }) {
    final colors = Theme.of(context).fx;
    final effectiveHighlight = highlightColor ?? colors.textPrimary;
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.urbanist(
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          '${amount >= 0 ? '' : '-'}${amount.abs().toStringAsFixed(2)}',
          style: GoogleFonts.urbanist(
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
            color: isTotal ? effectiveHighlight : colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _callNumber(String number) async {
    final normalized = normalizeZambianNumber(number);
    final uri = Uri.parse('tel:$normalized');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to start call')));
  }

  String _normalizeStatusKey(String value) {
    return normalizeBookingStatusKey(value);
  }

  String _effectiveStatus(String status, bool hasFixer) {
    final normalized = _normalizeStatusKey(status);
    if (normalized == 'pending' && hasFixer) return 'accepted';
    return normalized;
  }

  Widget _buildCancellationDetails() {
    final canceledBy = formatCancellationActor(
      _requestData['canceled_by']?.toString(),
    );
    final reason = (_requestData['cancellation_reason_label'] ?? '')
        .toString()
        .trim();
    final note = (_requestData['cancellation_note'] ?? '').toString().trim();
    final canceledAt = parseAppDate(_requestData['canceled_at']);

    return _infoSection(
      title: 'Cancellation details',
      children: [
        _infoTile(Icons.person_off_rounded, 'Canceled by', canceledBy),
        _infoTile(
          Icons.rule_folder_rounded,
          'Reason',
          reason.isEmpty ? '—' : reason,
        ),
        if (note.isNotEmpty)
          _infoTile(Icons.notes_rounded, 'Additional note', note),
        _infoTile(
          Icons.event_busy_rounded,
          'Canceled at',
          canceledAt == null ? '—' : formatAppDateTime(canceledAt),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final formatted = _formatStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        formatted,
        style: GoogleFonts.urbanist(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatStatus(String value) {
    if (value.isEmpty) return 'Pending';
    return value
        .split('_')
        .map(
          (part) =>
              part.isEmpty ? part : part[0].toUpperCase() + part.substring(1),
        )
        .join(' ');
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class _ReceiptActions extends StatelessWidget {
  final Map<String, dynamic> request;
  final Map<String, dynamic> payment;
  final Color brand;

  const _ReceiptActions({
    required this.request,
    required this.payment,
    required this.brand,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).fx;
    final amount = _toCurrency(payment['amount']);
    final method = (payment['payment_method'] ?? 'manual').toString();
    final paidAtRaw =
        payment['paid_at'] ?? payment['updated_at'] ?? payment['created_at'];
    final paidAtDt = parseAppDate(paidAtRaw);
    final paidAt = paidAtDt != null
        ? formatAppDateTime(paidAtDt)
        : paidAtRaw?.toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            brand.withValues(alpha: 0.18),
            brand.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: brand.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(Icons.receipt_long_rounded, color: brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment confirmed',
                      style: GoogleFonts.urbanist(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: brand,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amount != null
                          ? 'K$amount · ${_formatMethod(method)}'
                          : _formatMethod(method),
                      style: GoogleFonts.urbanist(color: colors.textPrimary),
                    ),
                    if (paidAt != null)
                      Text(
                        paidAt,
                        style: GoogleFonts.urbanist(
                          color: colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final isStacked = maxWidth < 420;
              final buttonWidth = isStacked ? maxWidth : (maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: buttonWidth,
                    child: ElevatedButton.icon(
                      onPressed: () => _openReceipt(context, autoShare: false),
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('View E-Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: buttonWidth,
                    child: OutlinedButton.icon(
                      onPressed: () => _openReceipt(context, autoShare: true),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Share / Download'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: brand,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        side: BorderSide(
                          color: brand.withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _openReceipt(BuildContext context, {required bool autoShare}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => EReceiptScreen(
          request: request,
          payment: payment,
          autoShare: autoShare,
        ),
      ),
    );
  }

  static String? _toCurrency(dynamic value) {
    if (value is num) return value.toStringAsFixed(2);
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed.toStringAsFixed(2);
    }
    return null;
  }

  String _formatMethod(String method) {
    if (method.isEmpty) return 'Manual';
    return method
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}

class _CancelBookingSheet extends StatefulWidget {
  const _CancelBookingSheet({required this.onSubmit});

  final Future<CancelRequestResult> Function(String reasonKey, String? note)
  onSubmit;

  @override
  State<_CancelBookingSheet> createState() => _CancelBookingSheetState();
}

class _CancelBookingSheetState extends State<_CancelBookingSheet> {
  final TextEditingController _noteController = TextEditingController();
  String? _selectedKey;
  String? _errorText;
  bool _submitting = false;

  bool get _isOtherSelected => _selectedKey == 'other';

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final selectedKey = _selectedKey;
    final trimmedNote = _noteController.text.trim();

    if (selectedKey == null) {
      setState(() => _errorText = 'Select a cancellation reason to continue.');
      return;
    }

    if (selectedKey == 'other' && trimmedNote.isEmpty) {
      setState(() => _errorText = 'Please specify why you are cancelling.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final result = await widget.onSubmit(
      selectedKey,
      _isOtherSelected ? trimmedNote : null,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop(result);
      return;
    }

    setState(() {
      _submitting = false;
      _errorText = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).fx;
    final brand = colors.brand;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.surfaceRaised, colors.surface],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Cancel booking',
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceTint,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: brand.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_active_rounded,
                            color: brand,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'The assigned fixer will be notified.',
                            style: GoogleFonts.urbanist(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Why are you cancelling?',
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...bookingCancellationReasons.map((option) {
                    final selected = option.key == _selectedKey;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: _submitting
                            ? null
                            : () {
                                setState(() {
                                  _selectedKey = option.key;
                                  _errorText = null;
                                });
                              },
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selected
                                ? brand.withValues(alpha: 0.08)
                                : colors.surfaceRaised,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected ? brand : colors.border,
                              width: selected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: selected ? brand : colors.textMuted,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option.label,
                                  style: GoogleFonts.urbanist(
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: !_isOtherSelected
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Please specify',
                                  style: GoogleFonts.urbanist(
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _noteController,
                                  enabled: !_submitting,
                                  maxLines: 3,
                                  minLines: 2,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    hintText: 'Add a short note',
                                    filled: true,
                                    fillColor: colors.surfaceRaised,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorText!,
                      style: GoogleFonts.urbanist(
                        color: colors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Keep booking'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _submitting ? 'Cancelling…' : 'Cancel booking',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _resolveFixerName({
  required Map<String, dynamic> request,
  Map<String, dynamic>? fixer,
}) {
  String? _stringValue(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  for (final key in [
    'fixer_name',
    'assigned_fixer_name',
    'fixerDisplayName',
    'fixer_display_name',
  ]) {
    final direct = _stringValue(request[key]);
    if (direct != null) return direct;
  }

  var explore = fixer;
  if (explore == null && request['fixer_user'] is Map) {
    explore = Map<String, dynamic>.from(request['fixer_user'] as Map);
  }

  final resolvedExplore = explore;
  if (resolvedExplore == null) {
    return 'Pending assignment';
  }

  String fromMap(Map m) {
    final first = _stringValue(m['first_name'] ?? m['firstName']);
    final last = _stringValue(m['last_name'] ?? m['lastName']);
    if (first != null || last != null) {
      return [first, last].whereType<String>().join(' ');
    }

    for (final key in [
      'name',
      'full_name',
      'fullName',
      'display_name',
      'username',
      'company_name',
      'business_name',
    ]) {
      final candidate = _stringValue(m[key]);
      if (candidate != null) return candidate;
    }
    return '';
  }

  for (final key in ['user', 'profile', 'account']) {
    if (resolvedExplore[key] is Map) {
      final nested = fromMap(
        Map<String, dynamic>.from(resolvedExplore[key] as Map),
      );
      if (nested.isNotEmpty) return nested;
    }
  }

  final direct = fromMap(resolvedExplore);
  if (direct.isNotEmpty) return direct;

  return 'Pending assignment';
}

String? _resolveFixerContact({
  required Map<String, dynamic> request,
  Map<String, dynamic>? fixer,
}) {
  String? pick(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  for (final key in [
    'fixer_contact',
    'assigned_fixer_contact',
    'fixerContact',
    'fixer_phone',
    'contact',
  ]) {
    final direct = pick(request[key]);
    if (direct != null) return direct;
  }

  Map<String, dynamic>? explore = fixer;
  if (explore == null && request['fixer_user'] is Map) {
    explore = Map<String, dynamic>.from(request['fixer_user'] as Map);
  } else if (explore == null && request['fixer'] is Map) {
    explore = Map<String, dynamic>.from(request['fixer'] as Map);
  }

  String? fromMap(Map m) {
    for (final key in [
      'contact_number',
      'phone_number',
      'mobile_number',
      'primary_phone',
      'phone',
      'mobile',
      'telephone',
      'contact',
    ]) {
      final value = pick(m[key]);
      if (value != null) return value;
    }
    return null;
  }

  String? exploreMap(Map<String, dynamic> map) {
    final direct = fromMap(map);
    if (direct != null) return direct;
    for (final key in ['user', 'profile', 'account']) {
      if (map[key] is Map) {
        final nested = exploreMap(Map<String, dynamic>.from(map[key] as Map));
        if (nested != null) return nested;
      }
    }
    return null;
  }

  if (explore != null) {
    final resolved = exploreMap(explore);
    if (resolved != null) return resolved;
  }

  for (final key in ['fixers', 'assignments', 'accepted_fixers']) {
    final list = request[key];
    if (list is! List) continue;
    for (final raw in list.whereType<Map>()) {
      final resolved = exploreMap(Map<String, dynamic>.from(raw));
      if (resolved != null) return resolved;
    }
  }

  return null;
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
    barrierColor: Colors.black.withValues(alpha: 0.4),
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
