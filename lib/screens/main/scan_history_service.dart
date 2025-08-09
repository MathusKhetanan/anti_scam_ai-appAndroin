import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result.dart';

class ScanHistoryService {
  static const String key = 'scan_history';

  /// เพิ่มประวัติใหม่
  static Future<void> addScanResult(ScanResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(key) ?? [];
    history.add(jsonEncode(result.toJson()));
    await prefs.setStringList(key, history);
  }

  /// ดึงประวัติทั้งหมด
  static Future<List<ScanResult>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(key) ?? [];
    return history.map((e) => ScanResult.fromJson(jsonDecode(e))).toList();
  }

  /// ลบประวัติทั้งหมด
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
