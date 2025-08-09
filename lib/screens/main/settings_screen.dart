import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;
  const SettingsScreen({super.key, required this.themeModeNotifier});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool protectionEnabled = true;
  double notificationSensitivity = 0.5;
  bool darkModeEnabled = false;

  // สถานะสิทธิ์
  bool smsPermission = false;
  bool notificationPermission = false;
  bool accessibilityPermission = false;

  static const platform = MethodChannel('message_monitor');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      protectionEnabled = prefs.getBool('protectionEnabled') ?? true;
      notificationSensitivity =
          prefs.getDouble('notificationSensitivity') ?? 0.5;
      darkModeEnabled = prefs.getBool('darkModeEnabled') ?? false;
    });
    widget.themeModeNotifier.value =
        darkModeEnabled ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _checkPermissions() async {
    try {
      final Map result = await platform.invokeMethod('checkPermissions');
      if (!mounted) return;
      setState(() {
        smsPermission = result['sms'] ?? false;
        notificationPermission = result['notification'] ?? false;
        accessibilityPermission = result['accessibility'] ?? false;
      });
    } catch (e) {
      debugPrint("Permission check failed: $e");
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _saveProtectionEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('protectionEnabled', value);
    _showSnackBar('ระบบป้องกันถูก${value ? 'เปิด' : 'ปิด'}แล้ว');
  }

  Future<void> _saveNotificationSensitivity(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('notificationSensitivity', value);
    _showSnackBar(
        'ระดับความไวการแจ้งเตือนถูกตั้งเป็น ${(value * 100).round()}%');
  }

  Future<void> _saveDarkModeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkModeEnabled', value);
    _showSnackBar('โหมดมืดถูก${value ? 'เปิด' : 'ปิด'}แล้ว');
  }

  Future<void> _resetProtectionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('protectionEnabled');
    await prefs.remove('notificationSensitivity');
    await _loadSettings();
    _showSnackBar('รีเซ็ตระบบป้องกันเรียบร้อยแล้ว');
  }

  Future<void> _resetThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('darkModeEnabled');
    await _loadSettings();
    _showSnackBar('รีเซ็ตธีมเรียบร้อยแล้ว');
  }

  void _onDarkModeChanged(bool value) {
    setState(() {
      darkModeEnabled = value;
    });
    _saveDarkModeEnabled(value);
    widget.themeModeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  Widget _buildPermissionCard(
      String title, String subtitle, bool granted, VoidCallback onTap) {
    final theme = Theme.of(context);
    final iconColor =
        granted ? theme.colorScheme.primary : theme.colorScheme.error;
    final backgroundColor = granted
        ? theme.colorScheme.primary.withOpacity(0.1)
        : theme.colorScheme.error.withOpacity(0.1);

    final borderColor = granted
        ? theme.colorScheme.primary.withOpacity(0.3)
        : theme.colorScheme.error.withOpacity(0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            granted ? Icons.check_circle : Icons.error,
            color: iconColor,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Chip(
          label: Text(
            granted ? 'เปิดแล้ว' : 'ยังไม่เปิด',
            style: TextStyle(
              color: iconColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: backgroundColor,
          side: BorderSide.none,
        ),
        onTap: granted ? null : onTap,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAppSettings() async {
    try {
      await platform.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('Open app settings failed: $e');
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (!mounted) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('คำแนะนำ'),
        content: const Text(
            'ระบบจะเปิดหน้าตั้งค่าการเข้าถึง Notification Listener โปรดเลื่อนหาแอป "Anti Scam AI" และเปิดสิทธิ์ให้แอปทำงานได้'),
        actions: [
          TextButton(
            child: const Text('ยกเลิก'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: const Text('ตกลง'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await platform.invokeMethod('requestNotificationPermission');
        setState(() {
          notificationPermission = false; // ต้องให้ผู้ใช้เปิดเอง
        });
        _showSnackBar(
            'โปรดเปิดสิทธิ์ Notification Listener สำหรับแอป Anti Scam AI ในหน้าตั้งค่าที่เปิดขึ้น');
      } catch (e) {
        debugPrint('Request Notification permission failed: $e');
        _showSnackBar('ขอสิทธิ์ Notification Listener ล้มเหลว');
      }
    } else {
      _showSnackBar('ยกเลิกการเปิดสิทธิ์ Notification Listener');
    }
  }

  Future<void> _requestAccessibilityPermission() async {
    try {
      final bool granted =
          await platform.invokeMethod('requestAccessibilityPermission');
      if (!mounted) return;
      setState(() {
        accessibilityPermission = granted;
      });
      _showSnackBar(granted
          ? 'สิทธิ์ Accessibility ถูกอนุญาตแล้ว'
          : 'ไม่ได้รับสิทธิ์ Accessibility');
    } catch (e) {
      debugPrint('Request Accessibility permission failed: $e');
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'antiscamai@gmail.com', // ← แก้ตรงนี้
      queryParameters: {
        'subject': 'สอบถาม Anti Scam AI',
      },
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      _showSnackBar('ไม่สามารถเปิดแอปอีเมลได้');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่า'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ส่วนสถานะสิทธิ์
            _buildSectionHeader('สถานะสิทธิ์การเข้าถึง', Icons.security),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildPermissionCard(
                    'สิทธิ์อ่าน SMS',
                    'อนุญาตให้แอปอ่านข้อความ SMS',
                    smsPermission,
                    _openAppSettings,
                  ),
                  _buildPermissionCard(
                    'สิทธิ์ Notification Listener',
                    'อนุญาตให้แอปเข้าถึงการแจ้งเตือน',
                    notificationPermission,
                    _requestNotificationPermission,
                  ),
                  _buildPermissionCard(
                    'สิทธิ์ Accessibility',
                    'อนุญาตให้แอปเข้าถึงฟีเจอร์ความสะดวก',
                    accessibilityPermission,
                    _requestAccessibilityPermission,
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    label: 'ตรวจสอบสิทธิ์อีกครั้ง',
                    icon: Icons.refresh,
                    onPressed: _checkPermissions,
                  ),
                ],
              ),
            ),

            // ส่วนระบบป้องกัน
            _buildSectionHeader('ระบบป้องกัน', Icons.shield),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'เปิดระบบป้องกัน',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('เปิด/ปิดการทำงานของระบบตรวจจับสแกม'),
                    value: protectionEnabled,
                    onChanged: (bool value) {
                      setState(() => protectionEnabled = value);
                      _saveProtectionEnabled(value);
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.tune,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ระดับความรุนแรงของการแจ้งเตือน',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('ต่ำ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: notificationSensitivity,
                          min: 0,
                          max: 1,
                          divisions: 10,
                          label: '${(notificationSensitivity * 100).round()}%',
                          onChanged: (double value) {
                            setState(() => notificationSensitivity = value);
                            _saveNotificationSensitivity(value);
                          },
                        ),
                      ),
                      const Text('สูง', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    label: 'รีเซ็ตระบบป้องกัน',
                    icon: Icons.restore,
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    onPressed: () async {
                      final confirmed = await _showConfirmDialog(
                        'ยืนยันการรีเซ็ต',
                        'คุณแน่ใจว่าจะรีเซ็ตการตั้งค่าระบบป้องกันเป็นค่าเริ่มต้น?',
                      );
                      if (confirmed == true) {
                        _resetProtectionSettings();
                      }
                    },
                  ),
                ],
              ),
            ),

            // ส่วนธีมแอป
            _buildSectionHeader('ธีมแอป', Icons.palette),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'โหมดมืด',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('เปิด/ปิดโหมดมืดของแอป'),
                    value: darkModeEnabled,
                    onChanged: _onDarkModeChanged,
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    label: 'รีเซ็ตธีม',
                    icon: Icons.restore,
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    onPressed: () async {
                      final confirmed = await _showConfirmDialog(
                        'ยืนยันการรีเซ็ต',
                        'คุณแน่ใจว่าจะรีเซ็ตการตั้งค่าธีมเป็นค่าเริ่มต้น?',
                      );
                      if (confirmed == true) {
                        _resetThemeSettings();
                      }
                    },
                  ),
                ],
              ),
            ),

            // ส่วนเพิ่มเติม
            _buildSectionHeader('เพิ่มเติม', Icons.more_horiz),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.help_outline, color: Colors.blue),
                    ),
                    title: const Text(
                      'คู่มือการใช้งาน',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: const Text('คู่มือการใช้งาน'),
                          content: const Text(
                            'แอปนี้จะขอสิทธิ์อ่าน SMS, Notification Listener และ Accessibility เพื่อช่วยตรวจจับข้อความหลอกลวงและแจ้งเตือนคุณ\n\n'
                            'โปรดอนุญาตสิทธิ์เหล่านี้ในหน้าการตั้งค่าของอุปกรณ์ เพื่อให้แอปทำงานได้อย่างถูกต้อง',
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('ปิด'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.email, color: Colors.green),
                    ),
                    title: const Text(
                      'ติดต่อผู้พัฒนา',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _launchEmail,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
