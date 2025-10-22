import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fixitzed_app/core/api.dart';

class CategoryService {
  Future<List<dynamic>> getCategories() async {
    final response = await http.get(
      Uri.parse('${Api.baseUrl}/categories?per_page=100'),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded.containsKey('data')) {
        final data = decoded['data'];
        if (data is List) return data;
      }
      return const [];
    } else {
      throw Exception('Failed to load categories');
    }
  }
}
