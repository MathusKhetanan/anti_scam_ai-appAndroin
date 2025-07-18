
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'anti_scam_alerts',
          channelName: 'Anti-Scam Alerts',
          channelDescription: 'แจ้งเตือนเมื่อพบข้อความต้องสงสัย',
          defaultColor: const Color(0xFFf44336),
          importance: NotificationImportance.High,
        )
      ],
      debug: true,
    );
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'anti_scam_alerts',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }
}
