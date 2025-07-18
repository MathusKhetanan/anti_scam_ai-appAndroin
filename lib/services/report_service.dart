import 'dart:convert';
import 'package:http/http.dart' as http;

class ReportService {
  final String _apiUrl = 'http://localhost:3000/api/report'; // เปลี่ยน URL ตามต้องการ
  final bool useMock = true; // ถ้า true จะไม่ส่งจริง ใช้ mock แทน

  Future<bool> sendReport(String phone, String reason) async {
    if (useMock) {
      // MOCK การส่งรายงาน (จำลอง)
      await Future.delayed(const Duration(seconds: 1));
      print('รายงาน (mock): เบอร์: $phone เหตุผล: $reason');
      return true; // แกล้งตอบว่าสำเร็จ
    } else {
      try {
        final res = await http.post(
          Uri.parse(_apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone, 'reason': reason}),
        );
        return res.statusCode == 200;
      } catch (e) {
        print('Error sending report: $e');
        return false;
      }
    }
  }
}
