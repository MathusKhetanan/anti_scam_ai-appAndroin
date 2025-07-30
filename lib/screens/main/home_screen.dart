import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/scan_result.dart';
import '../services/sms_model_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final Telephony telephony = Telephony.instance;
  List<ScanResult> scanResults = [];
  bool isLoading = false;
  bool protectionEnabled = true;
  bool modelReady = false;
  
  // สถิติ
  int messagesCheckedToday = 0;
  int scamDetectedToday = 0;
  int safeMessagesToday = 0;
  
  // Cache
  Map<String, ScanResult> _scanCache = {};
  SharedPreferences? _prefs;
  
  // Animation Controllers
  late AnimationController _refreshController;
  late AnimationController _statsController;
  
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initCache();
    _loadModelAndData();
  }
  
  @override
  void dispose() {
    _refreshController.dispose();
    _statsController.dispose();
    _saveCache();
    super.dispose();
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
  
  Future<void> _initCache() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final cacheString = _prefs?.getString('sms_scan_cache') ?? '{}';
      final cacheData = json.decode(cacheString) as Map<String, dynamic>;
      
      _scanCache = cacheData.map((key, value) {
        final data = Map<String, dynamic>.from(value);
        return MapEntry(key, ScanResult(
          id: data['id'] ?? '',
          sender: data['sender'] ?? '',
          message: data['message'] ?? '',
          isScam: data['isScam'] ?? false,
          dateTime: DateTime.parse(data['dateTime'] ?? DateTime.now().toIso8601String()),
          score: (data['score'] ?? 0.0).toDouble(),
          reason: data['reason'] ?? '',
        ));
      });
    } catch (e) {
      debugPrint('Error loading cache: $e');
      _scanCache = {};
    }
  }
  
  Future<void> _saveCache() async {
    try {
      final cacheData = _scanCache.map((key, value) => MapEntry(key, {
        'id': value.id,
        'sender': value.sender,
        'message': value.message,
        'isScam': value.isScam,
        'dateTime': value.dateTime.toIso8601String(),
        'score': value.score,
        'reason': value.reason,
      }));
      
      final cacheString = json.encode(cacheData);
      await _prefs?.setString('sms_scan_cache', cacheString);
    } catch (e) {
      debugPrint('Error saving cache: $e');
    }
  }
  
  Future<void> _loadModelAndData() async {
    if (isLoading) return;
    
    setState(() {
      isLoading = true;
    });
    
    _refreshController.repeat();
    
    try {
      // โหลดโมเดล AI
      await SMSModelService.instance.loadModel();
      setState(() => modelReady = true);
      
      // โหลดและวิเคราะห์ข้อความ
      await _loadAndAnalyzeSMS();
      
      _statsController.forward();
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการโหลดโมเดล: $e');
    } finally {
      _refreshController.stop();
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
  
  Future<void> _loadAndAnalyzeSMS() async {
    try {
      bool permissionGranted = await telephony.requestPhoneAndSmsPermissions;
      if (!permissionGranted) {
        _showError('ไม่ได้รับสิทธิ์เข้าถึง SMS');
        return;
      }
      
      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
        limit: 100,
      );
      
      List<ScanResult> results = [];
      int scamCount = 0;
      int safeCount = 0;
      
      for (var msg in messages) {
        final sender = msg.address ?? 'ไม่ทราบเบอร์';
        final text = msg.body ?? '';
        final date = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0);
        
        if (text.trim().isEmpty) continue;
        
        ScanResult result;
        
        // ตรวจสอบ cache ก่อน
        if (_scanCache.containsKey(text)) {
          result = _scanCache[text]!;
        } else {
          // วิเคราะห์ข้อความด้วย AI
          final analysisResult = await SMSModelService.instance.analyze(text);
          
          result = ScanResult(
            id: msg.id.toString(),
            sender: sender,
            message: text,
            isScam: analysisResult.isScam,
            dateTime: date,
            score: analysisResult.score,
            reason: 'โมเดล AI วิเคราะห์ (คะแนน: ${analysisResult.score.toStringAsFixed(3)})',
          );
          
          // เพิ่มเข้า cache
          _scanCache[text] = result;
        }
        
        results.add(result);
        
        if (result.isScam) {
          scamCount++;
        } else {
          safeCount++;
        }
      }
      
      if (mounted) {
        setState(() {
          scanResults = results;
          messagesCheckedToday = results.length;
          scamDetectedToday = scamCount;
          safeMessagesToday = safeCount;
        });
        
        await _saveCache();
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการโหลดข้อความ: $e');
    }
  }
  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _toggleProtection() {
    setState(() {
      protectionEnabled = !protectionEnabled;
    });
    
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
              _buildDetailRow('คะแนนความเสี่ยง:', result.score.toStringAsFixed(3)),
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
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    final securityScore = messagesCheckedToday == 0 
        ? 100.0 
        : (safeMessagesToday / messagesCheckedToday) * 100;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Anti-Scam AI',
          style: GoogleFonts.kanit(fontWeight: FontWeight.w600),
        ),
        actions: [
          // สถานะโมเดล
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Icon(
              modelReady ? Icons.smart_toy : Icons.hourglass_empty,
              color: modelReady ? Colors.green : Colors.orange,
            ),
          ),
          // ปุ่มป้องกัน
          IconButton(
            icon: Icon(
              protectionEnabled ? Icons.shield : Icons.shield_outlined,
              color: protectionEnabled ? Colors.green : Colors.grey,
            ),
            onPressed: _toggleProtection,
            tooltip: protectionEnabled ? 'ป้องกันเปิดอยู่' : 'ป้องกันปิดอยู่',
          ),
          // ปุ่มรีเฟรช
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
            modelReady ? Icons.check_circle : Icons.hourglass_empty,
            color: modelReady ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            modelReady 
                ? '✅ โมเดル AI พร้อมใช้งาน'
                : '⏳ กำลังโหลดโมเดล AI...',
            style: GoogleFonts.kanit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: modelReady 
                  ? Colors.green.shade800 
                  : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProtectionStatus() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (!modelReady) {
      statusText = '⏳ โมเดล AI กำลังโหลด กรุณารอสักครู่';
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    } else if (!protectionEnabled) {
      statusText = '❌ ระบบป้องกันปิดอยู่ กรุณาเปิดเพื่อความปลอดภัย';
      statusColor = Colors.red;
      statusIcon = Icons.shield_outlined;
    } else if (scamDetectedToday > 0) {
      statusText = '⚠️ ตรวจพบข้อความต้องสงสัย $scamDetectedToday รายการ';
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else {
      statusText = '✅ ระบบป้องกันกำลังทำงาน และไม่พบภัยอันตรายวันนี้';
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
    final scoreColor = score > 80 
        ? Colors.green 
        : score > 50 
            ? Colors.orange 
            : Colors.red;

    return FadeTransition(
      opacity: _statsController,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                scoreColor.withOpacity(0.1),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.security, size: 48, color: scoreColor),
              const SizedBox(height: 12),
              Text(
                'คะแนนความปลอดภัยวันนี้',
                style: GoogleFonts.kanit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${score.toStringAsFixed(0)}%',
                style: GoogleFonts.kanit(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatsCards() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _statsController,
        curve: Curves.easeOutCubic,
      )),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'ตรวจทั้งหมด',
              messagesCheckedToday.toString(),
              Icons.message,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'ต้องสงสัย',
              scamDetectedToday.toString(),
              Icons.warning,
              Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'ปลอดภัย',
              safeMessagesToday.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.kanit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.kanit(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentScansList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ตรวจสอบล่าสุด',
              style: GoogleFonts.kanit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (scanResults.isNotEmpty)
              Text(
                '${scanResults.length} รายการ',
                style: GoogleFonts.kanit(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (scanResults.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ยังไม่มีการตรวจสอบ',
                    style: GoogleFonts.kanit(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: scanResults.take(20).length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final result = scanResults[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: result.isScam 
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          result.isScam ? Icons.warning : Icons.check_circle,
                          color: result.isScam ? Colors.red : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.score.toStringAsFixed(2),
                          style: GoogleFonts.kanit(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: result.isScam ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
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
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: result.isScam 
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              result.isScam ? 'ต้องสงสัย' : 'ปลอดภัย',
                              style: GoogleFonts.kanit(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: result.isScam ? Colors.red : Colors.green,
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
    );
  }
}