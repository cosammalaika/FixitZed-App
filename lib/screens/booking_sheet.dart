import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/services/home_service.dart';
import 'package:fixitzed_app/services/local_notification_service.dart';
import 'package:fixitzed_app/services/service_request_service.dart';
import 'package:fixitzed_app/services/locations_service.dart';

class _ActiveFixerServiceSet {
  const _ActiveFixerServiceSet({
    required this.ids,
    required this.names,
    required this.slugs,
  });

  final Set<String> ids;
  final Set<String> names;
  final Set<String> slugs;

  static const _ActiveFixerServiceSet empty = _ActiveFixerServiceSet(
    ids: <String>{},
    names: <String>{},
    slugs: <String>{},
  );

  bool get isEmpty => ids.isEmpty && names.isEmpty && slugs.isEmpty;
}

class BookingSheet extends StatefulWidget {
  final Map<String, dynamic>? initialService;
  const BookingSheet({super.key, this.initialService});

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  static const Set<String> _activeFixerStatusTokens = {
    'active',
    'approved',
    'available',
    'online',
    'enabled',
    'verified',
    'live',
    'current',
  };

  static const Set<String> _inactiveFixerStatusTokens = {
    'inactive',
    'disabled',
    'suspended',
    'blocked',
    'pending',
    'unavailable',
    'offline',
    'archived',
    'deactivated',
    'draft',
    'rejected',
  };

  final _svc = HomeService();
  final _req = ServiceRequestService();

  static const _lastLocationLabelKey = 'booking:last_location_label';
  static const _lastLocationLatKey = 'booking:last_location_lat';
  static const _lastLocationLngKey = 'booking:last_location_lng';

  List<Map<String, dynamic>> _services = const <Map<String, dynamic>>[];
  String? _serviceId;
  String? _serviceName;
  bool _submitting = false;
  final _locationCtrl = TextEditingController();
  final _customServiceCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _savedLocations = const <Map<String, dynamic>>[];
  double? _locationLat;
  double? _locationLng;
  bool _locating = false;
  Future<void>? _initialLoad;

