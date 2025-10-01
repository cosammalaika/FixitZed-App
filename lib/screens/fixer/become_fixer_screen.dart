import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/home_service.dart';
import '../../services/fixer_application_service.dart';

class BecomeFixerScreen extends StatefulWidget {
  const BecomeFixerScreen({super.key});

  @override
  State<BecomeFixerScreen> createState() => _BecomeFixerScreenState();
}

class _BecomeFixerScreenState extends State<BecomeFixerScreen> {
  final _home = HomeService();
  final _applyService = FixerApplicationService();
  final _bioCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Set<int> _selectedServices = <int>{};
  PlatformFile? _profilePhoto;
  PlatformFile? _nrcFront;
  PlatformFile? _nrcBack;
  final List<PlatformFile> _supportingDocs = [];

  List<Map<String, dynamic>> _services = const [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await _home.fetchServices();
    final services = raw
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
    services.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    if (!mounted) return;
    setState(() {
      _services = services;
      _loading = false;
    });
  }

  Future<void> _selectSingleFile({required bool imagesOnly, required void Function(PlatformFile file) onSelected}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: imagesOnly
            ? const ['jpg', 'jpeg', 'png', 'webp']
            : const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) onSelected(file);
      }
    } catch (_) {
      _showSnack('Failed to pick file. Please try again.');
    }
  }

  Future<void> _selectSupportingDocs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        final files = result.files.where((f) => f.path != null).take(5).toList();
        setState(() {
          _supportingDocs
            ..clear()
            ..addAll(files);
        });
      }
    } catch (_) {
      _showSnack('Failed to pick documents. Please try again.');
    }
  }

  String _fileLabel(PlatformFile file) {
    final sizeKb = file.size / 1024;
    final size = sizeKb > 1024 ? '${(sizeKb / 1024).toStringAsFixed(1)} MB' : '${sizeKb.toStringAsFixed(0)} KB';
    return '${file.name} · $size';
  }

  Widget _documentTile({
    required String label,
    required PlatformFile? file,
    required VoidCallback onTap,
    bool required = false,
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
                required ? '$label *' : label,
                style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: onTap,
                child: Text(file == null ? 'Upload' : 'Change'),
              ),
            ],
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                helper,
                style: GoogleFonts.urbanist(color: Colors.black54, fontSize: 12),
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
                      _fileLabel(file),
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
                onPressed: _selectSupportingDocs,
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

  Future<void> _pickProfilePhoto() async {
    await _selectSingleFile(
      imagesOnly: true,
      onSelected: (file) => setState(() => _profilePhoto = file),
    );
  }

  Future<void> _pickNrcFront() async {
    await _selectSingleFile(
      imagesOnly: false,
      onSelected: (file) => setState(() => _nrcFront = file),
    );
  }

  Future<void> _pickNrcBack() async {
    await _selectSingleFile(
      imagesOnly: false,
      onSelected: (file) => setState(() => _nrcBack = file),
    );
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (_selectedServices.isEmpty) {
      _showSnack('Select at least one service');
      return;
    }
    if ((_nrcFront?.path ?? '').isEmpty || (_nrcBack?.path ?? '').isEmpty) {
      _showSnack('Please upload both sides of your NRC');
      return;
    }
    setState(() => _submitting = true);
    final ok = await _applyService.apply(
      bio: _bioCtrl.text.trim(),
      serviceIds: _selectedServices.toList(),
      profilePhotoPath: _profilePhoto?.path,
      nrcFrontPath: _nrcFront?.path,
      nrcBackPath: _nrcBack?.path,
      supportingDocuments:
          _supportingDocs.where((f) => f.path != null && f.path!.isNotEmpty).map((f) => f.path!).toList(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      _showSnack('Application submitted. We will review it shortly.', success: true);
      Navigator.of(context).pop(true);
    } else {
      _showSnack('Failed to submit application. Please try again.');
    }
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text('Become a Fixer', style: GoogleFonts.urbanist(color: Colors.black, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: ListView(
                  children: [
                    Text('Apply to become a verified Fixer', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us about your skills and experience. We will review your application and get back to you.',
                      style: GoogleFonts.urbanist(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    Text('Services you can handle', style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (_services.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'No services available yet. Please try again later.',
                          style: GoogleFonts.urbanist(color: Colors.black54),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _services.map((service) {
                          final id = (service['id'] as num?)?.toInt();
                          if (id == null) return const SizedBox.shrink();
                          final selected = _selectedServices.contains(id);
                          final name = (service['name'] ?? 'Service').toString();
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
                            selectedColor: brand.withOpacity(0.2),
                            checkmarkColor: brand,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          );
                        }).toList(),
                      ),
                    if (_selectedServices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Select the services you offer',
                          style: GoogleFonts.urbanist(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text('About you', style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bioCtrl,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Describe your experience, qualifications, and preferred areas.',
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
                    const SizedBox(height: 32),
                    Text('Verification documents', style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'Upload your NRC and any supporting documents so we can verify your identity. Each file must be under 5MB.',
                      style: GoogleFonts.urbanist(color: Colors.black54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    _documentTile(
                      label: 'Profile photo (optional)',
                      file: _profilePhoto,
                      onTap: _pickProfilePhoto,
                      helper: 'A clear headshot helps customers recognise you.',
                      onRemove: _profilePhoto == null
                          ? null
                          : () => setState(() => _profilePhoto = null),
                    ),
                    const SizedBox(height: 12),
                    _documentTile(
                      label: 'NRC front',
                      file: _nrcFront,
                      required: true,
                      onTap: _pickNrcFront,
                      helper: 'Accepted: JPG, PNG, WEBP or PDF.',
                      onRemove: _nrcFront == null
                          ? null
                          : () => setState(() => _nrcFront = null),
                    ),
                    const SizedBox(height: 12),
                    _documentTile(
                      label: 'NRC back',
                      file: _nrcBack,
                      required: true,
                      onTap: _pickNrcBack,
                      helper: 'Accepted: JPG, PNG, WEBP or PDF.',
                      onRemove: _nrcBack == null
                          ? null
                          : () => setState(() => _nrcBack = null),
                    ),
                    const SizedBox(height: 12),
                    _supportingDocsSection(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _submitting ? null : _submit,
                        child: Text(_submitting ? 'Submitting…' : 'Submit Application'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We will notify you once your application has been reviewed.',
                      style: GoogleFonts.urbanist(color: Colors.black45, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
