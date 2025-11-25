import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/services/locations_service.dart';

class ManageAddressScreen extends StatefulWidget {
  const ManageAddressScreen({super.key});

  @override
  State<ManageAddressScreen> createState() => _ManageAddressScreenState();
}

class _ManageAddressScreenState extends State<ManageAddressScreen> {
  final _svc = LocationsService();
  bool _loading = true;
  bool _dirty = false;
  List<Map<String, dynamic>> _addresses = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _svc.list();
    if (!mounted) return;
    setState(() {
      _addresses = list;
      _loading = false;
    });
  }

  Future<void> _delete(Map<String, dynamic> address) async {
    final id = _parseId(address['id']);
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove address?'),
        content: const Text(
          'This address will be removed from your saved locations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _svc.delete(id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _dirty = true;
        _addresses =
            _addresses.where((element) => _parseId(element['id']) != id).toList();
      });
      _showSnack('Address removed');
    } else {
      _showSnack('Failed to remove the address', success: false);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? initial}) async {
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddressFormSheet(initial: initial),
    );
    if (payload == null) return;
    final saved = await _svc.save(
      id: _parseId(initial?['id']),
      label: payload['label'] as String,
      address: payload['address'] as String,
      city: payload['city'] as String?,
      instructions: payload['details'] as String?,
      latitude: payload['latitude'] as double?,
      longitude: payload['longitude'] as double?,
      isDefault: payload['is_default'] as bool? ?? false,
    );
    if (!mounted) return;
    if (saved != null) {
      _dirty = true;
      await _load();
      _showSnack(
        initial == null ? 'Address saved' : 'Address updated',
      );
    } else {
      _showSnack(
        'Unable to save the address. Please try again.',
        success: false,
      );
    }
  }

  void _showSnack(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF2E7D32) : Colors.redAccent,
      ),
    );
  }

  int? _parseId(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  bool _isDefault(Map<String, dynamic> address) {
    final flags = [
      address['is_default'],
      address['default'],
      address['primary'],
      address['isPrimary'],
    ];
    for (final entry in flags) {
      if (entry == null) continue;
      if (entry is bool && entry) return true;
      if (entry is num && entry != 0) return true;
      if (entry is String) {
        final lower = entry.toLowerCase();
        if (lower == '1' || lower == 'true' || lower == 'yes') return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Future<bool> handlePop() async {
      Navigator.of(context).pop(_dirty);
      return false;
    }

    return WillPopScope(
      onWillPop: handlePop,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          title: Text(
            'Manage Addresses',
            style: GoogleFonts.urbanist(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: handlePop,
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('Add address'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _addresses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.maps_home_work_outlined,
                            size: 64,
                            color: Color(0xFFB0B7C3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No saved addresses yet',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your frequently used locations to speed up new requests.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.urbanist(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemBuilder: (context, index) {
                        final address = _addresses[index];
                        final label =
                            (address['label'] ?? address['address'] ?? 'Address')
                                .toString();
                        final line =
                            (address['address'] ?? address['line1'] ?? '')
                                .toString();
                        final city = (address['city'] ?? address['town'] ?? '')
                            .toString();
                        final details =
                            (address['details'] ?? address['description'] ?? '')
                                .toString();
                        final badge = _isDefault(address)
                            ? Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x1AF1592A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Default',
                                  style: GoogleFonts.urbanist(
                                    color: const Color(0xFFF1592A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : null;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x11000000),
                                blurRadius: 16,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0x1AF1592A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.place_rounded,
                                  color: Color(0xFFF1592A),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            label,
                                            style: GoogleFonts.urbanist(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        if (badge != null) badge,
                                      ],
                                    ),
                                    if (line.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        line,
                                        style: GoogleFonts.urbanist(
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                    if (city.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        city,
                                        style: GoogleFonts.urbanist(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                    if (details.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        details,
                                        style: GoogleFonts.urbanist(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () => _openEditor(
                                      initial: address,
                                    ),
                                    icon: const Icon(Icons.edit_rounded),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => _delete(address),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: _addresses.length,
                    ),
                  ),
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _AddressFormSheet({required this.initial});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _detailsCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  bool _makeDefault = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? <String, dynamic>{};
    _labelCtrl = TextEditingController(
      text: (initial['label'] ?? initial['address'] ?? '').toString(),
    );
    _addressCtrl = TextEditingController(
      text: (initial['address'] ?? initial['line1'] ?? '').toString(),
    );
    _cityCtrl = TextEditingController(
      text: (initial['city'] ?? initial['town'] ?? '').toString(),
    );
    _detailsCtrl = TextEditingController(
      text: (initial['details'] ?? initial['description'] ?? '').toString(),
    );
    _latCtrl = TextEditingController(
      text: _formatCoordinate(initial['latitude']),
    );
    _lngCtrl = TextEditingController(
      text: _formatCoordinate(initial['longitude']),
    );
    _makeDefault = initial.isEmpty ? true : initial['is_default'] == true;
  }

  String _formatCoordinate(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    return value.toString();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _detailsCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showSnack('Enable location services to continue');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Location permission denied');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _latCtrl.text = position.latitude.toString();
      _lngCtrl.text = position.longitude.toString();
      try {
        final places = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (places.isNotEmpty) {
          final p = places.first;
          final addressParts = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
            p.country,
          ].whereType<String>().where((value) => value.trim().isNotEmpty);
          final label = addressParts.join(', ');
          if (label.isNotEmpty) {
            _addressCtrl.text = label;
            _labelCtrl.text = label;
          }
          if ((p.locality ?? '').isNotEmpty) {
            _cityCtrl.text = p.locality!;
          }
        }
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final title = widget.initial == null ? 'Add address' : 'Edit address';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _labelCtrl,
                decoration: const InputDecoration(labelText: 'Label'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter a label'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Address line'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter the address'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(labelText: 'City / District'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detailsCtrl,
                decoration:
                    const InputDecoration(labelText: 'Instructions (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Latitude'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Longitude'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: Text(_locating ? 'Locating…' : 'Use current location'),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _makeDefault,
                onChanged: (value) => setState(() => _makeDefault = value),
                title: const Text('Set as default location'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    double? parse(String text) {
                      if (text.trim().isEmpty) return null;
                      return double.tryParse(text.trim());
                    }

                    Navigator.of(context).pop({
                      'label': _labelCtrl.text.trim(),
                      'address': _addressCtrl.text.trim(),
                      'city': _cityCtrl.text.trim().isEmpty
                          ? null
                          : _cityCtrl.text.trim(),
                      'details': _detailsCtrl.text.trim().isEmpty
                          ? null
                          : _detailsCtrl.text.trim(),
                      'latitude': parse(_latCtrl.text),
                      'longitude': parse(_lngCtrl.text),
                      'is_default': _makeDefault,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Save address'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
