import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';

class CategoryService {
  Future<List<dynamic>> getCategories() async {
    final response = await http.get(Uri.parse("${Api.baseUrl}/categories"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to load categories");
    }
  }
}
