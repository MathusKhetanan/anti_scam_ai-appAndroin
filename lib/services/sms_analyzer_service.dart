import 'package:telephony/telephony.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'model_service.dart';  // ไฟล์ที่คุณสร้างโหลดโมเดลและวิเคราะห์ข้อความ

class SmsAnalyzerService {
  final Telephony _telephony = Telephony.instance;
  final ModelService _modelService;

  SmsAnalyzerService(this._modelService);

  /// เรียกขอ permission และดึง SMS พร้อมวิเคราะห์
  Future<void> fetchAndAnalyzeSMS() async {
    bool granted = await _telephony.requestPhoneAndSmsPermissions;
    if (!granted) {
      print("ไม่มีสิทธิ์อ่าน SMS");
      return;
    }

    List<SmsMessage> messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [
        OrderBy(SmsColumn.DATE, sort: Sort.DESC),
      ],
      // limit: 50, // ถ้าต้องการจำกัดจำนวน SMS
    );

    for (var msg in messages) {
      final text = msg.body ?? "";
      final isScam = await _modelService.analyze(text);
      if (isScam) {
        print("พบข้อความมิจฉาชีพ: $text");
        _showNotification(msg.address ?? "ไม่ทราบเบอร์", text);
      }
    }
  }

  /// แสดงแจ้งเตือนเมื่อพบ SMS มิจฉาชีพ
  void _showNotification(String sender, String message) {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique id
        channelKey: 'basic_channel',  // ต้องกำหนด channel ไว้ใน main app
        title: 'ข้อความมิจฉาชีพจาก $sender',
        body: message.length > 100 ? '${message.substring(0, 100)}...' : message,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }
}
