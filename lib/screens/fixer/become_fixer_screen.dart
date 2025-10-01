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
    setState(() => _submitting = true);
    final ok = await _applyService.apply(
      bio: _bioCtrl.text.trim(),
      serviceIds: _selectedServices.toList(),
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
