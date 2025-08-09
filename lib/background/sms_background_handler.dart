// lib/background/sms_background_handler.dart
import 'package:flutter/services.dart';
import 'package:telephony/telephony.dart';
import '../services/api_service.dart';
import 'dart:developer' as dev;

const _bgNotify = MethodChannel('bg_notifier');

String _truncate(String s, {int max = 200}) {
  if (s.length <= max) return s;
  return s.substring(0, max) + '…';
}

@pragma('vm:entry-point')
Future<void> smsBackgroundHandler(SmsMessage message) async {
  try {
    final text = (message.body ?? '').trim();
    if (text.isEmpty) return;

    Map<String, dynamic> res = const {};
    try {
      final r = await ApiService.checkMessage(text);
      if (r is Map<String, dynamic>) res = r;
    } catch (e, st) {
      dev.log('API error: $e', name: 'sms_bg', stackTrace: st);
    }

    final label = (res['label'] ?? '').toString();
    final score = (res['score'] ?? 0).toString();
    final isScam = (res['isScam'] == true) || label.toLowerCase() == 'scam';

    dev.log(
      '[BG SMS] from=${message.address ?? "-"} label=$label score=$score text="${_truncate(text, max: 300)}"',
      name: 'sms_bg',
    );

    final title = isScam ? '🚨 ข้อความน่าสงสัย' : '✅ ข้อความปลอดภัย';
    final body =
        'จาก: ${message.address ?? "ไม่ทราบเบอร์"} • Label: ${label.isEmpty ? "-" : label.toUpperCase()} • Score: $score\n${_truncate(text)}';

    // ✅ ส่งให้ Native เด้ง notification + กระจาย Event ให้ Flutter แบบ real-time
    try {
      await _bgNotify.invokeMethod('notify', {
        'title': title,
        'body': body,
        // payload สำหรับ Flutter EventChannel
        'sender': message.address ?? 'ไม่ทราบเบอร์',
        'text': text,
        'label': label,
        'score': score,
        'isScam': isScam,
        'timestampMs': message.date ?? DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      dev.log('notify error: $e', name: 'sms_bg');
    }
  } catch (e, st) {
    dev.log('BG handler error: $e', name: 'sms_bg', stackTrace: st);
  }
}
