import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/home_service.dart';
import '../services/service_request_service.dart';
import '../services/coupon_service.dart';
import '../services/locations_service.dart';

class BookingSheet extends StatefulWidget {
  const BookingSheet({super.key});

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  final _svc = HomeService();
  final _req = ServiceRequestService();

  List<Map<String, dynamic>> _services = const [];
  List<Map<String, dynamic>> _fixers = const [];
  String? _serviceId;
  String? _serviceName;
  String? _fixerId;
  DateTime? _scheduledAt;
  bool _submitting = false;
  final _locationCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _couponCtrl = TextEditingController();
  Map<String, dynamic>? _couponInfo;
  double? _servicePrice;
  double? _discountValue;
  String? _fixerNameSelected;
  List<Map<String, dynamic>> _savedLocations = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  InputDecoration _fieldDecoration({
    required String label,
    Widget? icon,
    String? hint,
    String? helper,
  }) {
    final ctx = context;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      filled: true,
      fillColor: Theme.of(ctx).colorScheme.surfaceVariant.withOpacity(0.18),
      prefixIcon: icon,
      labelStyle: TextStyle(color: Theme.of(ctx).hintColor),
      hintStyle: TextStyle(color: Theme.of(ctx).hintColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(ctx).dividerColor, width: 1),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(ctx).dividerColor, width: 1),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFF1592A), width: 1.2),
      ),
    );
  }

  Future<void> _load() async {
    final servicesRaw = await _svc.fetchServices();
    final fixersRaw = await _svc.fetchAllFixers();
    final locsRaw = await LocationsService().list();
    final services = servicesRaw
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
    final fixers = fixersRaw
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
    if (!mounted) return;
    setState(() {
      _services = services;
      _fixers = fixers;
      _savedLocations = locsRaw;
    });
  }

  List<Map<String, dynamic>> get _filteredFixers {
    if (_serviceId == null) return _fixers;
    bool fixerOffers(Map f, String sid) {
      final services = f['services'] ?? f['skills'] ?? f['offerings'];
      if (services is List) {
        for (final s in services) {
          if (s is Map) {
            final id = (s['id'] ?? s['uuid'] ?? s['service_id'] ?? '')
                .toString();
            if (id == sid) return true;
          } else if (s is String) {
            if (s == sid) return true;
          }
        }
      }
      return false;
    }

    return _fixers.where((f) => fixerOffers(f, _serviceId!)).toList();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: now,
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => _scheduledAt = dt);
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      _showSnack(
        message: 'Please complete all required fields',
        success: false,
      );
      return;
    }
    setState(() => _submitting = true);
    final ok = await _req.createRequest(
      serviceId: _serviceId!,
      fixerId: _fixerId, // optional per backend
      scheduledAt: _scheduledAt!,
      location: _locationCtrl.text.trim(),
      status: 'pending',
      couponCode: _couponCtrl.text.trim().isEmpty
          ? null
          : _couponCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop(true);
      _showSnack(
        message: 'Booking submitted — pending approval',
        success: true,
      );
    } else {
      _showSnack(message: 'Failed to submit booking', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 12,
        ),
        child: Form(
          key: _formKey,
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
                  const Icon(
                    Icons.event_available_rounded,
                    color: Color(0xFFF1592A),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Book a Service',
                    style: GoogleFonts.urbanist(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FormField<String>(
                      validator: (_) =>
                          (_serviceId == null || _serviceId!.isEmpty)
                          ? 'Please select a service'
                          : null,
                      builder: (state) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _pickService,
                            child: InputDecorator(
                              decoration: _fieldDecoration(
                                label: 'Service',
                                icon: const Icon(Icons.handyman_outlined),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _serviceName ?? 'Select a service',
                                      style: GoogleFonts.urbanist(),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.search_rounded,
                                    color: Colors.black45,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (state.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                state.errorText!,
                                style: GoogleFonts.urbanist(
                                  color: const Color(0xFFD32F2F),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FormField<String>(
                      validator: (_) => (_fixerId == null || _fixerId!.isEmpty)
                          ? 'Please select a fixer'
                          : null,
                      builder: (state) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _serviceId == null ? null : _pickFixer,
                            child: InputDecorator(
                              decoration: _fieldDecoration(
                                label: 'Fixer',
                                icon: const Icon(Icons.engineering_outlined),
                                helper: _serviceId == null
                                    ? 'Select a service to see available fixers'
                                    : (_filteredFixers.isEmpty
                                          ? 'No fixers found for this service'
                                          : '${_filteredFixers.length} available'),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _fixerNameSelected ??
                                          'Any available fixer',
                                      style: GoogleFonts.urbanist(),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.search_rounded,
                                    color: Colors.black45,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (state.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                state.errorText!,
                                style: GoogleFonts.urbanist(
                                  color: Color(0xFFD32F2F),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_serviceId != null && _filteredFixers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x1AD32F2F),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x33D32F2F)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.report_gmailerrorred_rounded,
                                color: Color(0xFFD32F2F),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No available fixer for the selected service right now. You can still book and we\'ll assign one when available.',
                                  style: GoogleFonts.urbanist(
                                    color: Color(0xFFB00020),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _locationCtrl,
                            decoration: _fieldDecoration(
                              label: 'Location',
                              hint: 'e.g., Plot 123, Kabwata, Lusaka',
                              icon: const Icon(Icons.place_outlined),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Location is required'
                                : null,
                          ),
                        ),
                        if (_savedLocations.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _pickSavedLocation,
                            icon: const Icon(Icons.location_on_outlined),
                            label: const Text('Saved'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _couponCtrl,
                            decoration: _fieldDecoration(
                              label: 'Coupon code',
                              hint: 'Enter code',
                              icon: const Icon(Icons.sell_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _applyCoupon,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1592A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                    if (_couponInfo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _couponInfo!['message']?.toString() ??
                                    'Coupon applied',
                                style: GoogleFonts.urbanist(
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_couponCtrl.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.black45,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tap Apply to validate your code',
                                style: GoogleFonts.urbanist(
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_servicePrice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: _priceSummary(),
                      ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickDateTime,
                      child: InputDecorator(
                        decoration: _fieldDecoration(
                          label: 'Scheduled At',
                          icon: const Icon(Icons.access_time),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _scheduledAt == null
                                    ? 'Pick date & time'
                                    : _formatDateTime(_scheduledAt!),
                                style: GoogleFonts.urbanist(),
                              ),
                            ),
                            const Icon(
                              Icons.edit_calendar_outlined,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_scheduledAt == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Choose when you want the service',
                          style: GoogleFonts.urbanist(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(_submitting ? 'Booking…' : 'Book Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1592A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fixerName(Map f) {
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
                  '')
              .toString()
              .trim();
      return name.isNotEmpty ? name : 'Fixer';
    }

    if (f['user'] is Map) {
      final u = Map<String, dynamic>.from(f['user'] as Map);
      final nm = fromMap(u);
      if (nm != 'Fixer') return nm;
    }
    return fromMap(f);
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day  $hh:$mm';
  }

  void _showSnack({required String message, required bool success}) {
    final theme = Theme.of(context);
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

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) {
      _showSnack(message: 'Enter a coupon code', success: false);
      return;
    }
    if (_serviceId == null) {
      _showSnack(message: 'Select a service first', success: false);
      return;
    }
    try {
      final svc = _services.firstWhere(
        (s) => (s['id'] ?? s['uuid']).toString() == _serviceId,
      );
      _servicePrice = _parsePrice(svc);
    } catch (_) {
      _servicePrice = null;
    }

    final validate = await CouponService().validate(
      code,
      serviceId: _serviceId,
    );
    if (validate == null) {
      if (!mounted) return;
      setState(() {
        _couponInfo = null;
        _discountValue = null;
      });
      _showSnack(message: 'Invalid coupon', success: false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _couponInfo = validate;
      final norm = _normalizeCoupon(validate);
      if (norm['discount'] is num) {
        _discountValue = (norm['discount'] as num).toDouble();
      } else {
        _discountValue = _computeDiscount(_servicePrice, validate);
      }
      if (norm['price'] is num) {
        _servicePrice = (norm['price'] as num).toDouble();
      }
    });
    _showSnack(message: 'Coupon applied', success: true);
  }

  double? _parsePrice(Map s) {
    final v = s['price'] ?? s['amount'] ?? s['cost'] ?? s['rate'];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Map<String, dynamic> _normalizeCoupon(Map info) {
    final out = <String, dynamic>{};
    final m = (info['data'] is Map) ? Map<String, dynamic>.from(info['data']) : info;
    for (final k in ['total', 'final_total', 'finalAmount', 'final_amount']) {
      if (m[k] is num) out['total'] = (m[k] as num).toDouble();
    }
    for (final k in ['price', 'amount_before', 'subtotal', 'price_before']) {
      if (m[k] is num) out['price'] = (m[k] as num).toDouble();
    }
    for (final k in ['discount', 'discount_amount', 'amount_off']) {
      if (m[k] is num) out['discount'] = (m[k] as num).toDouble();
    }
    if (m['message'] != null) out['message'] = m['message'].toString();
    return out;
  }

  double? _computeDiscount(double? base, Map info) {
    if (base == null) return null;
    final m = (info['data'] is Map) ? Map<String, dynamic>.from(info['data']) : info;
    final type = (m['type'] ?? m['discount_type'] ?? '').toString().toLowerCase();
    final isPercent = type.contains('percent') || m['is_percent'] == true || m['is_percentage'] == true;
    final percent = m['percent'] ?? m['percentage'] ?? m['discount_percent'];
    final fixed = m['amount'] ?? m['discount_amount'] ?? m['amount_off'];
    final maxCap = m['max_discount'] ?? m['max_amount'] ?? m['cap'];
    double d = 0;
    if (isPercent && percent is num) {
      d = base * (percent.toDouble() / 100.0);
    } else if (fixed is num) {
      d = fixed.toDouble();
    } else if (percent is num) {
      d = base * (percent.toDouble() / 100.0);
    }
    if (maxCap is num) d = d.clamp(0, maxCap.toDouble());
    return d.clamp(0, base);
  }

  Widget _priceSummary() {
    final base = _servicePrice ?? 0;
    final disc = _discountValue ?? 0;
    // Prefer server-provided total when present
    double total = (base - disc).clamp(0, double.infinity);
    if (_couponInfo != null) {
      final norm = _normalizeCoupon(_couponInfo!);
      if (norm['total'] is num) total = (norm['total'] as num).toDouble();
    }
    TextStyle label = GoogleFonts.urbanist(color: Colors.black54);
    TextStyle value = GoogleFonts.urbanist(fontWeight: FontWeight.w700);
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
              Text('Price', style: label),
              const Spacer(),
              Text(base.toStringAsFixed(2), style: value),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Discount', style: label),
              const Spacer(),
              Text(
                '-${disc.toStringAsFixed(2)}',
                style: value.copyWith(color: const Color(0xFFD32F2F)),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Text(
                'Total',
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

  Future<void> _pickService() async {
    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final queryCtrl = TextEditingController();
        List<Map<String, dynamic>> filtered = List.of(_services);
        void applyFilter(String q) {
          final qq = q.trim().toLowerCase();
          filtered = _services.where((s) {
            final name = (s['name'] ?? s['title'] ?? 'Service')
                .toString()
                .toLowerCase();
            final desc = (s['description'] ?? s['summary'] ?? '')
                .toString()
                .toLowerCase();
            return name.contains(qq) || desc.contains(qq);
          }).toList();
        }

        return StatefulBuilder(
          builder: (ctx, setSt) => SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 12,
              ),
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
                  Text(
                    'Choose Service',
                    style: GoogleFonts.urbanist(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: queryCtrl,
                    autofocus: true,
                    decoration: _fieldDecoration(
                      label: 'Search services',
                      icon: const Icon(Icons.search_rounded),
                      hint: 'Type to filter…',
                    ),
                    onChanged: (v) => setSt(() {
                      applyFilter(v);
                    }),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                'No services match your search',
                                style: GoogleFonts.urbanist(
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final s = filtered[i];
                              final id = (s['id'] ?? s['uuid'] ?? '$i')
                                  .toString();
                              final name =
                                  (s['name'] ?? s['title'] ?? 'Service')
                                      .toString();
                              final desc =
                                  (s['description'] ?? s['summary'] ?? '')
                                      .toString();
                              return ListTile(
                                leading: const Icon(
                                  Icons.handyman_outlined,
                                  color: Color(0xFFF1592A),
                                ),
                                title: Text(
                                  name,
                                  style: GoogleFonts.urbanist(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: desc.isNotEmpty
                                    ? Text(
                                        desc,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                onTap: () => Navigator.of(
                                  ctx,
                                ).pop({'id': id, 'name': name}),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected != null) {
      setState(() {
        _serviceId = selected['id'];
        _serviceName = selected['name'];
        _fixerId = null;
      });
    }
  }

  Future<void> _pickFixer() async {
    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final queryCtrl = TextEditingController();
        List<Map<String, dynamic>> filtered = List.of(_filteredFixers);
        void applyFilter(String q) {
          final qq = q.trim().toLowerCase();
          filtered = _filteredFixers.where((f) {
            final nm = _fixerName(f).toLowerCase();
            final svc = (f['services'] ?? f['skills'] ?? '')
                .toString()
                .toLowerCase();
            return nm.contains(qq) || svc.contains(qq);
          }).toList();
        }

        return StatefulBuilder(
          builder: (ctx, setSt) => SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 12,
              ),
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
                  Text(
                    'Choose Fixer',
                    style: GoogleFonts.urbanist(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: queryCtrl,
                    autofocus: true,
                    decoration: _fieldDecoration(
                      label: 'Search fixers',
                      icon: const Icon(Icons.search_rounded),
                      hint: 'Type to filter…',
                    ),
                    onChanged: (v) => setSt(() {
                      applyFilter(v);
                    }),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                'No fixers match your search',
                                style: GoogleFonts.urbanist(
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final f = filtered[i];
                              final id =
                                  (f['id'] ?? f['user_id'] ?? f['uuid'] ?? '$i')
                                      .toString();
                              final name = _fixerName(f);
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Color(0xFFF1592A),
                                  child: Icon(
                                    Icons.engineering_rounded,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: GoogleFonts.urbanist(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onTap: () => Navigator.of(
                                  ctx,
                                ).pop({'id': id, 'name': name}),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected != null) {
      setState(() {
        _fixerId = selected['id'];
        _fixerNameSelected = selected['name'];
      });
    }
  }

  Future<void> _pickSavedLocation() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
              Text(
                'Saved Addresses',
                style: GoogleFonts.urbanist(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _savedLocations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final m = _savedLocations[i];
                    final line =
                        (m['address'] ?? m['line1'] ?? m['label'] ?? 'Address')
                            .toString();
                    final city = (m['city'] ?? '').toString();
                    final detail = [
                      line,
                      city,
                    ].where((e) => e.isNotEmpty).join(', ');
                    return ListTile(
                      leading: const Icon(
                        Icons.place_outlined,
                        color: Color(0xFFF1592A),
                      ),
                      title: Text(
                        line,
                        style: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: city.isNotEmpty ? Text(city) : null,
                      onTap: () => Navigator.of(ctx).pop(detail),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() => _locationCtrl.text = selected);
    }
  }
}
