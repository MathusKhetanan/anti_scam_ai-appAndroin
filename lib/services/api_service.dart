// lib/services/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://backend-api-j5m6.onrender.com';
  static const String _predict = '/predict';
  static const String _predictBatch = '/predict/batch';
  static const String _healthz = '/healthz';

  // flutter run --dart-define=API_KEY=your-secret
  static const String _apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: 'my-secret-key',
  );

  // ปรับ timeout ได้จากที่เดียว
  static const Duration _timeout = Duration(seconds: 45);

  static Map<String, String> _headers({bool jsonBody = true}) => {
        if (jsonBody) 'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_apiKey.isNotEmpty) 'X-API-Key': _apiKey,
      };

  /// ✅ Health check
  static Future<bool> testConnection() async {
    final url = Uri.parse('$baseUrl$_healthz');
    try {
      if (kDebugMode) debugPrint('🌐 Checking API health at $url');
      final res = await http
          .get(url, headers: _headers(jsonBody: false))
          .timeout(const Duration(seconds: 10));
      if (kDebugMode) debugPrint('📥 Health: ${res.statusCode} ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Connection test failed: $e');
      return false;
    }
  }

  /// 🔍 วิเคราะห์ข้อความเดี่ยว
  static Future<Map<String, dynamic>> checkMessage(String message) async {
    final url = Uri.parse('$baseUrl$_predict');
    try {
      if (kDebugMode) debugPrint('🌐 POST $url');
      final res = await http
          .post(url,
              headers: _headers(), body: jsonEncode({'message': message}))
          .timeout(_timeout);

      if (kDebugMode) debugPrint('📥 ${res.statusCode} ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final label = data['label'] as String?;
        final score = (data['score'] as num?)?.toDouble();
        return {
          'success': true,
          'label': label,
          'isScam': label == 'scam',
          'score': score,
          'threshold': (data['threshold'] as num?)?.toDouble(),
          'explanation': data['explanation'],
          'meta': data['meta'],
        };
      }

      if (res.statusCode == 401) {
        return {
          'success': false,
          'error': 'Unauthorized: ตรวจสอบ X-API-Key ให้ถูกต้อง'
        };
      }

      // พยายามอ่าน body เผื่อฝั่ง server ส่ง detail
      try {
        final body = jsonDecode(res.body);
        return {'success': false, 'error': 'HTTP ${res.statusCode}: $body'};
      } catch (_) {
        return {
          'success': false,
          'error': 'HTTP ${res.statusCode}: ${res.body}'
        };
      }
    } on FormatException catch (e) {
      // กรณี body ไม่ใช่ JSON
      return {'success': false, 'error': 'Invalid JSON response: $e'};
    } catch (e) {
      if (kDebugMode) debugPrint('❌ API Error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// 📦 วิเคราะห์ข้อความแบบชุด (batch)
  /// ส่งกลับรายการผลลัพธ์เหมือน /predict/batch ของฝั่ง FastAPI
  static Future<Map<String, dynamic>> checkMessagesBatch(
    List<String> messages, {
    bool explain = true,
  }) async {
    final url = Uri.parse('$baseUrl$_predictBatch');
    try {
      if (kDebugMode) debugPrint('🌐 POST $url (batch ${messages.length})');
      final res = await http
          .post(
            url,
            headers: _headers(),
            body: jsonEncode({'messages': messages, 'explain': explain}),
          )
          .timeout(_timeout);

      if (kDebugMode) debugPrint('📥 ${res.statusCode} ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return {
          'success': true,
          'results': data['results'],
          'meta': data['meta'],
        };
      }

      if (res.statusCode == 401) {
        return {
          'success': false,
          'error': 'Unauthorized: ตรวจสอบ X-API-Key ให้ถูกต้อง'
        };
      }

      try {
        final body = jsonDecode(res.body);
        return {'success': false, 'error': 'HTTP ${res.statusCode}: $body'};
      } catch (_) {
        return {
          'success': false,
          'error': 'HTTP ${res.statusCode}: ${res.body}'
        };
      }
    } on FormatException catch (e) {
      return {'success': false, 'error': 'Invalid JSON response: $e'};
    } catch (e) {
      if (kDebugMode) debugPrint('❌ API Error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
}
