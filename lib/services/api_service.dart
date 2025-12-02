// ฟังก์ชันยิงรูปไป Colab อยู่ในนี้
// services/api_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiService {
  static Future<http.Response> uploadImage(File imageFile) async {
    final uri = Uri.parse('$backendBaseUrl/analyze');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }
}
