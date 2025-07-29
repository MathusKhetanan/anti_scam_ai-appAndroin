import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
// เปลี่ยนจาก GeminiApi เป็น SmsModelService
import 'package:anti_scam_ai/services/sms_model_service.dart';

// ฟังก์ชันสำหรับประมวลผลใน Isolate (ต้องอยู่นอก class)
Future<List<Map<String, String>>> isolateSMSProcessing(
    Map<String, dynamic> params) async {
  final List<Map<String, dynamic>> messagesData = 
      List<Map<String, dynamic>>.from(params['messages']);
  final Map<String, Map<String, String>> cache = 
      Map<String, Map<String, String>>.from(params['cache'] ?? {});
  
  final List<Map<String, String>> results = [];

  // สร้าง SmsModelService instance ใน isolate
  final SmsModelService modelService = SmsModelService();
  await modelService.loadModelAndTokenizer();

  for (final msgData in messagesData) {
    final content = msgData['body'] as String? ?? '';
    if (content.trim().isEmpty) continue;

    // ตรวจสอบ cache ก่อน
    if (cache.containsKey(content)) {
      results.add(Map<String, String>.from(cache[content]!));
      continue;
    }

    try {
      // เรียกโมเดล TFLite วิเคราะห์
      final double score = modelService.predict(content);
      final bool isScam = score > 0.5; // เกณฑ์ที่ 0.5
      final String reason = 'โมเดล AI วิเคราะห์ (คะแนน: ${score.toStringAsFixed(3)})';

      final result = {
        'time': _formatMessageTimeFromTimestamp(msgData['date'] as int?),
        'content': content,
        'result': isScam ? 'Scam' : 'Safe',
        'reason': reason,
        'app': 'SMS',
        'score': score.toStringAsFixed(3), // เพิ่มคะแนนเพื่อแสดงผล
      };

      results.add(result);
    } catch (e) {
      final result = {
        'time': _formatMessageTimeFromTimestamp(msgData['date'] as int?),
        'content': content,
        'result': 'Unknown',
        'reason': 'ไม่สามารถวิเคราะห์ได้: ${e.toString()}',
        'app': 'SMS',
        'score': '0.000',
      };
      results.add(result);
    }
  }

  return results;
}

