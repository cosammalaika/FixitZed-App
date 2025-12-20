import 'dart:async';

import 'package:fixitzed_app/screens/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixitzed_app/data/province_districts.dart';
import 'package:fixitzed_app/services/auth_service.dart';
import 'package:fixitzed_app/services/location_service.dart';
import 'package:fixitzed_app/core/app_spacing.dart';
import 'package:fixitzed_app/widgets/app_text_field.dart';
import 'package:fixitzed_app/widgets/keyboard_safe_form.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _WizardStep {
  final String title;
  final String subtitle;
  final IconData icon;

  const _WizardStep({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _SignUpScreenState extends State<SignUpScreen> {
  final orange = const Color(0xFFF1592A);

  static const List<_WizardStep> _steps = [
    _WizardStep(
      title: 'Who are you?',
      subtitle: 'Let’s start with the basics.',
      icon: Icons.person_outline_rounded,
    ),
    _WizardStep(
      title: 'Where are you based?',
      subtitle: 'We match jobs to your area.',
      icon: Icons.location_on_outlined,
    ),
    _WizardStep(
      title: 'Secure your account',
      subtitle: 'Set a strong password.',
      icon: Icons.lock_outline_rounded,
    ),
  ];

  late final List<GlobalKey<FormState>> _stepKeys;
  int _currentStep = 0;

  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  final _firstFocus = FocusNode();
  final _lastFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();

  final _locationService = LocationService();
  Map<String, List<String>> _provinceMap = ProvinceData.asMutable();
  String? _selectedProvince;
  String? _selectedDistrict;
  List<String> _districtOptions = [];
  bool _loadingProvinces = false;
  int get _stepCount => _steps.length;
  bool get _isLastStep => _currentStep == _stepCount - 1;

  @override
  void initState() {
    super.initState();
    _stepKeys = List.generate(_stepCount, (_) => GlobalKey<FormState>());
    _districtOptions = [];
    _loadProvinceData();
  }

  Future<void> _loadProvinceData() async {
    setState(() => _loadingProvinces = true);
    try {
      final data = await _locationService.fetchProvinceDistricts();
      if (!mounted) return;
      setState(() {
        _provinceMap = data;
        if (_selectedProvince != null &&
            !_provinceMap.containsKey(_selectedProvince)) {
          _selectedProvince = null;
        }
        _districtOptions = _selectedProvince != null
            ? List<String>.from(
                _provinceMap[_selectedProvince!] ?? const <String>[],
              )
            : <String>[];
        if (!_districtOptions.contains(_selectedDistrict)) {
          _selectedDistrict = null;
        }
        _loadingProvinces = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProvinces = false);
    }
  }

  void _onProvinceChanged(String? province) {
    setState(() {
      _selectedProvince = province;
      _districtOptions = province != null
          ? List<String>.from(_provinceMap[province] ?? const <String>[])
          : <String>[];
      if (!_districtOptions.contains(_selectedDistrict)) {
        _selectedDistrict = null;
      }
    });
  }

  void _goToPreviousStep() {
    if (_currentStep == 0 || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _currentStep -= 1);
  }

  void _goToNextStep() {
    if (_isLastStep || _loading) return;
    FocusScope.of(context).unfocus();
    final form = _stepKeys[_currentStep].currentState;
    if (form == null) return;
    if (!form.validate()) return;
    setState(() => _currentStep += 1);
  }

  bool _validateAllSteps() {
    var firstInvalid = -1;
    for (var i = 0; i < _stepCount; i++) {
      final form = _stepKeys[i].currentState;
      if (form == null) continue;
      if (!form.validate()) {
        firstInvalid = i;
        break;
      }
    }
    if (firstInvalid != -1 && firstInvalid != _currentStep) {
      setState(() => _currentStep = firstInvalid);
      return false;
    }
    return firstInvalid == -1;
  }

  bool _loading = false;
  bool _pwVisible = false;
  bool _cpwVisible = false;

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
    _firstFocus.dispose();
    _lastFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> handleSignUp() async {
    FocusScope.of(context).unfocus();
    if (!_validateAllSteps()) return;

    final firstName = firstNameCtrl.text.trim();
    final lastName = lastNameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final username = usernameCtrl.text.trim();
    final password = passCtrl.text;
    final province = _selectedProvince;
    final district = _selectedDistrict;

    if (province == null || district == null) {
      await _showErrorDialog(
        title: 'Missing location',
        message: 'Select your province and district before continuing.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await AuthService().register(
        firstName: firstName,
        lastName: lastName.isEmpty ? null : lastName,
        email: email,
        phone: phone,
        password: password,
        province: province,
        district: district,
        username: username.isEmpty ? null : username,
      );
      if (!mounted) return;

      if (result.success) {
        // Optional: clear remembered email on a fresh sign-up
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('remember_identifier');
        await prefs.remove('remember_email');

        unawaited(Navigator.pushReplacementNamed(context, '/home'));
      } else {
        final detailLines = result.errors;
        var message = result.displayMessage ?? '';
        if (message.isEmpty && detailLines.isNotEmpty) {
          message = 'Please review the issues below.';
        } else if (message.isEmpty) {
          message = 'We couldn\'t create your account. Please try again.';
        }
        await _showErrorDialog(
          title: 'Sign up failed',
          message: message,
          details: detailLines,
        );
      }
    } catch (_) {
      if (!mounted) return;
      await _showErrorDialog(
        title: 'Sign up failed',
        message:
            'We couldn\'t reach our servers. Please check your internet connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showErrorDialog({
    required String title,
    required String message,
    List<String> details = const [],
  }) async {
    const brand = Color(0xFFF1592A);
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: brand,
                  size: 32,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(color: Colors.black87),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...details.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(color: Colors.black54),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            style: GoogleFonts.urbanist(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('OK, got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixIcon: suffix,
    );
  }

  Widget _row2(BuildContext context, Widget a, Widget b) {
    final wide = MediaQuery.of(context).size.width >= 600;
    if (wide) {
      return Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      );
    }
    return Column(children: [a, const SizedBox(height: 12), b]);
  }

  Widget _buildHeroSection(double height, Color brand) {
    final step = _steps[_currentStep];
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.9),
                  brand.withOpacity(0.9),
                  const Color(0xFF1F1F1F),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Create your Fixer profile',
                              style: GoogleFonts.urbanist(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'A few guided steps\nand you’re ready to go.',
                            style: GoogleFonts.urbanist(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                      Image.asset(
                        'assets/images/logo.png',
                        height: 85,
                        fit: BoxFit.contain,
                        semanticLabel: 'FixItZed logo',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Row(
                    key: ValueKey(step.title),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        child: Icon(step.icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Step ${_currentStep + 1} of $_stepCount',
                            style: GoogleFonts.urbanist(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Text(
                          //   step.title,
                          //   style: GoogleFonts.urbanist(
                          //     color: Colors.white,
                          //     fontSize: 18,
                          //     fontWeight: FontWeight.w700,
                          //   ),
                          // ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressOverview(Color brand) {
    final progress = (_currentStep + 1) / _stepCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: progress,
            backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.24),
            valueColor: AlwaysStoppedAnimation<Color>(brand),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(int index) {
    switch (index) {
      case 0:
        return _buildStepSection(
          index: index,
          fields: [
            _row2(
              context,
              FocusAware(
                focusNode: _firstFocus,
                child: AppTextField(
                  controller: firstNameCtrl,
                  focusNode: _firstFocus,
                  nextFocusNode: _lastFocus,
                  textInputAction: TextInputAction.next,
                  labelText: 'First Name',
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'First name is required'
                      : null,
                ),
              ),
              FocusAware(
                focusNode: _lastFocus,
                child: AppTextField(
                  controller: lastNameCtrl,
                focusNode: _lastFocus,
                nextFocusNode: _usernameFocus,
                textInputAction: TextInputAction.next,
                labelText: 'Last Name',
                validator: (v) => v == null || v.trim().isEmpty
                      ? 'Last Name is required'
                      : null,
              ),
            ),
            ),
            FocusAware(
              focusNode: _usernameFocus,
              child: AppTextField(
                controller: usernameCtrl,
                focusNode: _usernameFocus,
                nextFocusNode: _emailFocus,
                textInputAction: TextInputAction.next,
                labelText: 'Username (optional)',
                hintText: 'Public handle',
                helperText: 'Clients will see this as your public handle.',
                helperStyle: GoogleFonts.urbanist(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
                suffixIcon: const Icon(Icons.alternate_email_rounded),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return null;
                  if (trimmed.length < 3) {
                    return 'Username should be at least 3 characters';
                  }
                  return null;
                },
              ),
            ),
            FocusAware(
              focusNode: _emailFocus,
              child: AppTextField(
                controller: emailCtrl,
                focusNode: _emailFocus,
                nextFocusNode: _phoneFocus,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                labelText: 'Email Address',
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Email is required';
                  final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s);
                  return ok ? null : 'Enter a valid email';
                },
              ),
            ),
          ],
          footer: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildInfoPill(
                  'We’ll never share your details.',
                  icon: Icons.privacy_tip_outlined,
                ),
                _buildInfoPill(
                  'Names help clients recognise you.',
                  icon: Icons.handshake_outlined,
                ),
              ],
            ),
          ],
        );
      case 1:
        final fields = <Widget>[
          FocusAware(
            focusNode: _phoneFocus,
            child: AppTextField(
              controller: phoneCtrl,
              focusNode: _phoneFocus,
              nextFocusNode: _passFocus,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              labelText: 'Contact Number',
              hintText: '9-digit mobile number',
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Center(
                  widthFactor: 0,
                  child: Text(
                    '+260',
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Contact number is required';
                if (value.length != 9) return 'Enter a valid 9-digit number';
                return null;
              },
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: _selectedProvince,
            items: _provinceMap.keys
                .map(
                  (province) =>
                      DropdownMenuItem(value: province, child: Text(province)),
                )
                .toList(),
            decoration: _dec('Province'),
            isExpanded: true,
            onChanged: (_loading || _loadingProvinces)
                ? null
                : (value) => _onProvinceChanged(value),
            validator: (value) {
              if (_loadingProvinces) return null;
              if (_provinceMap.isEmpty) return 'Provinces unavailable';
              if (value == null || value.isEmpty) return 'Province is required';
              return null;
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _selectedDistrict,
            items: _districtOptions
                .map(
                  (district) =>
                      DropdownMenuItem(value: district, child: Text(district)),
                )
                .toList(),
            decoration: _dec('Area / District'),
            isExpanded: true,
            onChanged:
                (_selectedProvince == null ||
                    _districtOptions.isEmpty ||
                    _loading ||
                    _loadingProvinces)
                ? null
                : (value) => setState(() => _selectedDistrict = value),
            validator: (value) {
              if (_loadingProvinces) return null;
              if (_selectedProvince == null || _selectedProvince!.isEmpty) {
                return 'Select a province first';
              }
              if (_districtOptions.isEmpty) return 'No areas available';
              if (value == null || value.isEmpty) return 'Area is required';
              return null;
            },
          ),
        ];
        if (_loadingProvinces) {
          fields.addAll([
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 3),
          ]);
        }
        return _buildStepSection(
          index: index,
          fields: fields,
          footer: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildInfoPill(
                  'We sync job leads to your coverage.',
                  icon: Icons.map_outlined,
                ),
                _buildInfoPill(
                  'Districts refresh instantly after selection.',
                  icon: Icons.refresh_rounded,
                ),
              ],
            ),
          ],
        );
      default:
        return _buildStepSection(
          index: index,
          fields: [
            FocusAware(
              focusNode: _passFocus,
              child: AppTextField(
                controller: passCtrl,
                focusNode: _passFocus,
                nextFocusNode: _confirmFocus,
                textInputAction: TextInputAction.next,
                obscureText: !_pwVisible,
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _pwVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: _loading
                      ? null
                      : () => setState(() => _pwVisible = !_pwVisible),
                ),
                validator: (v) {
                  final s = v ?? '';
                  if (s.isEmpty) return 'Password is required';
                  if (s.length < 8) return 'Minimum 8 characters';
                  return null;
                },
              ),
            ),
            FocusAware(
              focusNode: _confirmFocus,
              child: AppTextField(
                controller: confirmPassCtrl,
                focusNode: _confirmFocus,
                textInputAction: TextInputAction.done,
                obscureText: !_cpwVisible,
                labelText: 'Confirm Password',
                onFieldSubmitted: (_) => handleSignUp(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _cpwVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: _loading
                      ? null
                      : () => setState(() => _cpwVisible = !_cpwVisible),
                ),
                validator: (v) =>
                    v != passCtrl.text ? 'Passwords do not match' : null,
              ),
            ),
          ],
          footer: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make it memorable and secure:',
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildInfoPill(
                      'Mix letters & numbers',
                      icon: Icons.text_fields,
                    ),
                    _buildInfoPill(
                      'Avoid reused passwords',
                      icon: Icons.shield_moon_outlined,
                    ),
                    _buildInfoPill(
                      'Add a memorable symbol',
                      icon: Icons.emoji_objects_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildStepSection({
    required int index,
    required List<Widget> fields,
    List<Widget> footer = const [],
  }) {
    final step = _steps[index];
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface.withOpacity(
      theme.brightness == Brightness.dark ? 0.9 : 0.94,
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
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
                  shape: BoxShape.circle,
                  color: orange.withOpacity(0.14),
                ),
                child: Icon(step.icon, color: orange),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.subtitle,
                      style: GoogleFonts.urbanist(
                        fontSize: 14,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < fields.length; i++) ...[
            if (i != 0) const SizedBox(height: AppSpacing.md),
            fields[i],
          ],
          if (footer.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            ...footer
          ],
        ],
      ),
    );
  }

  Widget _buildInfoPill(String text, {IconData icon = Icons.auto_awesome}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: orange),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.urbanist(
                color: orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar(Color brand) {
    final primaryLabel = _isLastStep
        ? 'Create my account'
        : 'Next: ${_steps[_currentStep + 1].title}';
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _loading ? null : _goToPreviousStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: const Text('Back'),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: _currentStep > 0 ? 2 : 1,
          child: ElevatedButton(
            onPressed: _loading
                ? null
                : _isLastStep
                ? handleSignUp
                : _goToNextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(primaryLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPrompt(Color brand) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).hintColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _loading
              ? null
              : () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                ),
          child: Text(
            'Log in',
            style: GoogleFonts.urbanist(
              fontSize: 14,
              color: brand,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = orange;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heroHeight = (constraints.maxHeight * 0.3)
                    .clamp(220.0, 280.0)
                    .toDouble();
                final bottomInset =
                    MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg;
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Column(
                    children: [
                      _buildHeroSection(heroHeight, brand),
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Transform.translate(
                            offset: const Offset(0, -26),
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).canvasColor.withOpacity(
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? 0.92
                                              : 0.96,
                                        ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(26),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 14,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.lg,
                                  AppSpacing.xxl,
                                  AppSpacing.lg,
                                  AppSpacing.md,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildProgressOverview(brand),
                                    const SizedBox(height: AppSpacing.md),
                                    AnimatedSize(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.easeOut,
                                      child: IndexedStack(
                                        index: _currentStep,
                                        children: List.generate(
                                          _stepCount,
                                          (index) => Form(
                                            key: _stepKeys[index],
                                            autovalidateMode: AutovalidateMode
                                                .onUserInteraction,
                                            child: _buildStepContent(index),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    _buildNavigationBar(brand),
                                    const SizedBox(height: AppSpacing.md),
                                    _buildLoginPrompt(brand),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
