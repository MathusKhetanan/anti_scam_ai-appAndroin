import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import '../models/scan_result.dart';
import '../../services/api_service.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum TimeWindow { today, sevenDays, all }

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final Telephony telephony = Telephony.instance;

  // Debounce สำหรับการเซฟแคช
  Timer? _saveDebounce;
  void _saveCacheDebounced() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), _saveCache);
  }

  // สถิติ (สรุปตามช่วงที่เลือก)
  int messagesCheckedToday = 0;
  int scamDetectedToday = 0;
  int safeMessagesToday = 0;

  // Cache
  Map<String, ScanResult> _scanCache = {};
  SharedPreferences? _prefs;

  // Animation Controllers
  late AnimationController _refreshController;
  late AnimationController _statsController;

  // ตัวกรองช่วงเวลา
  TimeWindow selectedWindow = TimeWindow.today;

  // รับอีเวนต์จาก native background
  static const EventChannel bgUpdatesChannel =
      EventChannel('com.example.anti_scam_ai/bg_updates');
  StreamSubscription<dynamic>? _bgSub;
  List<ScanResult> scanResults = [];
  bool isLoading = false;
  bool protectionEnabled = true;
  bool modelReady = false;
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initCache();
    _loadModelAndData();
    _listenForBackgroundUpdates();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _bgSub?.cancel();
    _refreshController.dispose();
    _statsController.dispose();
    _saveCache(); // บันทึกล่าสุดก่อนปิด
    super.dispose();
  }

  // ---------- Time window helpers ----------
  List<ScanResult> _applyWindow(List<ScanResult> list) {
    final now = DateTime.now();
    switch (selectedWindow) {
      case TimeWindow.today:
        return list
            .where((e) =>
                e.dateTime.year == now.year &&
                e.dateTime.month == now.month &&
                e.dateTime.day == now.day)
            .toList();
      case TimeWindow.sevenDays:
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        return list.where((e) => e.dateTime.isAfter(sevenDaysAgo)).toList();
      case TimeWindow.all:
        return List.of(list);
    }
  }

  String _windowLabel(TimeWindow w) {
    switch (w) {
      case TimeWindow.today:
        return 'วันนี้';
      case TimeWindow.sevenDays:
        return '7 วัน';
      case TimeWindow.all:
        return 'ทั้งหมด';
    }
  }

  // ---------- Background updates ----------
  void _listenForBackgroundUpdates() {
    _bgSub = bgUpdatesChannel.receiveBroadcastStream().listen((event) {
      try {
        if (event is! Map<Object?, Object?>) return;

        // ทนทานกับ timestamp ได้หลายรูปแบบ
        final rawTs = event['timestamp'];
        int tsMs;
        if (rawTs is int) {
          tsMs = rawTs < 1000000000000 ? rawTs * 1000 : rawTs;
        } else if (rawTs is double) {
          final v = rawTs.round();
          tsMs = v < 1000000000000 ? v * 1000 : v;
        } else if (rawTs is String) {
          final asInt = int.tryParse(rawTs);
          if (asInt != null) {
            tsMs = asInt < 1000000000000 ? asInt * 1000 : asInt;
          } else {
            final iso = DateTime.tryParse(rawTs);
            tsMs = iso?.millisecondsSinceEpoch ??
                DateTime.now().millisecondsSinceEpoch;
          }
        } else {
          tsMs = DateTime.now().millisecondsSinceEpoch;
        }

        final dt = DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: false);

        final r = ScanResult(
          id: (event['id']?.toString().isNotEmpty == true)
              ? event['id'].toString()
              : tsMs.toString(),
          sender: event['sender']?.toString() ?? 'ไม่ทราบเบอร์',
          message: event['message']?.toString() ?? '',
          prediction: event['label']?.toString() ?? 'safe',
          isScam: event['isScam'] == true,
          score: double.tryParse('${event['score'] ?? '0'}') ?? 0.0,
          probability: double.tryParse('${event['score'] ?? '0'}') ?? 0.0,
          timestamp: dt,
          dateTime: dt,
          reason: 'ตรวจจาก Background',
          label: event['label']?.toString() ?? 'safe',
        );

        if (!mounted) return;

        final key = _keyFor(r);
        if (_scanCache.containsKey(key)) return; // กันซ้ำ

        setState(() {
          scanResults.insert(0, r);
          if (scanResults.length > 400) scanResults.removeLast();
          _scanCache[key] = r;
          _recomputeStatsFrom(scanResults);
        });

        // ใช้ Debounce เพื่อลดการเขียน SharedPreferences ถี่เกิน
        _saveCacheDebounced();
      } catch (e, st) {
        debugPrint('BG parse error: $e\n$st');
      }
    }, onError: (err) {
      debugPrint('Background update error: $err');
    });
  }

  void _initAnimations() {
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  // ---------- Helpers ----------
  void _recomputeStatsFrom(List<ScanResult> list) {
    final window = _applyWindow(list);
    final scam = window.where((e) => e.isScam).length;

    messagesCheckedToday = window.length;
    scamDetectedToday = scam;
    safeMessagesToday = window.length - scam;
  }

  String _keyFor(ScanResult r) {
    final content = '${r.sender}|${r.message}'.trim();
    if (content.isNotEmpty) {
      return sha1.convert(utf8.encode(content)).toString(); // กันซ้ำด้วยเนื้อหา
    }
    if (r.id.isNotEmpty) return r.id; // fallback
    return sha1
        .convert(utf8.encode(
            '${r.timestamp.millisecondsSinceEpoch}|${r.label}|${r.score}'))
        .toString();
  }

  List<ScanResult> _dedupeByKey(List<ScanResult> list) {
    final seen = <String>{};
    final out = <ScanResult>[];
    for (final r in list) {
      final k = _keyFor(r);
      if (seen.add(k)) out.add(r);
    }
    return out;
  }

  // ---------- Cache ----------
  Future<void> _initCache() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final cacheString = _prefs?.getString('sms_scan_cache') ?? '{}';
      final cacheData = json.decode(cacheString) as Map<String, dynamic>;

      _scanCache = {};
      cacheData.forEach((k, v) {
        final d = Map<String, dynamic>.from(v);
        _scanCache[k] = ScanResult(
          id: d['id'] ?? '',
          sender: d['sender'] ?? '',
          message: d['message'] ?? '',
          prediction: d['prediction'] ?? 'safe',
          isScam: d['isScam'] ?? false,
          timestamp: DateTime.tryParse(d['timestamp'] ?? '') ?? DateTime.now(),
          dateTime: DateTime.tryParse(d['dateTime'] ?? '') ?? DateTime.now(),
          score: (d['score'] is num) ? (d['score'] as num).toDouble() : 0.0,
          reason: d['reason'] ?? '',
          probability: (d['probability'] is num)
              ? (d['probability'] as num).toDouble()
              : 0.0,
          label: d['label']?.toString() ?? 'safe',
        );
      });

      final cachedList = _scanCache.values.toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

      if (mounted) {
        setState(() {
          scanResults = cachedList;
          _recomputeStatsFrom(cachedList);
        });
      }
    } catch (e) {
      debugPrint('Error loading cache: $e');
      _scanCache = {};
    }
  }

  Future<void> _saveCache() async {
    try {
      _prefs ??= await SharedPreferences.getInstance(); // ensure ready

      final list = _scanCache.values.toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      final capped = list.take(400).toList();

      final map = <String, dynamic>{};
      for (final v in capped) {
        map[_keyFor(v)] = {
          'id': v.id,
          'sender': v.sender,
          'message': v.message,
          'prediction': v.prediction,
          'isScam': v.isScam,
          'timestamp': v.timestamp.toIso8601String(),
          'dateTime': v.dateTime.toIso8601String(),
          'score': v.score,
          'reason': v.reason,
          'probability': v.probability,
          'label': v.label,
        };
      }
      await _prefs!.setString('sms_scan_cache', json.encode(map));

      _scanCache = {for (final v in capped) _keyFor(v): v};
    } catch (e) {
      debugPrint('Error saving cache: $e');
    }
  }

  // ---------- Load & Analyze ----------
  Future<void> _loadModelAndData() async {
    if (isLoading) return;

    setState(() => isLoading = true);
    _refreshController
      ..reset()
      ..repeat();

    try {
      final connected = await ApiService.testConnection();
      setState(() => modelReady = connected);

      if (!connected) {
        _showError('ไม่สามารถเชื่อมต่อ API ได้');
      } else {
        await _loadAndAnalyzeSMS();
        _statsController.forward();
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      _refreshController.stop();
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadAndAnalyzeSMS() async {
    try {
      bool permissionGranted =
          (await telephony.requestPhoneAndSmsPermissions) ?? false;
      if (!permissionGranted) {
        permissionGranted = (await telephony.requestSmsPermissions) ?? false;
      }
      if (!permissionGranted) {
        _showError('ไม่ได้รับสิทธิ์เข้าถึง SMS');
        return;
      }

      if (!modelReady) {
        _showError('API ยังไม่พร้อมใช้งาน');
        return;
      }

      final inbox = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      );
      final messages = inbox
          .where((m) => (m.body ?? '').trim().isNotEmpty)
          .toList()
        ..sort((a, b) => (b.date ?? 0).compareTo(a.date ?? 0));
      final limited = messages.take(100).toList();

      if (!protectionEnabled) {
        final results = limited.map((msg) {
          final sender = msg.address ?? 'ไม่ทราบเบอร์';
          final text = msg.body ?? '';
          final date =
              DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0, isUtc: false);
          return ScanResult(
            id: '${msg.id ?? date.millisecondsSinceEpoch}',
            sender: sender,
            message: text,
            prediction: 'safe',
            probability: 0.0,
            timestamp: date,
            dateTime: date,
            isScam: false,
            score: 0.0,
            reason: 'ระบบป้องกันปิดอยู่',
            label: 'safe',
          );
        }).toList();

        final view = results..sort((a, b) => b.dateTime.compareTo(a.dateTime));
        if (mounted) {
          setState(() {
            scanResults = view;
            _recomputeStatsFrom(view);
          });
        }
        return;
      }

      // เตรียมและคิวข้อความใหม่
      final prepared = <ScanResult>[];
      final queue = <String>[];

      for (final msg in limited) {
        final sender = msg.address ?? 'ไม่ทราบเบอร์';
        final text = msg.body ?? '';
        final date =
            DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0, isUtc: false);

        final temp = ScanResult(
          id: '${msg.id ?? date.millisecondsSinceEpoch}',
          sender: sender,
          message: text,
          prediction: 'safe',
          probability: 0.0,
          timestamp: date,
          dateTime: date,
          isScam: false,
          score: 0.0,
          reason: 'กำลังวิเคราะห์...',
          label: 'safe',
        );

        final key = _keyFor(temp);
        if (_scanCache.containsKey(key)) {
          prepared.add(_scanCache[key]!);
        } else {
          prepared.add(temp);
          queue.add(text);
        }
      }

      if (queue.isNotEmpty) {
        final batch = await ApiService.checkMessagesBatch(queue, explain: true);
        if (batch['success'] == true) {
          final results =
              (batch['results'] as List).cast<Map<String, dynamic>>();
          int qi = 0;
          for (int i = 0; i < prepared.length; i++) {
            if (prepared[i].reason == 'กำลังวิเคราะห์...' &&
                qi < results.length) {
              final r = results[qi++];
              final label = (r['label']?.toString() ?? 'safe').toLowerCase();
              final score =
                  double.tryParse(r['score']?.toString() ?? '0') ?? 0.0;
              final built = prepared[i].copyWith(
                prediction: label,
                isScam: label == 'scam',
                score: score,
                probability: score,
                reason: 'AI API (${label.toUpperCase()})',
                label: label,
              );
              final k = _keyFor(built);
              _scanCache[k] = built;
              prepared[i] = built;
            }
          }
        } else {
          _showError('Batch API ล้มเหลว: ${batch['error']}');
        }
      }

      final cleaned = _dedupeByKey(prepared)
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

      if (mounted) {
        setState(() {
          scanResults = cleaned;
          _recomputeStatsFrom(cleaned);
        });
        _saveCacheDebounced();
      }
    } catch (e, stack) {
      _showError('เกิดข้อผิดพลาดในการโหลดข้อความ: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  // ---------- UI Helpers ----------
  void _showError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }
  }

  void _toggleProtection() {
    setState(() => protectionEnabled = !protectionEnabled);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          protectionEnabled ? 'เปิดระบบป้องกันแล้ว' : 'ปิดระบบป้องกันแล้ว',
        ),
        backgroundColor: protectionEnabled ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMessageDetail(ScanResult result) {
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
              _buildDetailRow('ผู้ส่ง:', result.sender),
              const SizedBox(height: 12),
              _buildDetailRow('ข้อความ:', result.message),
              const SizedBox(height: 12),
              _buildDetailRow('เวลา:', _formatDateTime(result.dateTime)),
              const SizedBox(height: 12),
              _buildDetailRow(
                  'คะแนนความเสี่ยง:', result.score.toStringAsFixed(3)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: result.isScam
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: result.isScam ? Colors.red : Colors.green,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      result.isScam ? Icons.warning : Icons.check_circle,
                      color: result.isScam ? Colors.red : Colors.green,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.isScam ? 'ข้อความต้องสงสัย' : 'ข้อความปลอดภัย',
                      style: GoogleFonts.kanit(
                        fontWeight: FontWeight.w600,
                        color: result.isScam ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
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
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: GoogleFonts.kanit(fontSize: 13),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final windowed = _applyWindow(scanResults);
    final total = windowed.length;
    final safe = windowed.where((e) => !e.isScam).length;
    final securityScore = total == 0 ? 100.0 : (safe / total) * 100.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Anti-Scam AI',
          style: GoogleFonts.kanit(fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              modelReady ? Icons.cloud_done : Icons.cloud_off,
              color: modelReady ? Colors.green : Colors.orange,
            ),
          ),
          IconButton(
            icon: Icon(
              protectionEnabled ? Icons.shield : Icons.shield_outlined,
              color: protectionEnabled ? Colors.green : Colors.grey,
            ),
            onPressed: _toggleProtection,
            tooltip: protectionEnabled ? 'ป้องกันเปิดอยู่' : 'ป้องกันปิดอยู่',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'ล้างแคช',
            onPressed: () async {
              setState(() {
                _scanCache.clear();
                scanResults = [];
                messagesCheckedToday =
                    scamDetectedToday = safeMessagesToday = 0;
              });
              await _prefs?.remove('sms_scan_cache');
              _showError('ล้างแคชแล้ว');
            },
          ),
          RotationTransition(
            turns: _refreshController,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: isLoading ? null : _loadModelAndData,
            ),
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingScreen()
          : RefreshIndicator(
              onRefresh: _loadModelAndData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(),
                    const SizedBox(height: 16),
                    _buildModelStatus(),
                    const SizedBox(height: 16),
                    _buildFilterBar(),
                    const SizedBox(height: 16),
                    _buildProtectionStatus(),
                    const SizedBox(height: 24),
                    _buildSecurityScore(securityScore),
                    const SizedBox(height: 24),
                    _buildStatsCards(),
                    const SizedBox(height: 24),
                    _buildRecentScansList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        const Icon(Icons.filter_alt),
        const SizedBox(width: 8),
        Text('ช่วงสรุป: ',
            style: GoogleFonts.kanit(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        DropdownButton<TimeWindow>(
          value: selectedWindow,
          items: const [
            DropdownMenuItem(value: TimeWindow.today, child: Text('วันนี้')),
            DropdownMenuItem(value: TimeWindow.sevenDays, child: Text('7 วัน')),
            DropdownMenuItem(value: TimeWindow.all, child: Text('ทั้งหมด')),
          ],
          onChanged: (w) {
            if (w == null) return;
            setState(() {
              selectedWindow = w;
              _recomputeStatsFrom(scanResults);
            });
          },
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_windowLabel(selectedWindow)} • $messagesCheckedToday รายการ',
            style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            modelReady
                ? 'กำลังประมวลผลข้อความ...'
                : 'กำลังทดสอบการเชื่อมต่อ API...',
            style: GoogleFonts.kanit(fontSize: 16),
          ),
          if (messagesCheckedToday > 0)
            Text(
              'ประมวลผลแล้ว $messagesCheckedToday ข้อความ (${_windowLabel(selectedWindow)})',
              style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'สวัสดีตอนเช้า'
        : hour < 17
            ? 'สวัสดีตอนบ่าย'
            : 'สวัสดีตอนเย็น';

    return Text(
      '👋 $greeting!',
      style: GoogleFonts.kanit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildModelStatus() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: modelReady ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: modelReady ? Colors.green : Colors.orange,
        ),
      ),
      child: Row(
        children: [
          Icon(
            modelReady ? Icons.cloud_done : Icons.cloud_off,
            color: modelReady ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            modelReady ? '✅ API พร้อมใช้งาน' : '⏳ กำลังเชื่อมต่อ API...',
            style: GoogleFonts.kanit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  modelReady ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionStatus() {
    String windowLabel = _windowLabel(selectedWindow);
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (!modelReady) {
      statusText = '⏳ API กำลังเชื่อมต่อ กรุณารอสักครู่';
      statusColor = Colors.orange;
      statusIcon = Icons.cloud_off;
    } else if (!protectionEnabled) {
      statusText = '❌ ระบบป้องกันปิดอยู่ กรุณาเปิดเพื่อความปลอดภัย';
      statusColor = Colors.red;
      statusIcon = Icons.shield_outlined;
    } else if (scamDetectedToday > 0) {
      statusText =
          '⚠️ ตรวจพบข้อความต้องสงสัย $scamDetectedToday รายการ ($windowLabel)';
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else {
      statusText =
          '✅ ระบบป้องกันกำลังทำงาน และยังไม่พบภัยอันตราย ($windowLabel)';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
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

  Widget _buildSecurityScore(double score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'คะแนนความปลอดภัย '
          '${selectedWindow == TimeWindow.today ? "วันนี้" : "(${_windowLabel(selectedWindow)})"}',
          style: GoogleFonts.kanit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: score / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            score >= 80
                ? Colors.green
                : score >= 50
                    ? Colors.orange
                    : Colors.red,
          ),
        ),
        const SizedBox(height: 4),
        Text('${score.toStringAsFixed(1)}%',
            style: GoogleFonts.kanit(fontSize: 14)),
      ],
    );
  }

  Widget _buildStatsCards() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: _buildStatCard(
          'ตรวจทั้งหมด (${_windowLabel(selectedWindow)})',
          messagesCheckedToday.toString(),
          Icons.message,
          Colors.blue,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _buildStatCard(
          'ต้องสงสัย',
          scamDetectedToday.toString(),
          Icons.warning,
          Colors.orange,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _buildStatCard(
          'ปลอดภัย',
          safeMessagesToday.toString(),
          Icons.check_circle,
          Colors.green,
        ),
      ),
    ],
  );
}


// หรือเวอร์ชัน responsive แบบเต็ม
  Widget _buildStatsCardsResponsive() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // กำหนด spacing ตามขนาดหน้าจอ
        double spacing = constraints.maxWidth > 600 ? 12.0 : 8.0;

        return Row(
          children: [
            Expanded(
              flex: 1,
              child: _buildStatCard(
                'ตรวจทั้งหมด (${_windowLabel(selectedWindow)})',
                messagesCheckedToday.toString(),
                Icons.message,
                Colors.blue,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              flex: 1,
              child: _buildStatCard(
                'ต้องสงสัย',
                scamDetectedToday.toString(),
                Icons.warning,
                Colors.orange,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              flex: 1,
              child: _buildStatCard(
                'ปลอดภัย',
                safeMessagesToday.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        );
      },
    );
  }

// แนะนำให้ปรับ _buildStatCard ด้วยเพื่อรองรับหน้าจอขนาดต่างๆ
  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // กำหนด font size ตามขนาดการ์ด
        double titleFontSize = constraints.maxWidth < 120 ? 12.0 : 14.0;
        double valueFontSize = constraints.maxWidth < 120 ? 18.0 : 24.0;
        double iconSize = constraints.maxWidth < 120 ? 20.0 : 24.0;

        return Card(
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(constraints.maxWidth < 120 ? 8.0 : 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: iconSize,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentScansList() {
    final windowed = _applyWindow(scanResults)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final scams = windowed.where((e) => e.isScam).toList();
    final safes = windowed.where((e) => !e.isScam).toList();

    final displayedScams = scams.take(20).toList();
    final displayedSafes = safes.take(20).toList();

    Widget buildSection(
        String title, Color color, List<ScanResult> data, IconData icon) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Text(
                    '$title (${data.length})',
                    style: GoogleFonts.kanit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (data.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'ไม่มีรายการ',
                    style: GoogleFonts.kanit(color: Colors.grey[600]),
                  ),
                )
              else
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: data.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final result = data[index];
                    final tileColor = result.isScam
                        ? Colors.red.withOpacity(0.06)
                        : Colors.green.withOpacity(0.06);
                    final borderColor =
                        result.isScam ? Colors.red : Colors.green;

                    return Container(
                      decoration: BoxDecoration(
                        color: tileColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor.withOpacity(0.3)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              result.isScam
                                  ? Icons.warning
                                  : Icons.check_circle,
                              color: borderColor,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              result.score.toStringAsFixed(2),
                              style: GoogleFonts.kanit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: borderColor,
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          result.sender,
                          style: GoogleFonts.kanit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              result.message,
                              style: GoogleFonts.kanit(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  _formatDateTime(result.dateTime),
                                  style: GoogleFonts.kanit(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: borderColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    result.isScam ? 'ต้องสงสัย' : 'ปลอดภัย',
                                    style: GoogleFonts.kanit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: borderColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _showMessageDetail(result),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ตรวจสอบล่าสุด',
              style:
                  GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              '${windowed.length} รายการ (${_windowLabel(selectedWindow)})',
              style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        buildSection('ต้องสงสัย', Colors.orange, displayedScams,
            Icons.warning_amber_rounded),
        const SizedBox(height: 12),
        buildSection(
            'ปลอดภัย', Colors.green, displayedSafes, Icons.verified_rounded),
      ],
    );
  }
}
