import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class TakePhotoScreen extends StatefulWidget {
  const TakePhotoScreen({
    super.key,
    this.galleryMaxWidth,
    this.galleryMaxHeight,
    this.galleryImageQuality = 90,
  });

  final double? galleryMaxWidth;
  final double? galleryMaxHeight;
  final int galleryImageQuality;

  static Future<String?> open(
    BuildContext context, {
    double? galleryMaxWidth,
    double? galleryMaxHeight,
    int galleryImageQuality = 90,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => TakePhotoScreen(
          galleryMaxWidth: galleryMaxWidth,
          galleryMaxHeight: galleryMaxHeight,
          galleryImageQuality: galleryImageQuality,
        ),
      ),
    );
  }

  @override
  State<TakePhotoScreen> createState() => _TakePhotoScreenState();
}

class _TakePhotoScreenState extends State<TakePhotoScreen>
    with TickerProviderStateMixin {
  static const Color _brand = Color(0xFFF1592A);

  final ImagePicker _picker = ImagePicker();

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  late final AnimationController _capturePressController;
  late final AnimationController _shutterFlashController;

  bool _loading = true;
  bool _capturing = false;
  bool _flashOn = false;
  String? _capturedPath;
  String? _errorMessage;

  bool get _showPreview => _capturedPath != null && _capturedPath!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _capturePressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _shutterFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _initializeCameraFlow();
  }

  @override
  void dispose() {
    _capturePressController.dispose();
    _shutterFlashController.dispose();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  Future<void> _initializeCameraFlow() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = 'No camera available on this device.';
        });
        return;
      }

      _cameras = cameras;
      _cameraIndex = _preferredCameraIndex(cameras);
      await _initializeController(cameras[_cameraIndex]);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Camera is unavailable. Please try again.';
      });
    }
  }

  int _preferredCameraIndex(List<CameraDescription> cameras) {
    final backIndex = cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    return backIndex >= 0 ? backIndex : 0;
  }

  Future<void> _initializeController(CameraDescription description) async {
    final oldController = _controller;
    _controller = null;
    if (oldController != null) {
      await oldController.dispose();
    }

    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    setState(() {
      _loading = true;
      _errorMessage = null;
      _flashOn = false;
    });

    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Could not start camera.';
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_showPreview) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final next = !_flashOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() => _flashOn = next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash is not available for this camera.')),
      );
    }
  }

  Future<void> _switchCamera() async {
    if (_showPreview || _loading || _capturing || _cameras.length < 2) return;
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    _cameraIndex = nextIndex;
    await _initializeController(_cameras[nextIndex]);
  }

  Future<void> _pickFromGallery() async {
    if (_capturing) return;
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: widget.galleryMaxWidth,
        maxHeight: widget.galleryMaxHeight,
        imageQuality: widget.galleryImageQuality,
      );
      if (!mounted || image == null) return;
      Navigator.of(context).pop(image.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open gallery.')),
      );
    }
  }

  Future<void> _takePhoto() async {
    if (_capturing || _loading || _showPreview) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() => _capturing = true);
    try {
      await _capturePressController.forward();
      await _capturePressController.reverse();
      unawaited(_playShutterFlash());

      final image = await controller.takePicture();
      if (!mounted) return;
      setState(() => _capturedPath = image.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture photo. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  Future<void> _playShutterFlash() async {
    try {
      await _shutterFlashController.forward(from: 0);
      if (!mounted) return;
      await _shutterFlashController.reverse();
    } catch (_) {}
  }

  void _retake() {
    if (_capturing) return;
    setState(() => _capturedPath = null);
  }

  void _usePhoto() {
    final path = _capturedPath;
    if (path == null || path.isEmpty) return;
    Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _showPreview
                ? _buildCapturedPreview(key: const ValueKey('preview'))
                : _buildCameraPreview(key: const ValueKey('live')),
          ),
          _buildBottomGradientScrim(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopOverlay(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _showPreview ? _buildPreviewActionBar() : _buildCaptureBar(),
          ),
          AnimatedBuilder(
            animation: _shutterFlashController,
            builder: (_, __) {
              final opacity = 0.26 * _shutterFlashController.value;
              if (opacity <= 0) return const SizedBox.shrink();
              return IgnorePointer(
                child: Container(color: Colors.white.withValues(alpha: opacity)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomGradientScrim() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.62, 0.84, 1],
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.24),
              Colors.black.withValues(alpha: 0.56),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview({required Key key}) {
    if (_errorMessage != null) {
      return _buildErrorState(key: key);
    }
    if (_loading || _controller == null || !_controller!.value.isInitialized) {
      return Center(
        key: key,
        child: const CircularProgressIndicator(color: _brand),
      );
    }

    final previewSize = _controller!.value.previewSize;
    if (previewSize == null) {
      return Center(
        key: key,
        child: const CircularProgressIndicator(color: _brand),
      );
    }

    return SizedBox.expand(
      key: key,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _buildCapturedPreview({required Key key}) {
    final path = _capturedPath;
    if (path == null || path.isEmpty) {
      return _buildCameraPreview(key: key);
    }

    return SizedBox.expand(
      key: key,
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: Text(
            'Could not load captured image.',
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState({required Key key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF2B2B2B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, color: _brand, size: 36),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Unable to open camera.',
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _initializeCameraFlow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    final showFlash =
        !_showPreview && _controller != null && _errorMessage == null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  _overlayIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Take Photo',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (showFlash)
                    _overlayIconButton(
                      icon: _flashOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      onTap: _toggleFlash,
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildCaptureBar() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 42),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _controlIconButton(
            icon: Icons.photo_library_outlined,
            onTap: _pickFromGallery,
          ),
          AnimatedBuilder(
            animation: _capturePressController,
            builder: (_, child) {
              final scale = 1 - (_capturePressController.value * 0.08);
              return Transform.scale(scale: scale, child: child);
            },
            child: GestureDetector(
              onTap: _takePhoto,
              child: Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.98),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: _brand.withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8A5C), _brand],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _controlIconButton(
            icon: Icons.cameraswitch_outlined,
            onTap: _cameras.length > 1 ? _switchCamera : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewActionBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _retake,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _usePhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      child: const Text('Use Photo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlIconButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: disabled ? 0.1 : 0.16),
          child: InkWell(
            onTap: onTap,
            child: Ink(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: disabled ? 0.12 : 0.28),
                ),
                boxShadow: [
                  if (!disabled)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Icon(
                icon,
                color: disabled
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.96),
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
