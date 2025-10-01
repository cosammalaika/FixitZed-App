import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/payment_service.dart';
import '../services/coupon_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentSheet extends StatefulWidget {
  final int requestId;
  const PaymentSheet({super.key, required this.requestId});

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  bool _loading = true;
  bool _submitting = false;
  double? _amount;
  double? _originalAmount;
  double? _discountValue;
  String _method = 'cash';
  List<Map<String, dynamic>> _methods = const [];
  Map<String, dynamic>? _serviceRequest;
  final TextEditingController _couponCtrl = TextEditingController();
  Map<String, dynamic>? _couponInfo;
  bool _applyingCoupon = false;
  String? _couponCode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await PaymentService().get(widget.requestId);
    final methods = await _fetchMethods();
    if (!mounted) return;
    setState(() {
      _methods = methods;
      _amount = _toDouble(p?['amount']);
      _originalAmount = _toDouble(p?['original_amount']) ?? _amount;
      if (_originalAmount == null && _amount != null) {
        _originalAmount = _amount;
      }

      final storedDiscount = _toDouble(p?['discount_amount']);
      if (storedDiscount != null && storedDiscount > 0 && _originalAmount != null) {
        _discountValue = storedDiscount.clamp(0, _originalAmount!);
        if (_amount == null) {
          _amount = (_originalAmount! - _discountValue!).clamp(0, _originalAmount!);
        }
      } else if (_originalAmount != null && _amount != null) {
        final delta = _originalAmount! - _amount!;
        _discountValue = delta > 0 ? delta : 0;
      } else {
        _discountValue = 0;
      }

      final existingMethod = (p?['payment_method'] ?? '').toString();
      if (existingMethod.isNotEmpty && _methods.any((m) => (m['code'] ?? '').toString() == existingMethod)) {
        _method = existingMethod;
      } else if (_methods.isNotEmpty) {
        _method = (_methods.first['code'] ?? 'cash').toString();
      } else {
        _method = 'cash';
      }

      _serviceRequest = (p?['service_request'] is Map)
          ? Map<String, dynamic>.from(p!['service_request'] as Map)
          : null;

      final coupon = (p?['coupon'] is Map) ? Map<String, dynamic>.from(p!['coupon'] as Map) : null;
      if (coupon != null) {
        _couponCode = coupon['code']?.toString();
        if (_couponCode != null && _couponCode!.isNotEmpty) {
          _couponCtrl.text = _couponCode!;
          _couponInfo = {'data': coupon, 'message': coupon['title'] ?? 'Coupon applied'};
        }
      } else {
        _couponCode = null;
        if ((_discountValue ?? 0) == 0) {
          _couponInfo = null;
        }
      }

      _amount ??= _originalAmount;

      _loading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchMethods() async {
    try {
      final res = await http.get(
        Uri.parse('${Api.baseUrl}/payment-methods'),
        headers: {'Accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['data'] is List) {
          return (body['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        if (body is List)
          return body
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      }
    } catch (_) {}
    // Fallback to basic set
    return [
      {'name': 'Cash', 'code': 'cash'},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFFF1592A);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 12,
        ),
        child: _loading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.payment_rounded,
                        color: Color(0xFFF1592A),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Complete Payment',
                        style: GoogleFonts.urbanist(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Amount',
                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _amount == null ? '-' : _amount!.toStringAsFixed(2),
                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _couponSection(),
                  if ((_originalAmount ?? _amount) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14.0),
                      child: _priceSummary(),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Payment Method',
                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...(_methods.isNotEmpty
                      ? _methods.map(
                          (m) => _methodTile(
                            label: (m['name'] ?? m['code'] ?? 'Method')
                                .toString(),
                            value: (m['code'] ?? 'cash').toString(),
                            leading: Icons.payments_rounded,
                          ),
                        )
                      : [
                          _methodTile(
                            label: 'Cash',
                            value: 'cash',
                            leading: Icons.payments_rounded,
                          ),
                        ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_amount == null || _submitting)
                          ? null
                      : () async {
                              setState(() => _submitting = true);
                              final result = await PaymentService().pay(
                                requestId: widget.requestId,
                                amount: _amount!,
                                originalAmount: _originalAmount,
                                method: _method,
                                couponCode: _couponCode,
                              );
                              if (!mounted) return;
                              setState(() => _submitting = false);
                              if (!result.success) {
                                _showSnack(
                                  message: result.message ?? 'Payment failed. Please try again.',
                                  success: false,
                                );
                                return;
                              }

                              _showSnack(
                                message: result.message ?? 'Payment successful',
                                success: true,
                              );

                              await _promptRating();
                              if (!mounted) return;
                              Navigator.of(context).pop(true);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_submitting ? 'Processing…' : 'Pay Now'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _methodTile({
    required String label,
    required String value,
    required IconData leading,
  }) {
    final selected = _method == value;
    return InkWell(
      onTap: () => setState(() => _method = value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFF1592A) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(leading, color: const Color(0xFFF1592A)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFFF1592A) : Colors.black26,
                  width: 2,
                ),
              ),
              child: selected
                  ? Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1592A),
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String? get _serviceId {
    final sr = _serviceRequest;
    if (sr == null) return null;
    final raw = sr['service_id'] ??
        (sr['service'] is Map ? (sr['service'] as Map)['id'] : null);
    if (raw == null) return null;
    return raw.toString();
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) {
      _showSnack(message: 'Enter a coupon code', success: false);
      return;
    }
    final serviceId = _serviceId;
    if (serviceId == null) {
      _showSnack(message: 'Service details are unavailable for this booking', success: false);
      return;
    }
    if ((_originalAmount ?? _amount) == null) {
      _showSnack(message: 'Bill amount is missing', success: false);
      return;
    }

    setState(() => _applyingCoupon = true);
    try {
      final info = await CouponService().validate(code, serviceId: serviceId);
      if (info == null) {
        if (!mounted) return;
        setState(() {
          _couponInfo = null;
          _couponCode = null;
          _discountValue = 0;
          _amount = _originalAmount ?? _amount;
        });
        _showSnack(message: 'Invalid coupon', success: false);
        return;
      }

      final base = _originalAmount ?? _amount ?? 0;
      if (_originalAmount == null && base > 0) {
        _originalAmount = base;
      }
      var discount = _computeDiscount(_originalAmount, info) ?? 0;
      final norm = _normalizeCoupon(info);
      if (norm['discount'] is num) {
        discount = (norm['discount'] as num).toDouble();
      }
      double total;
      if (norm['total'] is num) {
        total = (norm['total'] as num).toDouble();
      } else {
        final baseline = _originalAmount ?? base;
        total = (baseline - discount).clamp(0, baseline);
      }

      if (!mounted) return;
      setState(() {
        _couponInfo = info;
        _couponCode = code;
        _discountValue = discount;
        _amount = total;
      });
      _showSnack(message: 'Coupon applied', success: true);
    } finally {
      if (mounted) setState(() => _applyingCoupon = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _couponCode = null;
      _couponInfo = null;
      _discountValue = 0;
      _couponCtrl.clear();
      _amount = _originalAmount ?? _amount;
    });
    _showSnack(message: 'Coupon removed', success: true);
  }

  Map<String, dynamic> _normalizeCoupon(Map info) {
    final out = <String, dynamic>{};
    final data = (info['data'] is Map) ? Map<String, dynamic>.from(info['data']) : info;
    for (final key in ['total', 'final_total', 'finalAmount', 'final_amount']) {
      if (data[key] is num) out['total'] = (data[key] as num).toDouble();
    }
    for (final key in ['price', 'amount_before', 'subtotal', 'price_before']) {
      if (data[key] is num) out['price'] = (data[key] as num).toDouble();
    }
    for (final key in ['discount', 'discount_amount', 'amount_off']) {
      if (data[key] is num) out['discount'] = (data[key] as num).toDouble();
    }
    if (data['message'] != null) out['message'] = data['message'].toString();
    return out;
  }

  double? _computeDiscount(double? base, Map info) {
    if (base == null) return null;
    final data = (info['data'] is Map) ? Map<String, dynamic>.from(info['data']) : info;
    final type = (data['type'] ?? data['discount_type'] ?? '').toString().toLowerCase();
    final percent = data['percent'] ?? data['percentage'] ?? data['discount_percent'];
    final fixed = data['amount'] ?? data['discount_amount'] ?? data['amount_off'];
    final maxCap = data['max_discount'] ?? data['max_amount'] ?? data['cap'];

    double discount = 0;
    final isPercent = type.contains('percent') || data['is_percent'] == true || data['is_percentage'] == true;

    if (isPercent && percent is num) {
      discount = base * (percent.toDouble() / 100);
    } else if (fixed is num) {
      discount = fixed.toDouble();
    } else if (percent is num) {
      discount = base * (percent.toDouble() / 100);
    }

    if (maxCap is num) {
      discount = discount.clamp(0, maxCap.toDouble());
    }

    return discount.clamp(0, base);
  }

  Widget _couponSection() {
    final applied = _couponCode != null && _couponCode!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coupon',
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _couponCtrl,
                enabled: !applied && !_applyingCoupon,
                decoration: InputDecoration(
                  hintText: 'Enter coupon code',
                  filled: true,
                  fillColor: const Color(0xFFF3F5F7),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            applied
                ? OutlinedButton(
                    onPressed: _removeCoupon,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Remove'),
                  )
                : ElevatedButton(
                    onPressed: _applyingCoupon ? null : _applyCoupon,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1592A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_applyingCoupon ? 'Applying…' : 'Apply'),
                  ),
          ],
        ),
        if (_couponInfo != null && applied)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x1A2E7D32),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (_normalizeCoupon(_couponInfo!)['message'] as String?) ?? 'Coupon applied',
                    style: GoogleFonts.urbanist(color: const Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _priceSummary() {
    final base = _originalAmount ?? _amount ?? 0;
    final discount = _discountValue ?? 0;
    final total = _amount ?? (base - discount).clamp(0, base);
    final labelStyle = GoogleFonts.urbanist(color: Colors.black54);
    final valueStyle = GoogleFonts.urbanist(fontWeight: FontWeight.w700);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Subtotal', style: labelStyle),
              const Spacer(),
              Text(base.toStringAsFixed(2), style: valueStyle),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Discount', style: labelStyle),
              const Spacer(),
              Text(
                '-${discount.toStringAsFixed(2)}',
                style: valueStyle.copyWith(color: const Color(0xFFD32F2F)),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Text('Total Due', style: GoogleFonts.urbanist(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                total.toStringAsFixed(2),
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _promptRating() async {
    final brand = const Color(0xFFF1592A);
    double rating = 5;
    final ctrl = TextEditingController();
    bool submitting = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF1592A)),
                        const SizedBox(width: 8),
                        Text(
                          'Rate your Fixer',
                          style: GoogleFonts.urbanist(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'How was the service?',
                      style: GoogleFonts.urbanist(color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(5, (i) {
                        final idx = i + 1;
                        final filled = rating >= idx;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: InkResponse(
                            onTap: () => setLocal(() => rating = idx.toDouble()),
                            radius: 22,
                            child: Icon(
                              filled ? Icons.star_rounded : Icons.star_border_rounded,
                              color: filled ? brand : Colors.grey.shade400,
                              size: 32,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F5F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: TextField(
                        controller: ctrl,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: 'Leave a comment (optional)',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting ? null : () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Skip'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    setLocal(() => submitting = true);
                                    try {
                                      final prefs = await SharedPreferences.getInstance();
                                      final token = prefs.getString('auth_token');
                                      final res = await http.post(
                                        Uri.parse('${Api.baseUrl}/service-requests/${widget.requestId}/ratings'),
                                        headers: {
                                          'Accept': 'application/json',
                                          'Content-Type': 'application/json',
                                          if (token != null) 'Authorization': 'Bearer $token',
                                        },
                                        body: jsonEncode({
                                          'rating': rating,
                                          if (ctrl.text.trim().isNotEmpty) 'comment': ctrl.text.trim(),
                                        }),
                                      );
                                      if (!mounted) return;
                                      if (res.statusCode >= 200 && res.statusCode < 300) {
                                        Navigator.of(ctx).pop(true);
                                      } else {
                                        Navigator.of(ctx).pop(false);
                                      }
                                    } finally {
                                      if (mounted) setLocal(() => submitting = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brand,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(submitting ? 'Submitting…' : 'Submit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (ok == true) {
      _showSnack(message: 'Thanks for your rating!', success: true);
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  void _showSnack({required String message, required bool success}) {
    final color = success ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
    final icon = success ? Icons.check_circle_rounded : Icons.error_rounded;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.urbanist(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
