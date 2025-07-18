import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:anti_scam_ai/services/scam_detector.dart';
import 'package:intl/intl.dart';
import 'package:anti_scam_ai/services/gemini_api.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final Telephony telephony = Telephony.instance;

  // ตัวแปรสถานะ
  bool hasDataLoaded = false;
  bool isLoading = true;
  bool permissionDenied = false;
  bool hasError = false;
  String errorMessage = '';
  
  // ข้อมูลสถิติ
  int totalMessages = 0;
  int scamMessages = 0;
  int safeMessages = 0;
  int analyzedMessages = 0; // จำนวนข้อความที่วิเคราะห์แล้ว
  DateTime? lastUpdated;

  // เก็บผลการวิเคราะห์และ cache
  Map<int, Map<String, dynamic>> analysisResults = {};
  static Map<String, Map<String, dynamic>> _messageCache = {}; // Cache แบบ static

  // Constants
  static const String appBarTitle = 'สถิติการตรวจสอบ SMS';
  static const String permissionDeniedMessage = 'กรุณาอนุญาتการเข้าถึง SMS ในการตั้งค่าเพื่อดูสถิติ';
  static const String noMessagesText = 'ไม่มีข้อความ SMS ในกล่องข้อความ';
  static const String overviewTitle = 'ภาพรวม';
  static const String ratioTitle = 'สัดส่วนข้อความ';
  static const String totalMessagesLabel = 'จำนวนข้อความทั้งหมด';
  static const String scamMessagesLabel = 'ข้อความหลอกลวง (Scam)';
  static const String safeMessagesLabel = 'ข้อความปลอดภัย';
  static const String lastUpdatedLabel = 'อัพเดทล่าสุด';
  static const String refreshButtonText = 'รีเฟรช';
  static const String retryButtonText = 'ลองใหม่';

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndLoadSms();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset หากกลับเข้าหน้านี้และข้อมูลเก่าเกิน 5 นาที
    if (hasDataLoaded && lastUpdated != null) {
      final timeDiff = DateTime.now().difference(lastUpdated!);
      if (timeDiff.inMinutes > 5) {
        hasDataLoaded = false;
      }
    }
  }

  // สร้าง hash key สำหรับ cache
  String _generateMessageHash(String message) {
    var bytes = utf8.encode(message.trim().toLowerCase());
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _requestPermissionsAndLoadSms() async {
    try {
      bool? permissionsGranted = await telephony.requestSmsPermissions;
      if (permissionsGranted == true) {
        await _loadSms();
      } else {
        setState(() {
          permissionDenied = true;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'เกิดข้อผิดพลาดในการขอสิทธิ์: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _loadSms() async {
    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
      analyzedMessages = 0;
    });

    try {
      // โหลด SMS ล่าสุด 20 ข้อความ
      List<SmsMessage> messages = await telephony.getInboxSms(
        columns: [SmsColumn.BODY, SmsColumn.DATE],
      );

      final recentMessages = messages.take(20).toList();
      totalMessages = recentMessages.length;

      if (totalMessages == 0) {
        setState(() {
          isLoading = false;
          hasDataLoaded = true;
        });
        return;
      }

      // เตรียมข้อมูลสำหรับการวิเคราะห์
      List<Future<Map<String, dynamic>>> analysisJobs = [];
      List<String> messageBodies = [];
      List<String> messageHashes = [];

      for (int i = 0; i < recentMessages.length; i++) {
        final body = recentMessages[i].body ?? '';
        final hash = _generateMessageHash(body);
        
        messageBodies.add(body);
        messageHashes.add(hash);

        // ตรวจสอบ cache ก่อน
        if (_messageCache.containsKey(hash)) {
          // ใช้ข้อมูลจาก cache
          analysisJobs.add(Future.value(_messageCache[hash]!));
        } else {
          // สร้าง job สำหรับวิเคราะห์ใหม่
          analysisJobs.add(_analyzeMessage(body, hash, i));
        }
      }

      // วิเคราะห์ข้อความทั้งหมดพร้อมกัน (แต่จำกัดจำนวนเพื่อป้องกัน rate limit)
      const int batchSize = 5; // วิเคราะห์ครั้งละ 5 ข้อความ
      List<Map<String, dynamic>> results = [];

      for (int i = 0; i < analysisJobs.length; i += batchSize) {
        final batch = analysisJobs.skip(i).take(batchSize).toList();
        final batchResults = await Future.wait(batch);
        results.addAll(batchResults);

        // อัพเดท progress
        setState(() {
          analyzedMessages = results.length;
        });

        // หน่วงเวลาเล็กน้อยระหว่าง batch
        if (i + batchSize < analysisJobs.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // นับผลลัพธ์
      int scamCount = 0;
      int safeCount = 0;
      
      for (int i = 0; i < results.length; i++) {
        final result = results[i];
        final isScam = result['isScam'] as bool;
        
        if (isScam) {
          scamCount++;
        } else {
          safeCount++;
        }

        analysisResults[i] = result;
        
        // บันทึกลง cache
        final hash = messageHashes[i];
        _messageCache[hash] = result;
      }

      // อัพเดทข้อมูลสถิติ
      setState(() {
        scamMessages = scamCount;
        safeMessages = safeCount;
        lastUpdated = DateTime.now();
        hasDataLoaded = true;
        isLoading = false;
        analyzedMessages = results.length;
      });

      // ทำความสะอาด cache เก่า (เก็บแค่ 100 รายการล่าสุด)
      _cleanupCache();

    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'เกิดข้อผิดพลาดในการโหลดข้อมูล: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _analyzeMessage(String body, String hash, int index) async {
    try {
      // เรียก Gemini API วิเคราะห์ข้อความ พร้อมเหตุผล
      final result = await GeminiApi.analyzeMessageWithReason(body);
      return {
        'isScam': result['isScam'] as bool,
        'reason': result['reason'] as String,
        'hash': hash,
        'analyzedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      // กรณีเรียก API ไม่สำเร็จ ให้ใช้ fallback เป็นไม่ใช่ scam
      return {
        'isScam': false,
        'reason': 'ไม่สามารถวิเคราะห์ข้อความนี้ได้: ${e.toString()}',
        'hash': hash,
        'analyzedAt': DateTime.now().toIso8601String(),
        'error': true,
      };
    }
  }

  void _cleanupCache() {
    if (_messageCache.length > 100) {
      // เก็บแค่ 50 รายการล่าสุด
      final sortedEntries = _messageCache.entries.toList()
        ..sort((a, b) {
          final timeA = DateTime.parse(a.value['analyzedAt'] ?? '1970-01-01');
          final timeB = DateTime.parse(b.value['analyzedAt'] ?? '1970-01-01');
          return timeB.compareTo(timeA);
        });
      
      _messageCache = Map.fromEntries(sortedEntries.take(50));
    }
  }

  Future<void> _refreshData() async {
    // รีเซ็ตข้อมูลและโหลดใหม่
    setState(() {
      hasDataLoaded = false;
      analysisResults.clear();
    });
    await _loadSms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(appBarTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!isLoading && !permissionDenied && !hasError)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
              tooltip: refreshButtonText,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (permissionDenied) {
      return _buildPermissionDeniedView();
    }

    if (hasError) {
      return _buildErrorView();
    }

    if (isLoading) {
      return _buildLoadingView();
    }

    if (totalMessages == 0) {
      return _buildNoMessagesView();
    }

    return _buildStatsView();
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.security,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              permissionDeniedMessage,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _requestPermissionsAndLoadSms,
              icon: const Icon(Icons.settings),
              label: const Text('ขอสิทธิ์อีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'เกิดข้อผิดพลาด',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Check if it's permission error
            if (errorMessage.contains('สิทธิ์') || errorMessage.contains('permission')) ...[
              ElevatedButton.icon(
                onPressed: _requestPermissionsAndLoadSms,
                icon: const Icon(Icons.security),
                label: const Text('ขอสิทธิ์อีกครั้ง'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  _showPermissionHelpDialog();
                },
                icon: const Icon(Icons.help_outline),
                label: const Text('วิธีเปิดสิทธิ์ในการตั้งค่า'),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _requestPermissionsAndLoadSms,
                icon: const Icon(Icons.refresh),
                label: const Text(retryButtonText),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          if (totalMessages > 0 && analyzedMessages > 0)
            Text('กำลังวิเคราะห์ $analyzedMessages/$totalMessages ข้อความ...')
          else
            const Text('กำลังโหลดข้อมูล SMS...'),
          if (totalMessages > 0 && analyzedMessages > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: analyzedMessages / totalMessages,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoMessagesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            noMessagesText,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'แอปจะวิเคราะห์ข้อความ SMS ล่าสุด 20 ข้อความ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text(refreshButtonText),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsView() {
    final scamRatio = totalMessages == 0 ? 0.0 : scamMessages / totalMessages;
    final safeRatio = totalMessages == 0 ? 0.0 : safeMessages / totalMessages;

    // รองรับธีมมืด
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = Theme.of(context).cardColor;
    final shadowColor = isDarkMode ? Colors.black26 : Colors.grey.shade200;
    final scamBarColor = isDarkMode ? Colors.red.shade300 : Colors.red;
    final safeBarColor = isDarkMode ? Colors.green.shade300 : Colors.green;
    final progressBarBackground = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lastUpdated != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.blue.shade900.withOpacity(0.2) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$lastUpdatedLabel: ${DateFormat('dd/MM/yyyy HH:mm').format(lastUpdated!)}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // แสดงจำนวนข้อความจาก cache
                  if (_messageCache.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Cache: ${_messageCache.length}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          const Text(
            overviewTitle,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildStatCard(
            title: totalMessagesLabel,
            value: totalMessages,
            icon: Icons.mail,
            color: Colors.blue,
            subtitle: 'วิเคราะห์ข้อความล่าสุด 20 ข้อความ',
          ),

          _buildStatCard(
            title: scamMessagesLabel,
            value: scamMessages,
            icon: Icons.warning,
            color: Colors.red,
            subtitle: 'ตรวจพบการหลอกลวง',
            percentage: scamRatio * 100,
          ),

          _buildStatCard(
            title: safeMessagesLabel,
            value: safeMessages,
            icon: Icons.check_circle,
            color: Colors.green,
            subtitle: 'ข้อความปลอดภัย',
            percentage: safeRatio * 100,
          ),

          const SizedBox(height: 32),

          const Text(
            ratioTitle,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: progressBarBackground,
                  ),
                  child: Row(
                    children: [
                      if (scamRatio > 0)
                        Expanded(
                          flex: (scamRatio * 100).round(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: scamBarColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                bottomLeft: const Radius.circular(12),
                                topRight: safeRatio == 0 ? const Radius.circular(12) : Radius.zero,
                                bottomRight: safeRatio == 0 ? const Radius.circular(12) : Radius.zero,
                              ),
                            ),
                          ),
                        ),
                      if (safeRatio > 0)
                        Expanded(
                          flex: (safeRatio * 100).round(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: safeBarColor,
                              borderRadius: BorderRadius.only(
                                topRight: const Radius.circular(12),
                                bottomRight: const Radius.circular(12),
                                topLeft: scamRatio == 0 ? const Radius.circular(12) : Radius.zero,
                                bottomLeft: scamRatio == 0 ? const Radius.circular(12) : Radius.zero,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendItem(
                      'Scam',
                      '${(scamRatio * 100).toStringAsFixed(1)}%',
                      scamBarColor,
                    ),
                    _buildLegendItem(
                      'Safe',
                      '${(safeRatio * 100).toStringAsFixed(1)}%',
                      safeBarColor,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          if (totalMessages > 0) _buildInsightsSection(scamRatio),
          
          // เพิ่มปุ่มดูรายละเอียดข้อความ
          if (analysisResults.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildViewDetailsButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    required String subtitle,
    double? percentage,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (percentage != null)
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, String percentage, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              percentage,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightsSection(double scamRatio) {
    String insightText;
    Color insightColor;
    IconData insightIcon;

    if (scamRatio == 0) {
      insightText = 'ยอดเยี่ยม! ไม่พบข้อความหลอกลวงในกล่องข้อความของคุณ';
      insightColor = Colors.green;
      insightIcon = Icons.shield;
    } else if (scamRatio < 0.05) {
      insightText = 'ดีมาก! พบข้อความหลอกลวงน้อยกว่า 5%';
      insightColor = Colors.green;
      insightIcon = Icons.thumb_up;
    } else if (scamRatio < 0.15) {
      insightText = 'ระวัง! พบข้อความหลอกลวงมากกว่าปกติ';
      insightColor = Colors.orange;
      insightIcon = Icons.warning;
    } else {
      insightText = 'อันตราย! พบข้อความหลอกลวงจำนวนมาก โปรดระวัง!';
      insightColor = Colors.red;
      insightIcon = Icons.dangerous;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: insightColor.withOpacity(0.1),
        border: Border.all(color: insightColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(insightIcon, color: insightColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insightText,
              style: TextStyle(
                color: _getDarkerColor(insightColor),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewDetailsButton() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.list_alt),
        title: const Text('ดูรายละเอียดการวิเคราะห์'),
        subtitle: Text('ดูเหตุผลการตรวจสอบแต่ละข้อความ (${analysisResults.length} ข้อความ)'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: _showAnalysisDetails,
      ),
    );
  }

  void _showAnalysisDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'รายละเอียดการวิเคราะห์',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: analysisResults.length,
                itemBuilder: (context, index) {
                  final result = analysisResults[index];
                  if (result == null) return const SizedBox();
                  
                  final isScam = result['isScam'] as bool;
                  final reason = result['reason'] as String;
                  final hasError = result['error'] == true;
                 return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hasError 
                              ? Colors.grey.withOpacity(0.1)
                              : (isScam ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          hasError 
                              ? Icons.error_outline
                              : (isScam ? Icons.warning : Icons.check_circle),
                          color: hasError 
                              ? Colors.grey
                              : (isScam ? Colors.red : Colors.green),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        hasError 
                            ? 'ข้อผิดพลาด'
                            : (isScam ? 'ข้อความหลอกลวง' : 'ข้อความปลอดภัย'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: hasError 
                              ? Colors.grey
                              : (isScam ? Colors.red : Colors.green),
                        ),
                      ),
                      subtitle: Text(
                        reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('วิธีเปิดสิทธิ์ SMS'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. ไปที่ การตั้งค่า > แอป'),
            SizedBox(height: 8),
            Text('2. ค้นหาแอป Anti-Scam AI'),
            SizedBox(height: 8),
            Text('3. เลือก สิทธิ์ (Permissions)'),
            SizedBox(height: 8),
            Text('4. เปิดสิทธิ์ SMS'),
            SizedBox(height: 16),
            Text(
              'หมายเหตุ: แอปต้องการสิทธิ์นี้เพื่อวิเคราะห์ข้อความ SMS เท่านั้น',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Color _getDarkerColor(Color color) {
    return Color.fromARGB(
      color.alpha,
      (color.red * 0.8).round(),
      (color.green * 0.8).round(),
      (color.blue * 0.8).round(),
    );
  }
}