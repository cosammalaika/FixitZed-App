import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/payment_service.dart';
import '../services/coupon_service.dart';
import '../services/loyalty_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentScreen extends StatefulWidget {
  final int requestId;
  const PaymentScreen({super.key, required this.requestId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = true;
  bool _submitting = false;
  double? _amount;
  double? _originalAmount;
  double? _baseAmount;
  double _couponDiscount = 0;
  double _loyaltyDiscount = 0;
  String _method = 'cash';
  List<Map<String, dynamic>> _methods = const [];
  Map<String, dynamic>? _serviceRequest;
  final TextEditingController _couponCtrl = TextEditingController();
  Map<String, dynamic>? _couponInfo;
  bool _applyingCoupon = false;
  String? _couponCode;
  int _loyaltyBalance = 0;
  int _loyaltyThreshold = 0;
  double _pointValue = 1;
  bool _useLoyalty = false;
  int _loyaltyToUse = 0;
  String? _autoTransactionId;

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
    final payment = await PaymentService().get(widget.requestId);
    final methods = await _fetchMethods();
    final loyalty = await LoyaltyService().summary();
    if (!mounted) return;
    setState(() {
      _methods = methods;
      _amount = _toDouble(payment?['amount']);
      _originalAmount = _toDouble(payment?['original_amount']) ?? _amount;
      if (_originalAmount == null && _amount != null) {
        _originalAmount = _amount;
      }

      final storedDiscount = _toDouble(payment?['discount_amount']);
      if (storedDiscount != null &&
          storedDiscount > 0 &&
          _originalAmount != null) {
        _couponDiscount = storedDiscount.clamp(0, _originalAmount!);
        if (_amount == null) {
          _amount = (_originalAmount! - _couponDiscount).clamp(
            0,
            _originalAmount!,
          );
        }
      } else if (_originalAmount != null && _amount != null) {
        final delta = _originalAmount! - _amount!;
        _couponDiscount = delta > 0 ? delta : 0;
      } else {
        _couponDiscount = 0;
      }

      final existingMethod = (payment?['payment_method'] ?? '').toString();
      if (existingMethod.isNotEmpty &&
          _methods.any((m) => (m['code'] ?? '').toString() == existingMethod)) {
        _method = existingMethod;
      } else if (_methods.isNotEmpty) {
        _method = (_methods.first['code'] ?? 'cash').toString();
      } else {
        _method = 'cash';
      }

      _serviceRequest = (payment?['service_request'] is Map)
          ? Map<String, dynamic>.from(payment!['service_request'] as Map)
          : null;

      final coupon = (payment?['coupon'] is Map)
          ? Map<String, dynamic>.from(payment!['coupon'] as Map)
          : null;
      if (coupon != null) {
        _couponCode = coupon['code']?.toString();
        if (_couponCode != null && _couponCode!.isNotEmpty) {
          _couponCtrl.text = _couponCode!;
          _couponInfo = {
            'data': coupon,
            'message': coupon['title'] ?? 'Coupon applied',
          };
        }
      } else {
        _couponCode = null;
        if (_couponDiscount == 0) {
          _couponInfo = null;
        }
      }

      _amount ??= _originalAmount;
      _baseAmount = _amount;

      _loyaltyBalance = (loyalty?['points'] as num?)?.toInt() ?? 0;

      final rawPointValue = (loyalty?['point_value'] ??
              loyalty?['point_rate'] ??
              loyalty?['point_value_rate'])
          as num?;
      _pointValue = rawPointValue?.toDouble() ?? 0.01;
      if (_pointValue <= 0) _pointValue = 0.01;

      final rawThreshold = (loyalty?['threshold'] ??
              loyalty?['minimum_redeem_points'] ??
              loyalty?['min_points'])
          as num?;
      _loyaltyThreshold = rawThreshold?.toInt() ?? 50;
      if (_loyaltyThreshold < 0) _loyaltyThreshold = 0;

      final meetsThreshold =
          _loyaltyThreshold <= 0 || _loyaltyBalance >= _loyaltyThreshold;
      final eligible = (loyalty?['eligible'] as bool?) ?? meetsThreshold;
      _useLoyalty = eligible && meetsThreshold && _loyaltyBalance > 0;

      _loading = false;
      _autoTransactionId = null;
    });

    _recalculateLoyalty(reset: true);
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Complete Payment',
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 20, 16, bottomInset + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF1592A), Color(0xFFFFA26C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: brand.withOpacity(0.18),
                              blurRadius: 28,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
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
                                    'Review your bill',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Apply coupons or loyalty points, then settle the payment securely.',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white.withOpacity(0.92),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Amount due',
                              style: GoogleFonts.urbanist(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF2EA),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                _amount == null
                                    ? '—'
                                    : 'K${_amount!.toStringAsFixed(2)}',
                                style: GoogleFonts.urbanist(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _couponSection(),
                            const SizedBox(height: 20),
                            _loyaltySection(),
                            if ((_originalAmount ?? _baseAmount ?? _amount) !=
                                null)
                              Padding(
                                padding: const EdgeInsets.only(top: 22),
                                child: _priceSummary(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Select payment method',
                        style: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_methods.isNotEmpty
                          ? _methods.map(
                              (m) => _methodTile(
                                label:
                                    (m['name'] ?? m['code'] ?? 'Method').toString(),
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
                      const SizedBox(height: 24),
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
                                    transactionId: _ensureTransactionId(),
                                    couponCode: _couponCode,
                                    loyaltyPoints:
                                        _useLoyalty ? _loyaltyToUse : 0,
                                  );
                                  if (!mounted) return;
                                  setState(() => _submitting = false);
                                  if (!result.success) {
                                    _showSnack(
                                      message: result.message ??
                                          'Payment failed. Please try again.',
                                      success: false,
                                    );
                                    return;
                                  }

                                  if (result.data != null) {
                                    final balance =
                                        (result.data!['loyalty_points_balance']
                                                as num?)
                                            ?.toInt();
                                    if (balance != null) {
                                      setState(() {
                                        _loyaltyBalance = balance;
                                      });
                                    }
                                  }

                                  _showSnack(
                                    message: result.message ??
                                        'Payment successful',
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
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child:
                              Text(_submitting ? 'Processing…' : 'Pay now'),
                        ),
                      ),
                  ],
                ),
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
    const brand = Color(0xFFF1592A);
    const accent = Color(0xFFFFA26C);
    return InkWell(
      onTap: () => setState(() => _method = value),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [brand, accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: brand.withOpacity(0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.18)
                    : const Color(0xFFE8EDF1),
                shape: BoxShape.circle,
              ),
              child: Icon(leading, color: selected ? Colors.white : brand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.black26,
                  width: 2,
                ),
              ),
              child: selected
                  ? Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
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

  String _ensureTransactionId() {
    return _autoTransactionId ??= _generateTransactionId();
  }

  String _generateTransactionId() {
    final now = DateTime.now().toUtc();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final random = math.Random().nextInt(900000) + 100000;
    return 'APP-$timestamp-$random';
  }

  String? get _serviceId {
    final sr = _serviceRequest;
    if (sr == null) return null;
    final raw =
        sr['service_id'] ??
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
      _showSnack(
        message: 'Service details are unavailable for this booking',
        success: false,
      );
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
          _couponDiscount = 0;
          _amount = _originalAmount ?? _amount;
          _baseAmount = _amount;
          _loyaltyDiscount = 0;
          _loyaltyToUse = 0;
        });
        _showSnack(message: 'Invalid coupon', success: false);
        _recalculateLoyalty(reset: true);
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
        _couponDiscount = discount;
        _amount = total;
        _baseAmount = total;
      });
      _showSnack(message: 'Coupon applied', success: true);
      _recalculateLoyalty(reset: true);
    } finally {
      if (mounted) setState(() => _applyingCoupon = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _couponCode = null;
      _couponInfo = null;
      _couponDiscount = 0;
      _couponCtrl.clear();
      _amount = _originalAmount ?? _amount;
      _baseAmount = _amount;
      _loyaltyDiscount = 0;
      _loyaltyToUse = 0;
    });
    _showSnack(message: 'Coupon removed', success: true);
    _recalculateLoyalty(reset: true);
  }

  Map<String, dynamic> _normalizeCoupon(Map info) {
    final out = <String, dynamic>{};
    final data = (info['data'] is Map)
        ? Map<String, dynamic>.from(info['data'])
        : info;
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

  int _maxRedeemablePointsForAmount(double amount) {
    if (_pointValue <= 0) return 0;
    final points = (amount / _pointValue).floor();
    return points > 0 ? points : 0;
  }

  void _recalculateLoyalty({bool reset = false}) {
    if (!mounted) return;
    final base = _baseAmount ?? _amount;
    if (base == null) {
      setState(() {
        _useLoyalty = false;
        _loyaltyToUse = 0;
        _loyaltyDiscount = 0;
      });
      return;
    }

    final meetsThreshold =
        _loyaltyThreshold <= 0 || _loyaltyBalance >= _loyaltyThreshold;
    var useLoyalty = _useLoyalty && meetsThreshold;
    var target = useLoyalty ? _loyaltyToUse : 0;
    if (useLoyalty) {
      final maxByAmount = _maxRedeemablePointsForAmount(base);
      final cap = math.min(_loyaltyBalance, maxByAmount);
      if (reset) {
        target = cap;
      }
      if (target > cap) {
        target = cap;
      }
      if (cap <= 0) {
        useLoyalty = false;
        target = 0;
      }
    }

    final discountValue = target * _pointValue;
    final baseAmount = base;
    setState(() {
      _useLoyalty = useLoyalty;
      _loyaltyToUse = useLoyalty ? target : 0;
      _loyaltyDiscount = useLoyalty ? discountValue : 0;
      _amount = (baseAmount - (useLoyalty ? discountValue : 0)).clamp(
        0,
        baseAmount,
      );
    });
  }

  void _setLoyaltyUsage(int points) {
    _useLoyalty = points > 0;
    _loyaltyToUse = points;
    _recalculateLoyalty(reset: false);
  }

  double? _computeDiscount(double? base, Map info) {
    if (base == null) return null;
    final data = (info['data'] is Map)
        ? Map<String, dynamic>.from(info['data'])
        : info;
    final type = (data['type'] ?? data['discount_type'] ?? '')
        .toString()
        .toLowerCase();
    final percent =
        data['percent'] ?? data['percentage'] ?? data['discount_percent'];
    final fixed =
        data['amount'] ?? data['discount_amount'] ?? data['amount_off'];
    final maxCap = data['max_discount'] ?? data['max_amount'] ?? data['cap'];

    double discount = 0;
    final isPercent =
        type.contains('percent') ||
        data['is_percent'] == true ||
        data['is_percentage'] == true;

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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Remove'),
                  )
                : ElevatedButton(
                    onPressed: _applyingCoupon ? null : _applyCoupon,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1592A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                    (_normalizeCoupon(_couponInfo!)['message'] as String?) ??
                        'Coupon applied',
                    style: GoogleFonts.urbanist(color: const Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _loyaltySection() {
    final base = _baseAmount ?? _amount ?? 0;
    final maxForAmount = _maxRedeemablePointsForAmount(base);
    final meetsThreshold =
        _loyaltyThreshold <= 0 || _loyaltyBalance >= _loyaltyThreshold;
    final sliderMax = meetsThreshold
        ? math.min(_loyaltyBalance, maxForAmount)
        : 0;
    final canRedeemNow = sliderMax > 0 && base > 0;
    final currencyValue = (_loyaltyBalance * _pointValue).toStringAsFixed(2);
    final shortfall = math.max(0, _loyaltyThreshold - _loyaltyBalance);
    final minPoints = _loyaltyThreshold > 0 ? _loyaltyThreshold : 0;
    final thresholdValue = (_loyaltyThreshold > 0)
        ? (_loyaltyThreshold * _pointValue).toStringAsFixed(2)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loyalty',
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6EEEA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available: $_loyaltyBalance pts',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Worth approximately K$currencyValue',
                          style: GoogleFonts.urbanist(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '1 pt = K${_pointValue.toStringAsFixed(2)}',
                          style: GoogleFonts.urbanist(
                            color: Colors.black45,
                            fontSize: 11,
                          ),
                        ),
                        if (_loyaltyThreshold > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Redeem from $minPoints pts (K${thresholdValue ?? '0.00'})',
                              style: GoogleFonts.urbanist(
                                color: Colors.black45,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _useLoyalty && canRedeemNow,
                    onChanged: canRedeemNow
                        ? (value) {
                            setState(() {
                              _useLoyalty = value;
                            });
                            _recalculateLoyalty(reset: value);
                          }
                        : null,
                    activeColor: const Color(0xFFF1592A),
                  ),
                ],
              ),
              if (!meetsThreshold)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Earn $shortfall more points (K${(shortfall * _pointValue).toStringAsFixed(2)}) to unlock redemptions.',
                    style: GoogleFonts.urbanist(color: Colors.black54),
                  ),
                )
              else if (!canRedeemNow)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    base <= 0
                        ? 'You will be able to redeem points on the next bill.'
                        : _loyaltyBalance <= 0
                        ? 'Earn points by completing bookings to unlock rewards.'
                        : 'Insufficient points for this amount. Keep earning to redeem.',
                    style: GoogleFonts.urbanist(color: Colors.black54),
                  ),
                ),
              if (canRedeemNow) ...[
                const SizedBox(height: 12),
                Slider(
                  value: _loyaltyToUse.toDouble().clamp(
                    0,
                    sliderMax.toDouble(),
                  ),
                  min: 0,
                  max: sliderMax.toDouble(),
                  divisions: sliderMax > 0 ? sliderMax : null,
                  activeColor: const Color(0xFFF1592A),
                  label: '${_loyaltyToUse} pts',
                  onChanged: (value) {
                    setState(() {
                      _useLoyalty = value > 0;
                      _loyaltyToUse = value.round();
                    });
                    _recalculateLoyalty(reset: false);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Using ${_loyaltyToUse.toString()} pts (K${(_loyaltyDiscount).toStringAsFixed(2)})',
                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '-K${(_loyaltyDiscount).toStringAsFixed(2)}',
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFFF1592A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _priceSummary() {
    final base = _originalAmount ?? _baseAmount ?? _amount ?? 0;
    final coupon = _couponDiscount;
    final loyalty = _loyaltyDiscount;
    final total = _amount ?? (base - coupon - loyalty).clamp(0, base);
    final labelStyle = GoogleFonts.urbanist(color: Colors.black54);
    final valueStyle = GoogleFonts.urbanist(fontWeight: FontWeight.w700);

    const brand = Color(0xFFF1592A);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: brand.withOpacity(0.12)),
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
          if (coupon > 0)
            Row(
              children: [
                Text('Coupon', style: labelStyle),
                const Spacer(),
                Text(
                  '-${coupon.toStringAsFixed(2)}',
                  style: valueStyle.copyWith(color: const Color(0xFFD32F2F)),
                ),
              ],
            ),
          if (loyalty > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Text('Loyalty applied', style: labelStyle),
                  const Spacer(),
                  Text(
                    '-${loyalty.toStringAsFixed(2)}',
                    style: valueStyle.copyWith(color: const Color(0xFFF1592A)),
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          Row(
            children: [
              Text(
                'Total Due',
                style: GoogleFonts.urbanist(fontWeight: FontWeight.w800),
              ),
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

    final serviceName = (() {
      final sr = _serviceRequest;
      if (sr == null) return '';
      if (sr['service'] is Map) {
        final svc = sr['service'] as Map;
        final name = (svc['name'] ?? svc['title']).toString();
        if (name.trim().isNotEmpty) return name;
      }
      final raw = sr['service_name'] ?? sr['serviceTitle'];
      return raw?.toString() ?? '';
    })();
    final fixerName = (() {
      final sr = _serviceRequest;
      if (sr == null) return '';
      final fixer = sr['fixer'];
      if (fixer is Map) {
        final first = (fixer['first_name'] ?? fixer['firstName'] ?? '')
            .toString()
            .trim();
        final last = (fixer['last_name'] ?? fixer['lastName'] ?? '')
            .toString()
            .trim();
        final combined = [first, last].where((p) => p.isNotEmpty).join(' ');
        if (combined.isNotEmpty) return combined;
        final nested = fixer['user'];
        if (nested is Map) {
          final nf = (nested['first_name'] ?? nested['firstName'] ?? '')
              .toString()
              .trim();
          final nl = (nested['last_name'] ?? nested['lastName'] ?? '')
              .toString()
              .trim();
          final c = [nf, nl].where((p) => p.isNotEmpty).join(' ');
          if (c.isNotEmpty) return c;
          final fallback =
              (nested['name'] ?? nested['full_name'] ?? nested['username'])
                  .toString();
          if (fallback.trim().isNotEmpty) return fallback.trim();
        }
        final fallback =
            (fixer['name'] ?? fixer['full_name'] ?? fixer['username'])
                .toString();
        if (fallback.trim().isNotEmpty) return fallback.trim();
      }
      return '';
    })();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [brand, const Color(0xFFFFA26C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: brand.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.volunteer_activism_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'How was your service?',
                            style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (serviceName.isNotEmpty) serviceName,
                              if (fixerName.isNotEmpty) 'with $fixerName',
                            ].join(' '),
                            style: GoogleFonts.urbanist(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6EEEA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Overall experience',
                            style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) {
                              final idx = i + 1;
                              final filled = rating >= idx;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: InkResponse(
                                  onTap: () =>
                                      setLocal(() => rating = idx.toDouble()),
                                  radius: 30,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: filled
                                          ? brand.withOpacity(0.15)
                                          : Colors.transparent,
                                    ),
                                    child: Icon(
                                      filled
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: filled ? brand : Colors.black26,
                                      size: 36,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Share more (optional)',
                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFF1592A).withOpacity(0.2),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x112B1B10),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: ctrl,
                        maxLines: 4,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Tell us what stood out…',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: brand,
                              side: BorderSide(color: brand.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Later'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    setLocal(() => submitting = true);
                                    try {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      final token = prefs.getString(
                                        'auth_token',
                                      );
                                      final res = await http.post(
                                        Uri.parse(
                                          '${Api.baseUrl}/service-requests/${widget.requestId}/ratings',
                                        ),
                                        headers: {
                                          'Accept': 'application/json',
                                          'Content-Type': 'application/json',
                                          if (token != null)
                                            'Authorization': 'Bearer $token',
                                        },
                                        body: jsonEncode({
                                          'rating': rating,
                                          if (ctrl.text.trim().isNotEmpty)
                                            'comment': ctrl.text.trim(),
                                        }),
                                      );
                                      if (!mounted) return;
                                      Navigator.of(ctx).pop(
                                        res.statusCode >= 200 &&
                                            res.statusCode < 300,
                                      );
                                    } finally {
                                      if (mounted)
                                        setLocal(() => submitting = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brand,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              submitting ? 'Sending…' : 'Submit Review',
                            ),
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

    ctrl.dispose();

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