  bool get _requiresCustomService {
    final id = _serviceId?.trim();
    if (id != null && id.isNotEmpty) {
      if (id == '1401') return true;
      final parsedId = int.tryParse(id);
      if (parsedId != null && parsedId == 1401) return true;
    }
    final name = _serviceName?.toLowerCase() ?? '';
    return name.contains('other') && name.contains('specify');
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initialService;
    if (init != null) {
      _serviceId = _extractServiceId(init);
      _serviceName = _extractServiceName(init);
    }
    _initialLoad = _load();
    _restoreLastLocation().then((_) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((__) {
          if (mounted && _locationCtrl.text.trim().isEmpty) {
            _prefillLocation();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _customServiceCtrl.dispose();
    super.dispose();
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
    final servicesFuture = _svc.fetchServices();
    final fixersFuture = _svc.fetchAllFixers();
    final locationsFuture = LocationsService().list();

    List<dynamic> servicesRaw = const [];
    List<dynamic> fixersRaw = const [];
    List<Map<String, dynamic>> locsRaw = const <Map<String, dynamic>>[];

    try {
      servicesRaw = await servicesFuture;
    } catch (_) {
      servicesRaw = const [];
    }
    try {
      fixersRaw = await fixersFuture;
    } catch (_) {
      fixersRaw = const [];
    }
    try {
      locsRaw = await locationsFuture;
    } catch (_) {
      locsRaw = const <Map<String, dynamic>>[];
    }

    final services = servicesRaw
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
    final filtered = _filterServicesByActiveFixers(services, fixersRaw);
    if (!mounted) return;
    setState(() {
      _services = filtered;
      _savedLocations = locsRaw;
      if (_serviceId != null) {
        Map<String, dynamic>? found;
        for (final service in _services) {
          if (_extractServiceId(service) == _serviceId) {
            found = service;
            break;
          }
        }
        if (found != null) {
          _serviceName = _extractServiceName(found);
        } else {
          _serviceId = null;
          _serviceName = null;
        }
      }
    });
    _initialLoad = null;
  }

  Future<void> _ensureServicesLoaded() async {
    _initialLoad ??= _load();
    try {
      await _initialLoad;
    } catch (_) {
      _initialLoad = null;
    }
  }

  Future<void> _prefillLocation() async {
    if (_locationCtrl.text.trim().isNotEmpty) return;
    final success = await _useCurrentLocation(
      showFeedback: false,
      showIndicator: false,
    );
    if (!success && mounted) {
      _showSnack(
        message:
            'Could not fetch your current location automatically. You can tap “Use current” or enter it manually.',
        success: false,
      );
    }
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
                      'Request a service',
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
        border: Border.all(color: background.withValues(alpha: 0.6)),
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

  List<Map<String, dynamic>> _filterServicesByActiveFixers(
    List<Map<String, dynamic>> services,
    List<dynamic> fixersRaw,
  ) {
    if (services.isEmpty) return services;
    final active = _collectActiveFixerServices(fixersRaw);
    if (active.isEmpty) return services;

    bool matches(Map<String, dynamic> service) {
      final id = _extractServiceId(service);
      if (id != null && active.ids.contains(id)) {
        return true;
      }

      for (final candidate in <String>{
        _normalizeSlugToken(service['slug']),
        _normalizeSlugToken(service['service_slug']),
        _normalizeSlugToken(service['serviceCode']),
      }) {
        if (candidate.isNotEmpty && active.slugs.contains(candidate)) {
          return true;
        }
      }

      for (final name in _serviceNameCandidates(service)) {
        final normalized = _normalizeServiceNameToken(name);
        if (normalized.isNotEmpty && active.names.contains(normalized)) {
          return true;
        }
      }
      return false;
    }

    final filtered = <Map<String, dynamic>>[];
    for (final service in services) {
      if (matches(service)) {
        filtered.add(service);
      }
    }
    return filtered.isEmpty ? services : filtered;
  }

  _ActiveFixerServiceSet _collectActiveFixerServices(List<dynamic> fixersRaw) {
    if (fixersRaw.isEmpty) return _ActiveFixerServiceSet.empty;

    final ids = <String>{};
    final names = <String>{};
    final slugs = <String>{};
    final seenFixerMaps = <int>{};
    final seenServiceMaps = <int>{};

    void addId(dynamic value) {
      if (value == null) return;
      if (value is num) {
        ids.add(value.toInt().toString());
      } else if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;
        if (RegExp(r'^\d+$').hasMatch(trimmed)) {
          ids.add(trimmed);
        }
      }
    }

    void addName(dynamic value) {
      if (value == null) return;
      if (value is String) {
        final segments = value
            .split(RegExp(r'[,&/;|]+'))
            .map((e) => e.trim())
            .where((element) => element.isNotEmpty);
        for (final segment in segments) {
          final normalized = _normalizeServiceNameToken(segment);
          if (normalized.isNotEmpty) names.add(normalized);
          final slug = _normalizeSlugToken(segment);
          if (slug.isNotEmpty) slugs.add(slug);
        }
      }
    }

    void addSlug(dynamic value) {
      final normalized = _normalizeSlugToken(value);
      if (normalized.isNotEmpty) slugs.add(normalized);
    }

    void collectService(dynamic raw) {
      if (raw == null) return;
      if (raw is Map) {
        final id = identityHashCode(raw);
        if (!seenServiceMaps.add(id)) return;
        addId(
          raw['service_id'] ??
              raw['serviceId'] ??
              raw['id'] ??
              raw['service_id_fk'],
        );
        addSlug(
          raw['slug'] ?? raw['service_slug'] ?? raw['slug_name'] ?? raw['code'],
        );
        addName(raw['name']);
        addName(raw['title']);
        addName(raw['label']);
        addName(raw['service_name']);
        addName(raw['display_name']);
        collectService(raw['service']);
        collectService(raw['pivot']);
        for (final entry in raw.entries) {
          final key = entry.key.toString().toLowerCase();
          if (key.contains('service') ||
              key.contains('skill') ||
              key.contains('tag') ||
              key.contains('category')) {
            collectService(entry.value);
          }
        }
      } else if (raw is Iterable) {
        for (final item in raw) {
          collectService(item);
        }
      } else if (raw is num) {
        addId(raw);
      } else if (raw is String) {
        addName(raw);
      }
    }

    void collectFixer(Map<dynamic, dynamic> fixer) {
      final id = identityHashCode(fixer);
      if (!seenFixerMaps.add(id)) return;
      if (!_isFixerActive(fixer)) return;

      collectService(fixer['services']);
      collectService(fixer['service_names']);
      collectService(fixer['service_list']);
      collectService(fixer['serviceIds']);
      collectService(fixer['service_ids']);
      collectService(fixer['service_ids_array']);
      collectService(fixer['skills']);
      collectService(fixer['skill_names']);
      collectService(fixer['tags']);
      collectService(fixer['categories']);
      collectService(fixer['specialities']);

      for (final key in const [
        'fixer',
        'user',
        'profile',
        'fixer_profile',
        'owner',
        'details',
        'metadata',
        'meta',
      ]) {
        final nested = fixer[key];
        if (nested is Map) {
          collectFixer(nested);
        } else if (nested is Iterable) {
          for (final item in nested) {
            if (item is Map) collectFixer(item);
          }
        }
      }
    }

    for (final raw in fixersRaw) {
      if (raw is Map) {
        collectFixer(raw);
      }
    }

    if (ids.isEmpty && names.isEmpty && slugs.isEmpty) {
      return _ActiveFixerServiceSet.empty;
    }
    return _ActiveFixerServiceSet(ids: ids, names: names, slugs: slugs);
  }

  bool _isFixerActive(Map<dynamic, dynamic> fixer) {
    bool? parseBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) return null;
        if (_activeFixerStatusTokens.contains(normalized) ||
            normalized == 'true' ||
            normalized == '1' ||
            normalized == 'yes') {
          return true;
        }
        if (_inactiveFixerStatusTokens.contains(normalized) ||
            normalized == 'false' ||
            normalized == '0' ||
            normalized == 'no') {
          return false;
        }
      }
      return null;
    }

    final direct =
        parseBool(fixer['is_active']) ??
        parseBool(fixer['active']) ??
        parseBool(fixer['isActive']) ??
        parseBool(fixer['available']) ??
        parseBool(fixer['availability']) ??
        parseBool(fixer['status']) ??
        parseBool(fixer['state']);

    if (direct != null) {
      return direct;
    }

    for (final key in const [
      'status',
      'state',
      'availability',
      'availability_status',
      'fixer_status',
    ]) {
      final value = fixer[key];
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        if (_inactiveFixerStatusTokens.contains(normalized)) {
          return false;
        }
        if (_activeFixerStatusTokens.contains(normalized)) {
          return true;
        }
      }
    }
    return true;
  }

