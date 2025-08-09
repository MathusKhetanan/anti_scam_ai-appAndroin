import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _smsCheckHistory = [];
  List<Map<String, dynamic>> _reportHistory = [];
  int _selectedTabIndex = 0;

  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadHistoryData();
  }

  void _initializeControllers() {
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryData() async {
    if (!mounted) return;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // โหลดประวัติการตรวจสอบ SMS
      final smsQuery = await _firestore
          .collection('sms_check_history')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('check_date', descending: true)
          .limit(50)
          .get();

      // โหลดประวัติการรายงาน SMS หลอกลวง
      final reportQuery = await _firestore
          .collection('sms_reports')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('report_date', descending: true)
          .limit(50)
          .get();

      setState(() {
        _smsCheckHistory = smsQuery.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                })
            .toList();

        _reportHistory = reportQuery.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                })
            .toList();

        _isLoading = false;
      });

      _fadeController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'ประวัติตรวจสอบ SMS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32), // สีเขียวธรรมชาติของไทย
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.message_outlined),
              text: 'ประวัติตรวจสอบ SMS',
            ),
            Tab(
              icon: Icon(Icons.report_problem),
              text: 'ประวัติการรายงาน',
            ),
          ],
        ),
      ),
      body: _isLoading ? _buildLoadingWidget() : _buildTabBarView(),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
          ),
          SizedBox(height: 16),
          Text(
            'กำลังโหลดประวัติการตรวจสอบ...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildSmsCheckHistoryTab(),
          _buildReportHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildSmsCheckHistoryTab() {
    if (_smsCheckHistory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.message_outlined,
        title: 'ยังไม่มีประวัติการตรวจสอบ',
        subtitle: 'เมื่อคุณใช้งานระบบตรวจสอบ SMS หลอกลวง\nประวัติจะแสดงที่นี่',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistoryData,
      color: const Color(0xFF2E7D32),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _smsCheckHistory.length,
        itemBuilder: (context, index) {
          final smsCheck = _smsCheckHistory[index];
          return _buildSmsCheckHistoryCard(smsCheck);
        },
      ),
    );
  }

  Widget _buildReportHistoryTab() {
    if (_reportHistory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.report_problem,
        title: 'ยังไม่มีประวัติการรายงาน',
        subtitle: 'เมื่อคุณรายงาน SMS หลอกลวง\nประวัติจะแสดงที่นี่',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistoryData,
      color: const Color(0xFF2E7D32),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reportHistory.length,
        itemBuilder: (context, index) {
          final report = _reportHistory[index];
          return _buildReportHistoryCard(report);
        },
      ),
    );
  }

  Widget _buildSmsCheckHistoryCard(Map<String, dynamic> smsCheck) {
    final senderNumber = smsCheck['sender_number'] ?? 'ไม่ทราบผู้ส่ง';
    final smsContent = smsCheck['sms_content'] ?? 'ไม่มีเนื้อหา';
    final checkDate = _formatDateTime(smsCheck['check_date']);
    final result = smsCheck['result'] ?? 'unknown';
    final riskLevel = smsCheck['risk_level'] ?? 0;
    final scamType = smsCheck['scam_type'];

    Color resultColor;
    IconData resultIcon;
    String resultText;

    switch (result) {
      case 'safe':
        resultColor = const Color(0xFF2E7D32); // สีเขียว
        resultIcon = Icons.verified_user;
        resultText = 'ปลอดภัย';
        break;
      case 'suspicious':
        resultColor = const Color(0xFFFF8F00); // สีส้ม
        resultIcon = Icons.warning_amber;
        resultText = 'น่าสงสัย';
        break;
      case 'scam':
        resultColor = const Color(0xFFD32F2F); // สีแดง
        resultIcon = Icons.dangerous;
        resultText = 'หลอกลวง';
        break;
      default:
        resultColor = Colors.grey;
        resultIcon = Icons.help_outline;
        resultText = 'ไม่ทราบ';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: resultColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSmsCheckDetails(smsCheck),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: resultColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      resultIcon,
                      color: resultColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'จาก: $senderNumber',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              resultText,
                              style: TextStyle(
                                color: resultColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (scamType != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getScamTypeText(scamType),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    checkDate,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  smsContent.length > 100
                      ? '${smsContent.substring(0, 100)}...'
                      : smsContent,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (riskLevel > 0) ...[
                const SizedBox(height: 12),
                _buildRiskLevelBar(riskLevel),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportHistoryCard(Map<String, dynamic> report) {
    final senderNumber = report['sender_number'] ?? 'ไม่ทราบผู้ส่ง';
    final reportDate = _formatDateTime(report['report_date']);
    final scamType = report['scam_type'] ?? 'other';
    final status = report['status'] ?? 'pending';

    Color statusColor;
    String statusText;

    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF2E7D32);
        statusText = 'อนุมัติแล้ว';
        break;
      case 'rejected':
        statusColor = const Color(0xFFD32F2F);
        statusText = 'ปฏิเสธ';
        break;
      case 'under_review':
        statusColor = const Color(0xFF1976D2);
        statusText = 'กำลังตรวจสอบ';
        break;
      default:
        statusColor = const Color(0xFFFF8F00);
        statusText = 'รอการตรวจสอบ';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showReportDetails(report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.report_problem,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รายงาน: $senderNumber',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _getScamTypeText(scamType),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                reportDate,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskLevelBar(int riskLevel) {
    final percentage = (riskLevel / 100).clamp(0.0, 1.0);
    Color barColor;

    if (riskLevel < 30) {
      barColor = const Color(0xFF2E7D32); // เขียว
    } else if (riskLevel < 70) {
      barColor = const Color(0xFFFF8F00); // ส้ม
    } else {
      barColor = const Color(0xFFD32F2F); // แดง
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ระดับความเสี่ยง',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$riskLevel%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHistoryData,
              icon: const Icon(Icons.refresh),
              label: const Text('รีเฟรช'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSmsCheckDetails(Map<String, dynamic> smsCheck) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.message_outlined, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('รายละเอียดการตรวจสอบ SMS'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('ผู้ส่ง', smsCheck['sender_number'] ?? 'ไม่ทราบ'),
              _buildDetailRow(
                  'วันที่ตรวจสอบ', _formatDateTime(smsCheck['check_date'])),
              _buildDetailRow(
                  'ผลการตรวจสอบ', _getResultText(smsCheck['result'])),
              _buildDetailRow(
                  'ระดับความเสี่ยง', '${smsCheck['risk_level'] ?? 0}%'),
              if (smsCheck['scam_type'] != null)
                _buildDetailRow(
                    'ประเภทหลอกลวง', _getScamTypeText(smsCheck['scam_type'])),
              const SizedBox(height: 12),
              const Text(
                'เนื้อหา SMS:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  smsCheck['sms_content'] ?? 'ไม่มีเนื้อหา',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (smsCheck['warning_reasons'] != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'เหตุผลที่เตือน:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ...List<String>.from(smsCheck['warning_reasons']).map(
                  (reason) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.red)),
                        Expanded(
                            child: Text(reason,
                                style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('ปิด', style: TextStyle(color: Color(0xFF2E7D32))),
          ),
        ],
      ),
    );
  }

  void _showReportDetails(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.report_problem, color: Colors.red),
            SizedBox(width: 8),
            Text('รายละเอียดการรายงาน'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('ผู้ส่ง', report['sender_number'] ?? 'ไม่ทราบ'),
              _buildDetailRow(
                  'วันที่รายงาน', _formatDateTime(report['report_date'])),
              _buildDetailRow(
                  'ประเภทหลอกลวง', _getScamTypeText(report['scam_type'])),
              _buildDetailRow('สถานะ', _getStatusText(report['status'])),
              if (report['description'] != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'รายละเอียดเพิ่มเติม:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report['description'],
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
              if (report['sms_content'] != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'เนื้อหา SMS ที่รายงาน:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Text(
                    report['sms_content'],
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('ปิด', style: TextStyle(color: Color(0xFF2E7D32))),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'ไม่ทราบ';

    try {
      DateTime date;
      if (dateTime is Timestamp) {
        date = dateTime.toDate();
      } else if (dateTime is String) {
        date = DateTime.parse(dateTime);
      } else {
        return 'ไม่ทราบ';
      }

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'วันนี้ ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.';
      } else if (difference.inDays == 1) {
        return 'เมื่อวาน ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} วันที่แล้ว';
      } else {
        return '${date.day}/${date.month}/${date.year + 543}'; // ปี พ.ศ.
      }
    } catch (e) {
      return 'ไม่ทราบ';
    }
  }

  String _getResultText(String? result) {
    switch (result) {
      case 'safe':
        return 'ปลอดภัย';
      case 'suspicious':
        return 'น่าสงสัย';
      case 'scam':
        return 'หลอกลวง';
      default:
        return 'ไม่ทราบ';
    }
  }

  String _getScamTypeText(String? type) {
    switch (type) {
      case 'phishing':
        return 'ฟิชชิ่ง (ขโมยข้อมูล)';
      case 'fake_bank':
        return 'ปลอมแปลงธนาคาร';
      case 'fake_gov':
        return 'ปลอมแปลงหน่วยงานราชการ';
      case 'lottery_scam':
        return 'หลอกถูกลอตเตอรี่';
      case 'investment_scam':
        return 'หลอกลงทุน';
      case 'loan_scam':
        return 'หลอกให้กู้เงิน';
      case 'prize_scam':
        return 'หลอกได้รางวัล';
      case 'romance_scam':
        return 'หลอกความรัก';
      case 'job_scam':
        return 'หลอกหางาน';
      case 'delivery_scam':
        return 'ปลอมแปลงขนส่ง';
      case 'covid_scam':
        return 'หลอกเกี่ยวกับโควิด';
      case 'other':
        return 'อื่นๆ';
      default:
        return 'ไม่ระบุประเภท';
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'approved':
        return 'อนุมัติแล้ว';
      case 'rejected':
        return 'ปฏิเสธ';
      case 'under_review':
        return 'กำลังตรวจสอบ';
      case 'pending':
        return 'รอการตรวจสอบ';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
