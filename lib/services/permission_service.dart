import 'package:flutter/services.dart';

class PermissionService {
  static const MethodChannel _methodChannel = MethodChannel('message_monitor');

  // ตรวจสอบสถานะสิทธิ์ทั้งหมด (sms, notification, accessibility)
  static Future<Map<String, bool>> checkPermissions() async {
    try {
      final Map permissions = await _methodChannel.invokeMethod('checkPermissions');
      return permissions.cast<String, bool>();
    } catch (e) {
      return {
        'sms': false,
        'notification': false,
        'accessibility': false,
      };
    }
  }

  // ขอสิทธิ์ SMS
  static Future<bool> requestSmsPermission() async {
    try {
      final bool granted = await _methodChannel.invokeMethod('requestSmsPermission');
      return granted;
    } catch (e) {
      return false;
    }
  }

  // ตรวจสอบว่า Notification Access ได้รับสิทธิ์หรือยัง (ผ่าน checkPermissions)
  static Future<bool> isNotificationPermissionGranted() async {
    try {
      final Map<String, bool> permissions = await checkPermissions();
      return permissions['notification'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // เปิดหน้าตั้งค่าการเข้าถึง Notification
  static Future<bool> openNotificationSettings() async {
    try {
      final bool result = await _methodChannel.invokeMethod('requestNotificationPermission');
      return result;
    } catch (e) {
      return false;
    }
  }

  // (ถ้าต้องการ) ขอสิทธิ์ Accessibility
  static Future<bool> requestAccessibilityPermission() async {
    try {
      final bool result = await _methodChannel.invokeMethod('requestAccessibilityPermission');
      return result;
    } catch (e) {
      return false;
    }
  }

  // เปิดหน้าตั้งค่าแอป
  static Future<bool> openAppSettings() async {
    try {
      final bool result = await _methodChannel.invokeMethod('openAppSettings');
      return result;
    } catch (e) {
      return false;
    }
  }
}
