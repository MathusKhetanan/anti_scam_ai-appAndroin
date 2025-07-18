import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiApi {
  static const String apiKey = 'AIzaSyC_CG-QfTA03-rPY_FVlDTciwg38LE1sRg';
  static const String model = 'gemini-1.5-pro';
  static final String endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

  /// เรียก API เพื่อวิเคราะห์ว่าเป็นสแกมหรือไม่ พร้อมเหตุผลประกอบ (Explainable)
  /// คืนค่า Map<String, dynamic> ที่มี 'isScam' เป็น bool และ 'reason' เป็น String
  static Future<Map<String, dynamic>> analyzeMessageWithReason(String inputText) async {
    final prompt = '''
ข้อความนี้เป็นสแกมหรือไม่: "$inputText"
ตอบกลับเป็น JSON ในรูปแบบนี้:
{
  "isScam": "ใช่" หรือ "ไม่ใช่",
  "reason": "เหตุผลที่คิดว่าข้อความนี้เป็นสแกมหรือปลอดภัย"
}
''';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final rawText = data['candidates'][0]['content']['parts'][0]['text'] as String;

      // หา JSON ในข้อความที่ได้ (AI อาจตอบแบบมีข้อความอื่นปน)
      final jsonStart = rawText.indexOf('{');
      final jsonEnd = rawText.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
        final jsonString = rawText.substring(jsonStart, jsonEnd + 1);
        final Map<String, dynamic> result = jsonDecode(jsonString);

        return {
          'isScam': result['isScam']?.trim() == 'ใช่',
          'reason': result['reason']?.trim() ?? 'ไม่มีเหตุผลจากระบบ'
        };
      } else {
        throw Exception('ไม่พบ JSON ในคำตอบของ AI: $rawText');
      }
    } else {
      throw Exception('Gemini API error (${response.statusCode}): ${response.body}');
    }
  }
}
