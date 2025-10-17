import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/home_service.dart';
import '../services/local_notification_service.dart';
import '../services/service_request_service.dart';
import '../services/locations_service.dart';

class BookingSheet extends StatefulWidget {
  final Map<String, dynamic>? initialService;
  const BookingSheet({super.key, this.initialService});

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  final _svc = HomeService();
  final _req = ServiceRequestService();

  List<Map<String, dynamic>> _services = const [];
  String? _serviceId;
  String? _serviceName;
  bool _submitting = false;
  final _locationCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _savedLocations = const [];
  double? _locationLat;
  double? _locationLng;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialService;
    if (init != null) {
      _serviceId = _extractServiceId(init);
      _serviceName = _extractServiceName(init);
    }
    _load();
  }

  InputDecoration _fieldDecoration({
    required String label,
    Widget? icon,
    String? hint,
    String? helper,
  }) {
    final ctx = context;
    final scheme = Theme.of(ctx).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.18),
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
    final locsRaw = await LocationsService().list();
    final services = servicesRaw
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
    if (!mounted) return;
    setState(() {
      _services = services;
      _savedLocations = locsRaw;
      if (_serviceId != null) {
        final match = _services.firstWhere(
          (s) => _extractServiceId(s) == _serviceId,
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          _serviceName = _extractServiceName(match);
        }
      }
    });
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1592A), Color(0xFFFF9155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF1592A).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book a service',
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick what you need, choose a fixer and lock in the visit without leaving the app.',
                      style: GoogleFonts.urbanist(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_serviceName != null)
                _heroChip(Icons.handyman_outlined, _serviceName!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x1AF1592A),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFF1592A)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _selectTile({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
    String? helper,
  }) {
    final enabled = onTap != null;
    final textColor = enabled ? Colors.black87 : Colors.black45;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF3ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? const Color(0xFFF6C2A6) : const Color(0xFFE5E5E5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 20, color: const Color(0xFFF1592A)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.urbanist(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9C531D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: GoogleFonts.urbanist(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  enabled ? Icons.chevron_right_rounded : Icons.lock_outline,
                  color: enabled ? const Color(0xFFF1592A) : Colors.black26,
                ),
              ],
            ),
            if (helper != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  helper,
                  style: GoogleFonts.urbanist(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoBanner({
    required IconData icon,
    required String message,
    required Color background,
    Color? foreground,
  }) {
    final fg = foreground ?? const Color(0xFFF1592A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: background.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.urbanist(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _extractServiceId(Map<dynamic, dynamic> s) {
    final id = s['id'] ?? s['uuid'] ?? s['service_id'];
    if (id == null) return null;
    if (id is num) return id.toInt().toString();
    return id.toString();
  }

  String _extractServiceName(Map<dynamic, dynamic> s) {
    return (s['name'] ?? s['title'] ?? 'Service').toString();
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
    if (_serviceId == null || _serviceId!.isEmpty) {
      _showSnack(
        message: 'Pick the service you need before requesting',
        success: false,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final scheduledAt = DateTime.now();
    setState(() => _submitting = true);
    final ok = await _req.createRequest(
      serviceId: _serviceId!,
      scheduledAt: scheduledAt,
      location: _locationCtrl.text.trim(),
      locationLat: _locationLat,
      locationLng: _locationLng,
      status: 'pending',
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      LocalNotificationService.instance.notifyBookingCreated(
        serviceName: _serviceName ?? 'Service request',
        scheduledAt: scheduledAt,
        location: _locationCtrl.text.trim(),
      );
      Navigator.of(context).pop(true);
      _showSnack(
        message: 'Request submitted — pending approval',
        success: true,
      );
    } else {
      _showSnack(message: 'Failed to submit request', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFFFF7F2)),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 16),
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
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
                  _buildHeroHeader(),
                  const SizedBox(height: 16),
                  _sectionCard(
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'Service details',
                    children: [
                      FormField<String>(
                        validator: (_) =>
                            (_serviceId == null || _serviceId!.isEmpty)
                            ? 'Please select a service'
                            : null,
                        builder: (state) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _selectTile(
                              label: 'Service',
                              value: _serviceName ?? 'Select a service',
                              icon: Icons.handyman_outlined,
                              onTap: _pickService,
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
                      const SizedBox(height: 14),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sectionCard(
                    icon: Icons.place_outlined,
                    title: 'Location & schedule',
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _locationCtrl,
                            decoration: _fieldDecoration(
                              label: 'Service location',
                              hint: 'e.g., Plot 123, Kabwata, Lusaka',
                              icon: const Icon(Icons.location_on_outlined),
                            ),
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (_locationLat != null || _locationLng != null) {
                                _locationLat = null;
                                _locationLng = null;
                              }
                            },
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Location is required'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              SizedBox(
                                height: 36,
                                child: OutlinedButton.icon(
                                  onPressed: _locating
                                      ? null
                                      : _useCurrentLocation,
                                  icon: _locating
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.my_location_rounded,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _locating ? 'Locating…' : 'Use current',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    foregroundColor: const Color(0xFFF1592A),
                                    side: const BorderSide(
                                      color: Color(0xFFF1592A),
                                    ),
                                    textStyle: GoogleFonts.urbanist(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              if (_savedLocations.isNotEmpty)
                                SizedBox(
                                  height: 36,
                                  child: OutlinedButton.icon(
                                    onPressed: _pickSavedLocation,
                                    icon: const Icon(
                                      Icons.maps_home_work_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Saved'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      foregroundColor: const Color(0xFFF1592A),
                                      side: const BorderSide(
                                        color: Color(0xFFF1592A),
                                      ),
                                      textStyle: GoogleFonts.urbanist(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _infoBanner(
                    icon: Icons.local_offer_outlined,
                    message:
                        'Coupons and loyalty points can be applied once your fixer shares a bill.',
                    background: const Color(0x1AF1592A),
                    foreground: Colors.black87,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    if (!mounted) return;
    if (selected != null) {
      setState(() {
        _serviceId = selected['id'];
        _serviceName = selected['name'];
      });
    }
  }

  Future<void> _pickSavedLocation() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
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
                      onTap: () => Navigator.of(ctx).pop({
                        'label': detail,
                        'latitude': m['latitude'],
                        'longitude': m['longitude'],
                      }),
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
      final label = (selected['label'] ?? '').toString();
      final latRaw = selected['latitude'];
      final lngRaw = selected['longitude'];
      double? toDouble(dynamic value) {
        if (value == null) return null;
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value);
        return null;
      }

      setState(() {
        _locationCtrl.text = label;
        _locationLat = toDouble(latRaw);
        _locationLng = toDouble(lngRaw);
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showSnack(
          message: 'Turn on location services to use current location',
          success: false,
        );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack(message: 'Location permission denied', success: false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String formatted =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts =
              [p.street, p.subLocality, p.locality, p.administrativeArea]
                  .where((e) => e != null && e!.trim().isNotEmpty)
                  .map((e) => e!.trim());
          final str = parts.join(', ');
          if (str.isNotEmpty) formatted = str;
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _locationCtrl.text = formatted;
        _locationLat = position.latitude;
        _locationLng = position.longitude;
      });
    } catch (_) {
      if (!mounted) return;
      _showSnack(message: 'Could not fetch current location', success: false);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }
}
