import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixitzed_app/services/fixer_application_service.dart';
import 'package:fixitzed_app/services/home_service.dart';

enum _AttachmentAction { camera, gallery, file }

class BecomeFixerScreen extends StatefulWidget {
  const BecomeFixerScreen({super.key});

  @override
  State<BecomeFixerScreen> createState() => _BecomeFixerScreenState();
}

class _BecomeFixerScreenState extends State<BecomeFixerScreen> {
  final _home = HomeService();
  final _applyService = FixerApplicationService();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  final Set<int> _selectedServices = <int>{};
  final List<PlatformFile> _supportingDocs = [];

  PlatformFile? _profilePhoto;
  PlatformFile? _nrcFront;
  PlatformFile? _nrcBack;

  List<Map<String, dynamic>> _services = const [];
  bool _loading = true;
  bool _submitting = false;
  bool _requestingLocation = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await _home.fetchServices();
    final services = raw
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
    services.sort(
      (a, b) =>
          (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()),
    );
    if (!mounted) return;
    setState(() {
      _services = services;
      _loading = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_requestingLocation) return;
    setState(() => _requestingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled. Please enable them.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _showSnack('Location permissions are denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      final buffer = [
        if (place != null &&
            place.street != null &&
            place.street!.trim().isNotEmpty)
          place.street,
        if (place != null &&
            place.subLocality != null &&
            place.subLocality!.trim().isNotEmpty)
          place.subLocality,
        if (place != null &&
            place.locality != null &&
            place.locality!.trim().isNotEmpty)
          place.locality,
        if (place != null &&
            place.country != null &&
            place.country!.trim().isNotEmpty)
          place.country,
      ].whereType<String>().join(', ');
      final locationString = buffer.isNotEmpty
          ? buffer
          : 'Lat ${position.latitude.toStringAsFixed(4)}, Lng ${position.longitude.toStringAsFixed(4)}';
      if (!mounted) return;
      _locationCtrl.text = locationString;
    } catch (_) {
      _showSnack('Unable to fetch current location.');
    } finally {
      if (mounted) setState(() => _requestingLocation = false);
    }
  }

  Future<void> _pickAttachment({
    required bool allowPdf,
    required ValueChanged<PlatformFile> onSelected,
  }) async {
    final action = await showModalBottomSheet<_AttachmentAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(ctx).pop(_AttachmentAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.image_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop(_AttachmentAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.file_present_rounded),
              title: Text(
                allowPdf ? 'Upload file (PDF or image)' : 'Upload image',
              ),
              onTap: () => Navigator.of(ctx).pop(_AttachmentAction.file),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (action == null) return;

    try {
      late final PlatformFile file;
      switch (action) {
        case _AttachmentAction.camera:
          final xFile = await _imagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
          );
          if (xFile == null) return;
          file = await _toPlatformFile(xFile);
          break;
        case _AttachmentAction.gallery:
          final xFile = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
          );
          if (xFile == null) return;
          file = await _toPlatformFile(xFile);
          break;
        case _AttachmentAction.file:
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: allowPdf
                ? const ['jpg', 'jpeg', 'png', 'webp', 'pdf']
                : const ['jpg', 'jpeg', 'png', 'webp'],
          );
          if (result == null || result.files.isEmpty) return;
          final picked = result.files.first;
          if (picked.path == null || picked.path!.isEmpty) {
            _showSnack('Selected file has no path. Please try again.');
            return;
          }
          file = picked;
          break;
      }

