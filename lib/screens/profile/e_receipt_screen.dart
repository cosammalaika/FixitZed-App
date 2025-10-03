import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/date_utils.dart';

class EReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  final Map<String, dynamic> payment;
  final bool autoShare;

  const EReceiptScreen({
    super.key,
    required this.request,
    required this.payment,
    this.autoShare = false,
  });

  @override
  State<EReceiptScreen> createState() => _EReceiptScreenState();
}

class _EReceiptScreenState extends State<EReceiptScreen> {
  final GlobalKey _captureKey = GlobalKey();
  bool _sharing = false;
  bool _downloading = false;
  bool _autoShareHandled = false;

  Map<String, dynamic> get _request => widget.request;
  Map<String, dynamic> get _payment => widget.payment;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.autoShare && !_autoShareHandled) {
      _autoShareHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _shareReceipt();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFFF1592A);
    final serviceName = _serviceName();
    final fixerName = _fixerName();

    // Parse possibly heterogeneous date inputs
    final scheduledDt =
        parseAppDate(_request['scheduled_at'] ?? _request['scheduledAt'] ?? _request['schedule']);
    final paidAtDt =
        parseAppDate(_payment['paid_at'] ?? _payment['updated_at'] ?? _payment['created_at']);

    final location = (_request['location'] ?? 'Not provided').toString();
    final transactionId = _payment['transaction_id']?.toString() ?? 'N/A';
    final method = (_payment['payment_method'] ?? 'manual').toString();
    final amount = _toCurrency(
      _payment['original_amount'] ?? _payment['amount'],
    );
    final discount = _payment['discount_amount'];
    final total = _toCurrency(_payment['amount']);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        elevation: 0,
        title: Text(
          'E-Receipt',
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            onPressed: _sharing ? null : _shareReceipt,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFFF7F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: RepaintBoundary(
                    key: _captureKey,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 24,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 60,
                                    child: Image.asset(
                                      'assets/images/logo-sm.png',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Payment Receipt',
                                    style: GoogleFonts.urbanist(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: brand,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Transaction #$transactionId',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.urbanist(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFE8ECF2),
                                  width: 1.2,
                                ),
                                color: const Color(0xFFF9FBFD),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: 70,
                                    child: CustomPaint(
                                      painter: _ReceiptBarcodePainter(
                                        transactionId,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _receiptRow('Service', serviceName),
                                  _receiptRow('Service Provider', fixerName),
                                  if (scheduledDt != null)
                                    _receiptRow(
                                      'Scheduled for',
                                      formatAppDateTime(scheduledDt),
                                    ),
                                  _receiptRow('Location', location),
                                  if (paidAtDt != null)
                                    _receiptRow(
                                      'Paid on',
                                      formatAppDateTime(paidAtDt),
                                    ),
                                  const Divider(height: 28),
                                  if (amount != null)
                                    _receiptRow('Subtotal', 'K$amount'),
                                  if (discount != null)
                                    _receiptRow(
                                      'Discount',
                                      '-K${_toCurrency(discount) ?? discount.toString()}',
                                      valueColor: Colors.redAccent,
                                    ),
                                  _receiptRow(
                                    'Total paid',
                                    total != null ? 'K$total' : '—',
                                    isBold: true,
                                    valueColor: brand,
                                  ),
                                  _receiptRow(
                                    'Payment method',
                                    _formatMethod(method),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _downloading ? null : _saveReceipt,
                      icon: _downloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(_downloading ? 'Saving…' : 'Download'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: brand.withOpacity(0.75),
                          width: 1.2,
                        ),
                        foregroundColor: brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sharing ? null : _shareReceipt,
                      icon: const Icon(Icons.share_rounded),
                      label: Text(_sharing ? 'Sharing…' : 'Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _serviceName() {
    final service = (_request['service'] is Map)
        ? Map<String, dynamic>.from(_request['service'] as Map)
        : null;
    return (service != null
            ? (service['name'] ?? service['title'])
            : _request['service_name'] ?? 'Service')
        .toString();
  }

  String _fixerName() {
    final fixer = (_request['fixer'] is Map)
        ? Map<String, dynamic>.from(_request['fixer'] as Map)
        : (_request['assigned_fixer'] is Map)
        ? Map<String, dynamic>.from(_request['assigned_fixer'] as Map)
        : null;
    return _resolveFixerNameForReceipt(
      request: _request,
      fixer: fixer,
    ).replaceAll(RegExp(r'\s+'), ' ');
  }

  Widget _receiptRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.urbanist(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.urbanist(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareReceipt() async {
    try {
      setState(() => _sharing = true);
      final bytes = await _captureReceiptBytes();
      if (bytes == null) {
        _showSnack('Unable to share receipt right now.');
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/receipt_${_request['id'] ?? 'booking'}.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([
        XFile(
          file.path,
          mimeType: 'image/png',
          name: file.uri.pathSegments.last,
        ),
      ], text: 'Receipt for ${_serviceName()} (${_request['id'] ?? ''})');
    } catch (e) {
      _showSnack('Failed to share receipt.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _saveReceipt() async {
    try {
      setState(() => _downloading = true);
      final bytes = await _captureReceiptBytes();
      if (bytes == null) {
        _showSnack('Unable to capture receipt.');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final filename =
          'FixitZed_receipt_${_request['id'] ?? 'booking'}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      _showSnack('Receipt saved to ${file.path}');
    } catch (e) {
      _showSnack('Could not save receipt.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<Uint8List?> _captureReceiptBytes() async {
    final boundary =
        _captureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.urbanist()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String? _toCurrency(dynamic value) {
    if (value == null) return null;
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

class _ReceiptBarcodePainter extends CustomPainter {
  final List<bool> bars;

  _ReceiptBarcodePainter(String seed) : bars = _generateBars(seed);

  static List<bool> _generateBars(String seed) {
    final base = seed.isEmpty
        ? DateTime.now().millisecondsSinceEpoch
        : seed.hashCode;
    final random = math.Random(base);
    return List<bool>.generate(120, (_) => random.nextBool());
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;
    final width = size.width;
    final barWidth = width / bars.length;
    for (var i = 0; i < bars.length; i++) {
      if (!bars[i]) continue;
      final rect = Rect.fromLTWH(i * barWidth, 0, barWidth * 0.7, size.height);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _resolveFixerNameForReceipt({
  required Map<String, dynamic> request,
  Map<String, dynamic>? fixer,
}) {
  String? stringValue(Object? value) {
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
    final direct = stringValue(request[key]);
    if (direct != null) return direct;
  }

  Map<String, dynamic>? explore = fixer;
  if (explore == null && request['fixer_user'] is Map) {
    explore = Map<String, dynamic>.from(request['fixer_user'] as Map);
  }

  if (explore == null) return 'Pending assignment';

  String fromMap(Map m) {
    final first = stringValue(m['first_name'] ?? m['firstName']);
    final last = stringValue(m['last_name'] ?? m['lastName']);
    if (first != null || last != null)
      return [first, last].whereType<String>().join(' ');

    for (final key in [
      'name',
      'full_name',
      'fullName',
      'display_name',
      'username',
      'company_name',
      'business_name',
    ]) {
      final candidate = stringValue(m[key]);
      if (candidate != null) return candidate;
    }
    return '';
  }

  for (final key in ['user', 'profile', 'account']) {
    if (explore![key] is Map) {
      final nested = fromMap(Map<String, dynamic>.from(explore[key] as Map));
      if (nested.isNotEmpty) return nested;
    }
  }

  final direct = fromMap(explore);
  if (direct.isNotEmpty) return direct;

  return 'Pending assignment';
}