// Helper function สำหรับ isolate
String _formatMessageTimeFromTimestamp(int? timestamp) {
  if (timestamp == null) return '--:--';
  return DateTime.fromMillisecondsSinceEpoch(timestamp)
      .toLocal()
      .toString()
      .substring(11, 16);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _methodChannel = MethodChannel('message_monitor');
  static const EventChannel accessibilityEventChannel =
      EventChannel('com.papkung.antiscamai/accessibility');

  bool protectionEnabled = true;
  int messagesCheckedToday = 0;
  bool _loadingAI = false;
  bool _modelReady = false;

  // เพิ่ม SmsModelService
  final SmsModelService _smsModelService = SmsModelService();

  final List<Map<String, String>> recentScans = [];
  final List<String> scamAlertsFromAccessibility = [];

  // ลดจำนวนข้อความเริ่มต้นเพื่อความเร็ว
  static const int MAX_MESSAGES_TO_PROCESS = 10;
  static const int BATCH_SIZE = 5;

  // Cache สำหรับเก็บผลลัพธ์ที่เคยประมวลผลแล้ว
  Map<String, Map<String, String>> _scanCache = {};
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initCache();
    _initModelAndLoadData(); // เปลี่ยนจาก _loadInitialData
    if (!kIsWeb) {
      _initAccessibilityListener();
    }
  }

  @override
  void dispose() {
    _saveCache();
    super.dispose();
  }

  // เพิ่มฟังก์ชันโหลดโมเดลและข้อมูล
  Future<void> _initModelAndLoadData() async {
    if (_loadingAI) return;

    setState(() {
      _loadingAI = true;
    });

    try {
      if (!kIsWeb) {
        // โหลดโมเดล TFLite
        await _smsModelService.loadModelAndTokenizer();
        setState(() => _modelReady = true);
      }

      await _loadInitialData();
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการโหลดโมเดล: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingAI = false);
      }
    }
  }

  // เริ่มต้น cache และโหลดจาก SharedPreferences
  Future<void> _initCache() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final cacheString = _prefs?.getString('sms_scan_cache') ?? '{}';
      final cacheData = json.decode(cacheString) as Map<String, dynamic>;
      _scanCache = cacheData.map((key, value) => 
          MapEntry(key, Map<String, String>.from(value)));
    } catch (e) {
      debugPrint('Error loading cache: $e');
      _scanCache = {};
    }
  }

  // บันทึก cache ลง SharedPreferences
  Future<void> _saveCache() async {
    try {
      final cacheString = json.encode(_scanCache);
      await _prefs?.setString('sms_scan_cache', cacheString);
    } catch (e) {
      debugPrint('Error saving cache: $e');
    }
  }

  // แก้ไข logic การขอ Permission
  Future<bool> _requestPermissions() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _methodChannel.invokeMethod('checkPermissions');

      final smsGranted = result?['sms'] == true;
      final phoneGranted = result?['phone'] == true;

      if (!smsGranted) {
        final granted = await _methodChannel.invokeMethod('requestSmsPermission');
        return granted == true;
      }
      return smsGranted && phoneGranted;
    } catch (e) {
      debugPrint('Permission request failed: $e');
      return false;
    }
  }

  Future<void> _loadInitialData() async {
    try {
      if (kIsWeb) {
        await _loadWebDemoData();
        return;
      }

      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        _showPermissionError();
        return;
      }

      if (_modelReady) {
        await _loadSMSDataOptimized();
      } else {
        _showError('โมเดล AI ยังไม่พร้อมใช้งาน');
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    }
  }

  Future<void> _loadWebDemoData() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    
    setState(() {
      messagesCheckedToday = 3;
      recentScans.clear();
      recentScans.addAll([
        {
          'time': '10:15',
          'content': 'นี่คือตัวอย่างข้อความสแกมบนเว็บ',
          'result': 'Scam',
          'reason': 'โมเดล AI วิเคราะห์ (คะแนน: 0.856)',
          'app': 'Web Demo',
          'score': '0.856',
        },
        {
          'time': '09:30',
          'content': 'ข้อความปลอดภัยตัวอย่าง',
          'result': 'Safe',
          'reason': 'โมเดล AI วิเคราะห์ (คะแนน: 0.123)',
          'app': 'Web Demo',
          'score': '0.123',
        },
        {
          'time': '08:00',
          'content': 'ข้อความต้องสงสัยตัวอย่าง',
          'result': 'Scam',
          'reason': 'โมเดล AI วิเคราะห์ (คะแนน: 0.789)',
          'app': 'Web Demo',
          'score': '0.789',
        },
      ]);
    });
  }

  // ใช้ compute() สำหรับประมวลผล SMS ใน background isolate
  Future<void> _loadSMSDataOptimized() async {
    final Telephony telephony = Telephony.instance;
    final List<SmsMessage> messages = await telephony
        .getInboxSms(columns: [SmsColumn.BODY, SmsColumn.DATE]);

    // จำกัดจำนวนข้อความที่จะประมวลผล
    final messagesToProcess = messages.take(MAX_MESSAGES_TO_PROCESS).toList();
    
    // แปลง SmsMessage เป็น Map เพื่อส่งไป isolate
    final messagesData = messagesToProcess.map((msg) => {
      'body': msg.body,
      'date': msg.date,
    }).toList();

    // เตรียมข้อมูลส่งไป isolate
    final params = {
      'messages': messagesData,
      'cache': _scanCache,
    };

    try {
      // ใช้ compute() เพื่อประมวลผลใน background
      final List<Map<String, String>> scans = 
          await compute(isolateSMSProcessing, params);

      // อัปเดต cache ด้วยผลลัพธ์ใหม่
      for (final scan in scans) {
        final content = scan['content'] ?? '';
        if (content.isNotEmpty && !_scanCache.containsKey(content)) {
          _scanCache[content] = scan;
        }
      }

      // บันทึก cache
      await _saveCache();

      if (mounted) {
        setState(() {
          messagesCheckedToday = scans.length;
          recentScans.clear();
          recentScans.addAll(scans);
        });
      }
    } catch (e) {
      debugPrint('Error in optimized SMS loading: $e');
      // fallback เป็นวิธีเดิม
      await _loadSMSDataFallback();
    }
  }

  // Fallback method สำหรับกรณีที่ compute() ไม่ทำงาน
  Future<void> _loadSMSDataFallback() async {
    final Telephony telephony = Telephony.instance;
    final List<SmsMessage> messages = await telephony
        .getInboxSms(columns: [SmsColumn.BODY, SmsColumn.DATE]);

    final messagesToProcess = messages.take(MAX_MESSAGES_TO_PROCESS).toList();
    List<Map<String, String>> scans = [];

    // ประมวลผลทีละชุดเพื่อไม่ให้ UI หยุดตอบสนอง
    for (int i = 0; i < messagesToProcess.length; i += BATCH_SIZE) {
      final batch = messagesToProcess.skip(i).take(BATCH_SIZE).toList();
      final batchResults = await _processSMSBatchWithTFLite(batch);
      scans.addAll(batchResults);

      // Progressive UI update
      if (mounted) {
        setState(() {
          messagesCheckedToday = scans.length;
          recentScans.clear();
          recentScans.addAll(scans);
        });
      }

      // หยุดพักเล็กน้อยเพื่อให้ UI ตอบสนอง
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // บันทึก cache
    await _saveCache();
  }

  // เปลี่ยนจาก _processSMSBatchWithCache เป็น _processSMSBatchWithTFLite
  Future<List<Map<String, String>>> _processSMSBatchWithTFLite(
      List<SmsMessage> messages) async {
    List<Map<String, String>> results = [];
    
    for (final msg in messages) {
      final content = msg.body ?? '';
      if (content.trim().isEmpty) continue;

      // ตรวจสอบ cache ก่อน
      if (_scanCache.containsKey(content)) {
        results.add(Map<String, String>.from(_scanCache[content]!));
        continue;
      }

      try {
        // เรียกโมเดล TFLite วิเคราะห์
        final double score = _smsModelService.predict(content);
        final bool isScam = score > 0.5; // เกณฑ์ที่ 0.5
        final String reason = 'โมเดล AI วิเคราะห์ (คะแนน: ${score.toStringAsFixed(3)})';

        final result = {
          'time': _formatMessageTime(msg.date),
          'content': content,
          'result': isScam ? 'Scam' : 'Safe',
          'reason': reason,
          'app': 'SMS',
          'score': score.toStringAsFixed(3),
        };

        // เพิ่มเข้า cache
        _scanCache[content] = result;
        results.add(result);
      } catch (e) {
        debugPrint('Error analyzing message with TFLite: $e');
        final result = {
          'time': _formatMessageTime(msg.date),
          'content': content,
          'result': 'Unknown',
          'reason': 'ไม่สามารถวิเคราะห์ได้: ${e.toString()}',
          'app': 'SMS',
          'score': '0.000',
        };
        _scanCache[content] = result;
        results.add(result);
      }
    }
    
    return results;
  }

  String _formatMessageTime(int? timestamp) {
    if (timestamp == null) return '--:--';
    return DateTime.fromMillisecondsSinceEpoch(timestamp)
        .toLocal()
        .toString()
        .substring(11, 16);
  }

  void _showPermissionError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ไม่ได้รับสิทธิ์เข้าถึง SMS หรือ โทรศัพท์'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _initAccessibilityListener() {
    accessibilityEventChannel.receiveBroadcastStream().listen(
      (event) {
        try {
          final Map<String, dynamic> data = Map<String, dynamic>.from(event);
          final String scamText = data['text'] ?? '';
          final String appPackage = data['app'] ?? 'unknown';

          if (scamText.isNotEmpty && mounted && _modelReady) {
            // วิเคราะห์ข้อความจาก accessibility service ด้วย TFLite
            try {
              final double score = _smsModelService.predict(scamText);
              final bool isScam = score > 0.5;
              
              if (isScam) {
                setState(() {
                  scamAlertsFromAccessibility.add('[$appPackage] $scamText');
                  recentScans.insert(0, {
                    'time': TimeOfDay.now().format(context),
                    'content': scamText,
                    'result': 'Scam',
                    'reason': 'โมเดル AI วิเคราะห์ (คะแนน: ${score.toStringAsFixed(3)})',
                    'app': appPackage,
                    'score': score.toStringAsFixed(3),
                  });
                });
              }
            } catch (e) {
              debugPrint('Error analyzing accessibility message: $e');
            }
          }
        } catch (e) {
          debugPrint('Error parsing accessibility event: $e');
        }
      },
      onError: (error) {
        debugPrint('Accessibility Event Channel Error: $error');
      },
    );
  }

  void _toggleProtection() {
    setState(() {
      protectionEnabled = !protectionEnabled;
    });
  }

  void _navigateToScan() => Navigator.pushNamed(context, '/scan');
  void _navigateToStats() => Navigator.pushNamed(context, '/stats');
  void _navigateToSettings() => Navigator.pushNamed(context, '/settings');

  // เพิ่มฟังก์ชันสำหรับโหลดข้อความเพิ่มเติม
  Future<void> _loadMoreMessages() async {
    if (_loadingAI || !_modelReady) return;

    setState(() {
      _loadingAI = true;
    });

    try {
      final Telephony telephony = Telephony.instance;
      final List<SmsMessage> messages = await telephony
          .getInboxSms(columns: [SmsColumn.BODY, SmsColumn.DATE]);

      // โหลดข้อความเพิ่มเติม (ข้ามที่โหลดไปแล้ว)
      final messagesToProcess = messages
          .skip(recentScans.length)
          .take(MAX_MESSAGES_TO_PROCESS)
          .toList();

      if (messagesToProcess.isNotEmpty) {
        final additionalResults = await _processSMSBatchWithTFLite(messagesToProcess);
        
        if (mounted) {
          setState(() {
            messagesCheckedToday += additionalResults.length;
            recentScans.addAll(additionalResults);
          });
        }
        
        await _saveCache();
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการโหลดข้อความเพิ่มเติม: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingAI = false);
      }
    }
  }

  // เพิ่มฟังก์ชันสำหรับล้าง cache
  Future<void> _clearCache() async {
    _scanCache.clear();
    await _prefs?.remove('sms_scan_cache');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ล้างแคชเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _resolveAppName(String? package) {
    if (package == null) return 'ไม่ทราบ';
    const appNames = {
      'com.linecorp.line': 'LINE',
      'com.facebook.orca': 'Messenger',
      'com.whatsapp': 'WhatsApp',
      'com.google.android.gm': 'Gmail',
      'com.android.messaging': 'ข้อความ',
      'com.sec.android.app.messaging': 'ข้อความ Samsung',
    };
    return appNames[package] ?? package;
  }

  @override
  Widget build(BuildContext context) {
    final scamsToday = recentScans.where((e) => e['result'] == 'Scam').length;
    final safeCount = recentScans.where((e) => e['result'] == 'Safe').length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Anti-Scam AI', style: GoogleFonts.kanit()),
        actions: [
          // แสดงสถานะโมเดล
          if (!_modelReady && !kIsWeb)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: const Icon(
                Icons.warning,
                color: Colors.orange,
              ),
            ),
          IconButton(
            icon: Icon(protectionEnabled ? Icons.shield : Icons.shield_outlined),
            onPressed: _toggleProtection,
            tooltip: protectionEnabled ? 'ป้องกันเปิดอยู่' : 'ป้องกันปิดอยู่',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'scan':
                  _navigateToScan();
                case 'stats':
                  _navigateToStats();
                case 'settings':
                  _navigateToSettings();
                case 'clear_cache':
                  _clearCache();
                case 'reload_model':
                  _initModelAndLoadData();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'scan', child: Text('ตรวจสอบ')),
              const PopupMenuItem(value: 'stats', child: Text('สถิติ')),
              const PopupMenuItem(value: 'settings', child: Text('ตั้งค่า')),
              const PopupMenuItem(value: 'clear_cache', child: Text('ล้างแคช')),
              const PopupMenuItem(value: 'reload_model', child: Text('โหลดโมเดลใหม่')),
            ],
          ),
        ],
      ),
      body: _loadingAI
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _modelReady 
                        ? 'กำลังประมวลผลข้อความ...'
                        : 'กำลังโหลดโมเดล AI...',
                    style: GoogleFonts.kanit(fontSize: 16),
                  ),
                  if (messagesCheckedToday > 0)
                    Text(
                      'ประมวลผลแล้ว $messagesCheckedToday ข้อความ',
                      style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey),
                    ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _initModelAndLoadData, // เปลี่ยนจาก _loadInitialData
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(),
                    const SizedBox(height: 16),
                    _buildModelStatus(), // เพิ่มสถานะโมเดล
                    const SizedBox(height: 16),
                    _buildRealTimeScamAlerts(),
                    const SizedBox(height: 16),
                    _buildProtectionStatus(scamsToday),
                    const SizedBox(height: 24),
                    _buildSecurityScore(scamsToday, safeCount),
                    const SizedBox(height: 24),
                    _buildScanButton(),
                    const SizedBox(height: 24),
                    _buildSummary(scamsToday, safeCount),
                    const SizedBox(height: 24),
                    _buildRecentScansList(),
                    const SizedBox(height: 16),
                    _buildLoadMoreButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGreeting() => Text(
        '👋 ยินดีต้อนรับกลับ!',
        style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.w600),
      );

  // เพิ่มแสดงสถานะโมเดล
  Widget _buildModelStatus() {
    if (kIsWeb) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _modelReady ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _modelReady ? Colors.green : Colors.orange,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _modelReady ? Icons.check_circle : Icons.hourglass_empty,
            color: _modelReady ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _modelReady 
                ? '✅ โมเดล AI พร้อมใช้งาน'
                : '⏳ กำลังโหลดโมเดล AI...',
            style: GoogleFonts.kanit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _modelReady ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeScamAlerts() {
    if (scamAlertsFromAccessibility.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🚨 แจ้งเตือนข้อความต้องสงสัย (เรียลไทม์)',
            style: GoogleFonts.kanit(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ...scamAlertsFromAccessibility.map(
            (text) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                text,
                style: GoogleFonts.kanit(fontSize: 13, color: Colors.red.shade900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionStatus(int scamsToday) {
    String statusText;
    Color statusColor;

    if (!_modelReady && !kIsWeb) {
      statusText = '⏳ โมเดล AI กำลังโหลด กรุณารอสักครู่';
      statusColor = Colors.orange;
    } else if (!protectionEnabled) {
      statusText = '❌ ระบบป้องกันปิดอยู่ กรุณาเปิดเพื่อความปลอดภัย';
      statusColor = Colors.red;
    } else if (scamsToday > 0) {
      statusText = '⚠️ ตรวจพบข้อความต้องสงสัย $scamsToday รายการ';
      statusColor = Colors.orange;
    } else {
      statusText = '✅ ระบบป้องกันกำลังทำงาน และไม่พบภัยอันตรายวันนี้';
      statusColor = Colors.green;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        children: [
          Icon(
            statusColor == Colors.green
                ? Icons.check_circle
                : (statusColor == Colors.orange ? Icons.warning : Icons.error),
            color: statusColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: GoogleFonts.kanit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityScore(int scamsToday, int safeCount) {
    final total = safeCount + scamsToday;
    final score = total == 0 ? 100 : (safeCount / total) * 100;
    final scoreColor =
        score > 80 ? Colors.green : (score > 50 ? Colors.orange : Colors.red);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.security, size: 40, color: scoreColor),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('คะแนนความปลอดภัยวันนี้',
                    style: GoogleFonts.kanit(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text('${score.toStringAsFixed(0)}%',
                    style: GoogleFonts.kanit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    )),
                if (!_modelReady && !kIsWeb)
                  Text('(โมเดลยังไม่พร้อม)',
                      style: GoogleFonts.kanit(
                          fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: Text('สแกนข้อความใหม่', style: GoogleFonts.kanit(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: (_loadingAI || (!_modelReady && !kIsWeb)) ? null : _initModelAndLoadData,
        ),
      );

  Widget _buildLoadMoreButton() => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.expand_more),
          label: Text('โหลดข้อความเพิ่มเติม', style: GoogleFonts.kanit(fontSize: 16)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: (_loadingAI || (!_modelReady && !kIsWeb)) ? null : _loadMoreMessages,
        ),
      );

  Widget _buildSummary(int scamsToday, int safeCount) => Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statTile('ตรวจทั้งหมด', '$messagesCheckedToday'),
              const SizedBox(width: 24),
              _statTile('ข้อความต้องสงสัย', '$scamsToday'),
              const SizedBox(width: 24),
              _statTile('ข้อความปลอดภัย', '$safeCount'),
              const SizedBox(width: 24),
              _statTile('แคชไว้', '${_scanCache.length}'),
              const SizedBox(width: 24),
              _statTile('โมเดล', _modelReady ? 'พร้อม' : 'รอ...'),
            ],
          ),
        ),
      ),
    );

  Widget _statTile(String label, String value) => Column(
      children: [
        Text(value,
            style: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(label,
            style: GoogleFonts.kanit(fontSize: 13, color: Colors.grey[700])),
      ],
    );

  Widget _buildRecentScansList() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ตรวจล่าสุด',
            style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        if (recentScans.isEmpty)
          Text(
            'ยังไม่มีการตรวจสอบวันนี้',
            style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey[600]),
          )
        else
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: recentScans.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = recentScans[index];
              final isScam = item['result'] == 'Scam';
              final isUnknown = item['result'] == 'Unknown';
              final score = double.tryParse(item['score'] ?? '0.0') ?? 0.0;
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: isScam 
                        ? Colors.red.withOpacity(0.2)
                        : isUnknown 
                            ? Colors.grey.withOpacity(0.2)
                            : Colors.green.withOpacity(0.2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isScam 
                              ? Icons.warning
                              : isUnknown 
                                  ? Icons.help_outline
                                  : Icons.check_circle,
                          color: isScam 
                              ? Colors.red
                              : isUnknown 
                                  ? Colors.grey
                                  : Colors.green,
                          size: 16,
                        ),
                        if (!isUnknown)
                          Text(
                            score.toStringAsFixed(2),
                            style: GoogleFonts.kanit(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: isScam ? Colors.red : Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ),
                  title: Text(
                    item['content'] ?? '',
                    style: GoogleFonts.kanit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        item['reason'] ?? '',
                        style: GoogleFonts.kanit(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${item['time']} • ${_resolveAppName(item['app'])}',
                            style: GoogleFonts.kanit(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isScam 
                                  ? Colors.red.withOpacity(0.1)
                                  : isUnknown 
                                      ? Colors.grey.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isScam 
                                    ? Colors.red.withOpacity(0.3)
                                    : isUnknown 
                                        ? Colors.grey.withOpacity(0.3)
                                        : Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              isScam 
                                  ? 'ต้องสงสัย'
                                  : isUnknown 
                                      ? 'ไม่ทราบ'
                                      : 'ปลอดภัย',
                              style: GoogleFonts.kanit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isScam 
                                    ? Colors.red
                                    : isUnknown 
                                        ? Colors.grey[700]
                                        : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _showMessageDetailDialog(context, item, isScam, isUnknown),
                ),
              );
            },
          ),
      ],
    );

  // แยกฟังก์ชัน dialog ออกมาเพื่อความเป็นระเบียบ
  void _showMessageDetailDialog(BuildContext context, Map<String, String> item, bool isScam, bool isUnknown) {
    final score = double.tryParse(item['score'] ?? '0.0') ?? 0.0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'รายละเอียดการตรวจสอบ',
          style: GoogleFonts.kanit(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ข้อความ:',
                style: GoogleFonts.kanit(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Text(
                  item['content'] ?? '',
                  style: GoogleFonts.kanit(fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ผลการวิเคราะห์:',
                style: GoogleFonts.kanit(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isScam 
                      ? Colors.red.withOpacity(0.1)
                      : isUnknown 
                          ? Colors.grey.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isScam 
                        ? Colors.red.withOpacity(0.3)
                        : isUnknown 
                            ? Colors.grey.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['reason'] ?? '',
                      style: GoogleFonts.kanit(fontSize: 13),
                    ),
                    if (!isUnknown) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.analytics,
                              size: 16,
                              color: isScam ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'คะแนนความเสี่ยง: ${score.toStringAsFixed(3)}',
                              style: GoogleFonts.kanit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isScam ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        score > 0.5 
                            ? 'คะแนน > 0.5 = ข้อความต้องสงสัย'
                            : 'คะแนน ≤ 0.5 = ข้อความปลอดภัย',
                        style: GoogleFonts.kanit(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow('เวลา:', item['time'] ?? '--:--'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailRow('แอป:', _resolveAppName(item['app'])),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildDetailRow('สถานะ:', isScam 
                  ? 'ต้องสงสัย'
                  : isUnknown 
                      ? 'ไม่ทราบ'
                      : 'ปลอดภัย'),
              if (_modelReady) ...[
                const SizedBox(height: 8),
                _buildDetailRow('วิธีการ:', 'โมเดล TensorFlow Lite'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'ปิด',
              style: GoogleFonts.kanit(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget สำหรับแสดงข้อมูลในรูปแบบแถว
  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.kanit(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.kanit(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}