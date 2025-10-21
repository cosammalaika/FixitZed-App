import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/core/api.dart';

class FixerApplicationService {
  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<bool> apply({
    required String bio,
    String? location,
    required List<int> serviceIds,
    String? profilePhotoPath,
    String? nrcFrontPath,
    String? nrcBackPath,
    List<String> supportingDocuments = const [],
  }) async {
    final token = await _token();
    if (token == null) return false;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${Api.baseUrl}/fixer/apply'),
    );

    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['bio'] = bio;
    if (location != null && location.trim().isNotEmpty) {
      request.fields['location'] = location.trim();
    }
    for (var i = 0; i < serviceIds.length; i++) {
      request.fields['service_ids[$i]'] = serviceIds[i].toString();
    }

    Future<void> attach(String? path, String field) async {
      if (path == null || path.isEmpty) return;
      request.files.add(await http.MultipartFile.fromPath(field, path));
    }

    await attach(profilePhotoPath, 'profile_photo');
    await attach(nrcFrontPath, 'nrc_front');
    await attach(nrcBackPath, 'nrc_back');

    for (var i = 0; i < supportingDocuments.length; i++) {
      final path = supportingDocuments[i];
      if (path.isEmpty) continue;
      request.files.add(await http.MultipartFile.fromPath('supporting_documents[$i]', path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    return response.statusCode >= 200 && response.statusCode < 300;
  }
}
