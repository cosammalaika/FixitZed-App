import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePhotoService {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();
  final ImagePicker _picker = ImagePicker();
  // One-time image picking only; no persistent storage/media permissions are required.

  Future<String?> pickFromCamera() async {
    if (kIsWeb) return null;
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    return image?.path;
  }

  Future<String?> pickFromGallery() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return null;
      return result.files.first.path;
    }

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 92,
    );
    return image?.path;
  }

  Future<File?> toFile(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (await file.exists()) return file;
    return null;
  }
}
