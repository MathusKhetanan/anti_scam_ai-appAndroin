import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _methodChannel = MethodChannel('com.papkung.antiscamai/methods');
  static const EventChannel _eventChannel = EventChannel('com.papkung.antiscamai/accessibility');

  Future<bool> requestPermissions() async {
    try {
      final bool granted = await _methodChannel.invokeMethod('requestPermissions');
      return granted;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkNotificationPermission() async {
    try {
      final bool enabled = await _methodChannel.invokeMethod('checkNotificationPermission');
      return enabled;
    } catch (e) {
      return false;
    }
  }

  void openNotificationSettings() {
    _methodChannel.invokeMethod('openNotificationSettings');
  }

  void openAppSettings() {
    _methodChannel.invokeMethod('openAppSettings');
  }

  Stream<dynamic> get accessibilityEvents {
    return _eventChannel.receiveBroadcastStream();
  }
}
