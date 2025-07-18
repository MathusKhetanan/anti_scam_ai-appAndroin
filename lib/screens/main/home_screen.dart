import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:anti_scam_ai/services/gemini_api.dart';

// ฟังก์ชันสำหรับประมวลผลใน Isolate (ต้องอยู่นอก class)
Future<List<Map<String, String>>> isolateSMSProcessing(
    Map<String, dynamic> params) async {
  final List<Map<String, dynamic>> messagesData = 
      List<Map<String, dynamic>>.from(params['messages']);
  final Map<String, Map<String, String>> cache = 
      Map<String, Map<String, String>>.from(params['cache'] ?? {});
  
  final List<Map<String, String>> results = [];

  for (final msgData in messagesData) {
    final content = msgData['body'] as String? ?? '';
    if (content.trim().isEmpty) continue;

    // ตรวจสอบ cache ก่อน
    if (cache.containsKey(content)) {
      results.add(Map<String, String>.from(cache[content]!));
      continue;
    }

    try {
      // เรียก Gemini API
      final analysis = await GeminiApi.analyzeMessageWithReason(content);
      final isScam = analysis['isScam'] as bool? ?? false;
      final reason = analysis['reason'] as String? ?? 'ไม่สามารถวิเคราะห์ได้';

      final result = {
        'time': _formatMessageTimeFromTimestamp(msgData['date'] as int?),
        'content': content,
        'result': isScam ? 'Scam' : 'Safe',
        'reason': reason,
        'app': 'SMS',
      };

      results.add(result);
    } catch (e) {
      final result = {
        'time': _formatMessageTimeFromTimestamp(msgData['date'] as int?),
        'content': content,
        'result': 'Unknown',
        'reason': 'ไม่สามารถวิเคราะห์ได้: การเชื่อมต่อมีปัญหา',
        'app': 'SMS',
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
    _loadInitialData();
    if (!kIsWeb) {
      _initAccessibilityListener();
    }
  }

  @override
  void dispose() {
    _saveCache();
    super.dispose();
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
    if (_loadingAI) return;

    setState(() {
      _loadingAI = true;
    });

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

      await _loadSMSDataOptimized();
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingAI = false);
      }
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
          'reason': 'ข้อความทดสอบบนเว็บ',
          'app': 'Web Demo',
        },
        {
          'time': '09:30',
          'content': 'ข้อความปลอดภัยตัวอย่าง',
          'result': 'Safe',
          'reason': 'ไม่มีปัญหา',
          'app': 'Web Demo',
        },
        {
          'time': '08:00',
          'content': 'ข้อความต้องสงสัยตัวอย่าง',
          'result': 'Scam',
          'reason': 'ข้อความทดสอบอีกอัน',
          'app': 'Web Demo',
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
      final batchResults = await _processSMSBatchWithCache(batch);
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

  // ประมวลผล SMS แบบใช้ cache
  Future<List<Map<String, String>>> _processSMSBatchWithCache(
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
        final analysis = await GeminiApi.analyzeMessageWithReason(content);
        final isScam = analysis['isScam'] as bool? ?? false;
        final reason = analysis['reason'] as String? ?? 'ไม่สามารถวิเคราะห์ได้';

        final result = {
          'time': _formatMessageTime(msg.date),
          'content': content,
          'result': isScam ? 'Scam' : 'Safe',
          'reason': reason,
          'app': 'SMS',
        };

        // เพิ่มเข้า cache
        _scanCache[content] = result;
        results.add(result);
      } catch (e) {
        debugPrint('Error analyzing message: $e');
        final result = {
          'time': _formatMessageTime(msg.date),
          'content': content,
          'result': 'Unknown',
          'reason': 'ไม่สามารถวิเคราะห์ได้: การเชื่อมต่อมีปัญหา',
          'app': 'SMS',
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

          if (scamText.isNotEmpty && mounted) {
            setState(() {
              scamAlertsFromAccessibility.add('[$appPackage] $scamText');
              recentScans.insert(0, {
                'time': TimeOfDay.now().format(context),
                'content': scamText,
                'result': 'Scam',
                'reason': 'ข้อความแจ้งเตือนจาก Accessibility Service',
                'app': appPackage,
              });
            });
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
    if (_loadingAI) return;

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
        final additionalResults = await _processSMSBatchWithCache(messagesToProcess);
        
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
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'scan', child: Text('ตรวจสอบ')),
              PopupMenuItem(value: 'stats', child: Text('สถิติ')),
              PopupMenuItem(value: 'settings', child: Text('ตั้งค่า')),
              PopupMenuItem(value: 'clear_cache', child: Text('ล้างแคช')),
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
                    'กำลังประมวลผลข้อความ...',
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
              onRefresh: _loadInitialData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(),
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

    if (!protectionEnabled) {
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
          onPressed: _loadingAI ? null : _loadInitialData,
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
          onPressed: _loadingAI ? null : _loadMoreMessages,
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
                    child: Icon(
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
                      size: 20,
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
                child: Text(
                  item['reason'] ?? '',
                  style: GoogleFonts.kanit(fontSize: 13),
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