  Iterable<String> _serviceNameCandidates(Map<dynamic, dynamic> service) sync* {
    for (final value in [
      service['name'],
      service['title'],
      service['label'],
      service['service_name'],
      service['display_name'],
      service['short_name'],
    ]) {
      if (value is String && value.trim().isNotEmpty) {
        yield value;
      }
    }
    final subcategory = service['subcategory'];
    if (subcategory is Map) {
      final subName = subcategory['name'] ?? subcategory['title'];
      if (subName is String && subName.trim().isNotEmpty) {
        yield subName;
      }
    }
    final subName2 = service['subcategory_name'] ?? service['subcategoryName'];
    if (subName2 is String && subName2.trim().isNotEmpty) {
      yield subName2;
    }
    final category = service['category'];
    if (category is Map) {
      final categoryName = category['name'] ?? category['title'];
      if (categoryName is String && categoryName.trim().isNotEmpty) {
        yield categoryName;
      }
    }
  }

  String _normalizeServiceNameToken(dynamic value) {
    if (value == null) return '';
    final lower = value.toString().trim().toLowerCase();
    if (lower.isEmpty) return '';
    return lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeSlugToken(dynamic value) {
    if (value == null) return '';
    final lower = value.toString().trim().toLowerCase();
    if (lower.isEmpty) return '';
    final cleaned = lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return cleaned;
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
    final customNote = _requiresCustomService
        ? _customServiceCtrl.text.trim()
        : null;
    setState(() => _submitting = true);
    final result = await _req.createRequest(
      serviceId: _serviceId!,
      scheduledAt: scheduledAt,
      location: _locationCtrl.text.trim(),
      locationLat: _locationLat,
      locationLng: _locationLng,
      customerNote: (customNote != null && customNote.isNotEmpty)
          ? customNote
          : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.success) {
      await LocalNotificationService.instance.notifyBookingCreated(
        serviceName: _serviceName ?? 'Service request',
        scheduledAt: scheduledAt,
        location: _locationCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      _showSnack(
        message: 'Request submitted — pending approval',
        success: true,
      );
    } else {
      _showSnack(
        message: result.message ?? 'Failed to submit request',
        success: false,
      );
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
                      if (_requiresCustomService)
                        TextFormField(
                          controller: _customServiceCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 4,
                          minLines: 3,
                          decoration: _fieldDecoration(
                            label: 'Describe the service',
                            hint:
                                'Share a few details so we can match the right fixer',
                          ),
                          validator: (value) {
                            if (!_requiresCustomService) return null;
                            if (value == null || value.trim().isEmpty) {
                              return 'Please tell us what you need done';
                            }
                            return null;
                          },
                        ),
                      if (_requiresCustomService) const SizedBox(height: 14),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sectionCard(
                    icon: Icons.place_outlined,
                    title: 'Location',
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _locationCtrl,
                            decoration:
                                _fieldDecoration(
                                  label: 'Service location',
                                  hint: 'e.g., Plot 123, Kabwata, Lusaka',
                                  icon: const Icon(Icons.location_on_outlined),
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      Icons.my_location_rounded,
                                      color: _locating
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.outline
                                          : const Color(0xFFF1592A),
                                    ),
                                    onPressed: _locating
                                        ? null
                                        : () async {
                                            await _useCurrentLocation();
                                          },
                                  ),
                                ),
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (_locationLat != null ||
                                  _locationLng != null) {
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
                                      : () async {
                                          await _useCurrentLocation();
                                        },
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
                      label: Text(_submitting ? 'Requesting…' : 'Request Now'),
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
    Future<void>? loader;
    if (_services.isEmpty && mounted) {
      loader = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    await _ensureServicesLoaded();

    if (loader != null && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await loader;
    }

    if (!mounted) return;
    if (_services.isEmpty) {
      _showSnack(
        message: 'Services are still syncing. Please try again in a moment.',
        success: false,
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final queryCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (ctx, setSt) {
            List<Map<String, dynamic>> filteredServices() {
              final query = queryCtrl.text.trim().toLowerCase();
              if (query.isEmpty)
                return List<Map<String, dynamic>>.of(_services);
              return _services
                  .where((s) {
                    final name = (s['name'] ?? s['title'] ?? 'Service')
                        .toString()
                        .toLowerCase();
                    final desc = (s['description'] ?? s['summary'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(query) || desc.contains(query);
                  })
                  .map((s) => Map<String, dynamic>.from(s))
                  .toList();
            }

            final filtered = filteredServices();

            return SafeArea(
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
                      onChanged: (_) => setSt(() {}),
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
            );
          },
        );
      },
    );
    if (!mounted) return;
    if (selected != null) {
      setState(() {
        _serviceId = selected['id'];
        _serviceName = selected['name'];
        if (!_requiresCustomService) {
          _customServiceCtrl.clear();
        }
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
        final cleaned = _cleanLocationLabel(label);
        _locationCtrl.text = cleaned;
        _locationLat = toDouble(latRaw);
        _locationLng = toDouble(lngRaw);
      });
      unawaited(
        _cacheLocation(_locationCtrl.text.trim(), _locationLat, _locationLng),
      );
    }
  }

  Future<bool> _useCurrentLocation({
    bool showFeedback = true,
    bool showIndicator = true,
  }) async {
    if (showIndicator && mounted) {
      setState(() => _locating = true);
    }
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (showFeedback) {
          _showSnack(
            message: 'Turn on location services to use current location',
            success: false,
          );
        }
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (showFeedback) {
          _showSnack(message: 'Location permission denied', success: false);
        }
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      var formatted =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final rawParts = [
            p.street,
            p.subLocality,
            p.locality,
            p.subAdministrativeArea,
            p.administrativeArea,
            p.country,
          ].whereType<String>().map((value) => value.trim()).toList();
          final str = _cleanLocationLabel(rawParts.join(', '));
          if (str.isNotEmpty) formatted = str;
        }
      } catch (_) {}

      if (!mounted) return false;
      setState(() {
        final cleaned = _cleanLocationLabel(formatted);
        _locationCtrl.text = cleaned;
        _locationLat = position.latitude;
        _locationLng = position.longitude;
        if (showIndicator) {
          _locating = false;
        }
      });
      unawaited(
        _cacheLocation(_locationCtrl.text.trim(), _locationLat, _locationLng),
      );
      return true;
    } catch (_) {
      if (!mounted) return false;
      if (showFeedback) {
        _showSnack(message: 'Could not fetch current location', success: false);
      }
      return false;
    } finally {
      if (showIndicator && mounted) {
        setState(() => _locating = false);
      }
    }
  }

  bool _isLikelyPlusCode(String value) {
    final cleaned = value.replaceAll(' ', '');
    return cleaned.contains('+') &&
        RegExp(r'^[23456789CFGHJMPQRVWX]{4,}\+\w+$').hasMatch(cleaned);
  }

  String _cleanLocationLabel(String raw) {
    final rawSegments = raw
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty && !_isLikelyPlusCode(segment))
        .toList();

    if (rawSegments.isEmpty) {
      return raw.trim();
    }

    final seen = <String>{};
    final uniqueSegments = <String>[];
    for (final segment in rawSegments) {
      final normalized = segment.toLowerCase();
      if (seen.add(normalized)) {
        uniqueSegments.add(segment);
      }
    }

    bool isAdministrative(String value) {
      final lower = value.toLowerCase();
      const adminKeywords = <String>[
        'province',
        'district',
        'country',
        'region',
        'state',
        'city',
        'municipality',
        'council',
      ];
      for (final keyword in adminKeywords) {
        if (lower.contains(keyword)) return true;
      }
      if (lower == 'zambia') return true;
      return false;
    }

    bool hasDigits(String value) => RegExp(r'\d').hasMatch(value);

    String? selectBest(List<String> segments) {
      for (final segment in segments) {
        if (!isAdministrative(segment) && !hasDigits(segment)) {
          return segment;
        }
      }
      for (final segment in segments) {
        if (!isAdministrative(segment)) {
          return segment;
        }
      }
      return segments.isEmpty ? null : segments.first;
    }

    return selectBest(uniqueSegments) ?? rawSegments.first;
  }

  Future<void> _restoreLastLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final label = prefs.getString(_lastLocationLabelKey);
      final lat = prefs.getDouble(_lastLocationLatKey);
      final lng = prefs.getDouble(_lastLocationLngKey);
      if (label == null || label.trim().isEmpty) return;
      if (!mounted) return;
      setState(() {
        _locationCtrl.text = label;
        _locationLat = lat;
        _locationLng = lng;
      });
    } catch (_) {}
  }

  Future<void> _cacheLocation(String label, double? lat, double? lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastLocationLabelKey, label);
      if (lat != null) {
        await prefs.setDouble(_lastLocationLatKey, lat);
      } else {
        await prefs.remove(_lastLocationLatKey);
      }
      if (lng != null) {
        await prefs.setDouble(_lastLocationLngKey, lng);
      } else {
        await prefs.remove(_lastLocationLngKey);
      }
    } catch (_) {}
  }
}
