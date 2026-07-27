import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_constants.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({this.baseUrl = ApiConstants.baseUrl});

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }
}