      onSelected(file);
    } catch (_) {
      _showSnack('Could not pick file. Please try again.');
    }
  }

  Future<PlatformFile> _toPlatformFile(XFile xFile) async {
    final path = xFile.path;
    final size = await File(path).length();
    return PlatformFile(name: _fileName(path), path: path, size: size);
  }

  String _fileName(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : path;
  }

  Widget _documentTile({
    required String label,
    required PlatformFile? file,
    required bool allowPdf,
    required ValueChanged<PlatformFile> onSelected,
    bool requiredField = false,
    String? helper,
    VoidCallback? onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                requiredField ? '$label *' : label,
                style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () =>
                    _pickAttachment(allowPdf: allowPdf, onSelected: onSelected),
                child: Text(file == null ? 'Upload' : 'Change'),
              ),
            ],
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                helper,
                style: GoogleFonts.urbanist(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
          if (file != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: Color(0xFFF1592A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${file.name} · ${_fileSize(file.size)}',
                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onRemove != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onRemove,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _fileSize(int bytes) {
    final kb = bytes / 1024;
    if (kb > 1024) return '${(kb / 1024).toStringAsFixed(1)} MB';
    return '${kb.toStringAsFixed(0)} KB';
  }

  Widget _supportingDocsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Supporting documents (optional)',
                style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: () async {
                  await _pickAttachment(
                    allowPdf: true,
                    onSelected: (file) {
                      setState(() {
                        if (_supportingDocs.length >= 5) {
                          _supportingDocs.removeAt(0);
                        }
                        _supportingDocs.add(file);
                      });
                    },
                  );
                },
                icon: const Icon(Icons.upload_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Certificates, permits or any extra proof (PDF or image, max 5 files).',
            style: GoogleFonts.urbanist(color: Colors.black54, fontSize: 12),
          ),
          if (_supportingDocs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_supportingDocs.length, (index) {
                final file = _supportingDocs[index];
                return Chip(
                  label: Text(file.name, overflow: TextOverflow.ellipsis),
                  deleteIcon: const Icon(Icons.close),
                  onDeleted: () {
                    setState(() => _supportingDocs.removeAt(index));
                  },
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() => _step = 0);
      return;
    }
    if (_nrcFront == null || _nrcBack == null) {
      setState(() => _step = 1);
      _showSnack('Please upload both sides of your NRC');
      return;
    }
    if (_selectedServices.isEmpty) {
      setState(() => _step = 2);
      _showSnack('Select at least one service');
      return;
    }

    setState(() => _submitting = true);
    final ok = await _applyService.apply(
      bio: _bioCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      serviceIds: _selectedServices.toList(),
      profilePhotoPath: _profilePhoto?.path,
      nrcFrontPath: _nrcFront?.path,
      nrcBackPath: _nrcBack?.path,
      supportingDocuments: _supportingDocs
          .where((f) => f.path != null && f.path!.isNotEmpty)
          .map((f) => f.path!)
          .toList(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      _showSnack(
        'Application submitted. We will review it shortly.',
        success: true,
      );
      Navigator.of(context).pop(true);
    } else {
      _showSnack('Failed to submit application. Please try again.');
    }
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? const Color(0xFF2E7D32)
            : const Color(0xFFD32F2F),
      ),
    );
  }

  bool _validateCurrentStep() {
    switch (_step) {
      case 0:
        return _formKey.currentState?.validate() ?? false;
      case 1:
        if (_nrcFront == null || _nrcBack == null) {
          _showSnack('Please upload both sides of your NRC');
          return false;
        }
        return true;
      case 2:
        if (_selectedServices.isEmpty) {
          _showSnack('Select at least one service');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    const accent = Color(0xFFFFA26C);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Become a Fixer',
          style: GoogleFonts.urbanist(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [brand, accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: brand.withValues(alpha: 0.20),
                          blurRadius: 18,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.handyman_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Become a Fixer',
                                style: GoogleFonts.urbanist(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tell us about yourself and upload your documents to get started.',
                                style: GoogleFonts.urbanist(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stepper(
                      currentStep: _step,
                      onStepTapped: (value) => setState(() => _step = value),
                      controlsBuilder: (context, details) {
                        return Row(
                          children: [
                            ElevatedButton(
                              onPressed: _submitting
                                  ? null
                                  : () {
                                      final valid = _validateCurrentStep();
                                      if (!valid) return;
                                      if (_step == 2) {
                                        _submit();
                                      } else {
                                        setState(() => _step += 1);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brand,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                _step == 2
                                    ? (_submitting ? 'Submitting…' : 'Submit')
                                    : 'Next',
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: _step == 0
                                  ? () => Navigator.of(context).pop()
                                  : () => setState(() => _step -= 1),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Back'),
                            ),
                          ],
                        );
                      },
                      steps: [
                        Step(
                          title: const Text('Profile'),
                          isActive: _step >= 0,
                          state: _step > 0
                              ? StepState.complete
                              : StepState.indexed,
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tell us about your skills and where you operate. This helps customers know you better.',
                                style: GoogleFonts.urbanist(
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _bioCtrl,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  hintText:
                                      'Describe your experience, qualifications, and preferred areas.',
                                  filled: true,
                                  fillColor: const Color(0xFFF3F5F7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Tell us a bit about your experience';
                                  }
                                  if (value.trim().length < 30) {
                                    return 'Please provide at least 30 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _locationCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Business location (optional)',
                                  filled: true,
                                  fillColor: const Color(0xFFF3F5F7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: _requestingLocation
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.my_location_rounded),
                                    onPressed: _requestingLocation
                                        ? null
                                        : _useCurrentLocation,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Step(
                          title: const Text('Documents'),
                          isActive: _step >= 1,
                          state: _step > 1
                              ? StepState.complete
                              : (_nrcFront != null && _nrcBack != null
                                    ? StepState.editing
                                    : StepState.indexed),
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _documentTile(
                                label: 'Profile photo (optional)',
                                file: _profilePhoto,
                                allowPdf: false,
                                helper:
                                    'A clear headshot helps customers recognise you.',
                                onSelected: (file) =>
                                    setState(() => _profilePhoto = file),
                                onRemove: _profilePhoto == null
                                    ? null
                                    : () =>
                                          setState(() => _profilePhoto = null),
                              ),
                              const SizedBox(height: 12),
                              _documentTile(
                                label: 'NRC front',
                                file: _nrcFront,
                                allowPdf: true,
                                requiredField: true,
                                helper:
                                    'Accepted: JPG, PNG, WEBP or PDF (max 5MB).',
                                onSelected: (file) =>
                                    setState(() => _nrcFront = file),
                                onRemove: _nrcFront == null
                                    ? null
                                    : () => setState(() => _nrcFront = null),
                              ),
                              const SizedBox(height: 12),
                              _documentTile(
                                label: 'NRC back',
                                file: _nrcBack,
                                allowPdf: true,
                                requiredField: true,
                                helper:
                                    'Accepted: JPG, PNG, WEBP or PDF (max 5MB).',
                                onSelected: (file) =>
                                    setState(() => _nrcBack = file),
                                onRemove: _nrcBack == null
                                    ? null
                                    : () => setState(() => _nrcBack = null),
                              ),
                              const SizedBox(height: 12),
                              _supportingDocsSection(),
                            ],
                          ),
                        ),
                        Step(
                          title: const Text('Services'),
                          isActive: _step >= 2,
                          state: _selectedServices.isNotEmpty
                              ? StepState.editing
                              : StepState.indexed,
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select the services you can handle. Customers will see these on your profile.',
                                style: GoogleFonts.urbanist(
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_services.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'No services available yet. Please try again later.',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.black54,
                                    ),
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _services.map((service) {
                                    final id = (service['id'] as num?)?.toInt();
                                    if (id == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final selected = _selectedServices.contains(
                                      id,
                                    );
                                    final name = (service['name'] ?? 'Service')
                                        .toString();
                                    return FilterChip(
                                      selected: selected,
                                      onSelected: (_) {
                                        setState(() {
                                          if (selected) {
                                            _selectedServices.remove(id);
                                          } else {
                                            _selectedServices.add(id);
                                          }
                                        });
                                      },
                                      label: Text(name),
                                      selectedColor: brand.withValues(alpha: 0.2),
                                      checkmarkColor: brand,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              if (_selectedServices.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Select at least one service you offer.',
                                    style: GoogleFonts.urbanist(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
