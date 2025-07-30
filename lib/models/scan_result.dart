class ScanResult {
  final String id;         // รหัสข้อความ (หรือ timestamp)
  final String sender;     // เบอร์ผู้ส่ง
  final String message;    // เนื้อความ SMS
  final bool isScam;       // วิเคราะห์ว่าเป็นมิจฉาชีพหรือไม่
  final DateTime dateTime; // วันที่รับข้อความ

  ScanResult({
    required this.id,
    required this.sender,
    required this.message,
    required this.isScam,
    required this.dateTime,
  });
}
