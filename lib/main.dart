import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/models/scan_result.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/permission/permission_screen.dart';
import 'screens/main/sms_history_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/main/home_screen.dart';
import 'screens/main/scan_screen.dart';
import 'screens/main/stats_screen.dart';
import 'screens/main/user_screen.dart';
import 'screens/main/settings_screen.dart';

// ✅ ใช้ ApiService จากไฟล์แยก
import 'services/api_service.dart';

// === Globals (ใช้ได้ทั้งแอป) ===
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier(ThemeMode.system);

// Native channels ต้องตรงกับฝั่ง Android (MainActivity.kt)
const MethodChannel methodChannel = MethodChannel('message_monitor');
const EventChannel eventChannel =
    EventChannel('com.example.anti_scam_ai/accessibility');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ทดสอบการเชื่อมต่อ API เมื่อเริ่มแอป
  final connected = await ApiService.testConnection();
  debugPrint('🌐 API Connection: ${connected ? "✅ Connected" : "❌ Failed"}');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<ScanResult> someScanResults = [];

  @override
  void initState() {
    super.initState();
    requestPermissions();
    listenToNativeEvents();
  }

  /// ✅ ขอสิทธิ์จาก Native (Android)
  Future<void> requestPermissions() async {
    try {
      final smsGranted =
          await methodChannel.invokeMethod<bool>('requestSmsPermission');
      debugPrint('📱 SMS Permission granted: $smsGranted');

      final notifGranted = await methodChannel
          .invokeMethod<bool>('requestNotificationListenerPermission');
      debugPrint('🔔 Notification Permission granted: $notifGranted');

      try {
        final accessibilityGranted = await methodChannel
            .invokeMethod<bool>('requestAccessibilityPermission');
        debugPrint('♿ Accessibility Permission granted: $accessibilityGranted');
      } catch (e) {
        debugPrint('ℹ️ Accessibility permission method not found: $e');
      }
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      _showErrorDialog('เกิดข้อผิดพลาด', 'ไม่สามารถขอสิทธิ์ได้: $e');
    }
  }

  /// ✅ ฟัง EventChannel จาก Native แล้วตรวจสอบข้อความผ่าน AI
  void listenToNativeEvents() {
    eventChannel.receiveBroadcastStream().listen((event) async {
      debugPrint('📲 Event received: $event');

      if (event != null && event.toString().trim().isNotEmpty) {
        final result = await ApiService.checkMessage(event.toString());

        final context = navigatorKey.currentContext;
        if (context == null) return;

        if (result['success'] == true) {
          if (result['isScam'] == true) {
            _showScamAlert(
              context,
              event.toString(),
              result['label'] ?? 'unknown',
              (result['score'] ?? 0.0).toDouble(),
            );
          } else {
            debugPrint('✅ Message is safe: $event');
            _showSafeNotification(context);
          }
        } else {
          _showErrorDialog(
              'ข้อผิดพลาด API', result['error'] ?? 'Unknown error');
        }
      }
    }, onError: (error) {
      debugPrint('⚠️ EventChannel error: $error');
      _showErrorSnackBar('การเชื่อมต่อ Native มีปัญหา: $error');
    });
  }

  /// 🚨 แจ้งเตือนเมื่อเจอ Scam
  void _showScamAlert(
      BuildContext context, String message, String label, double score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.red, size: 48),
        title: const Text(
          '🚨 ตรวจพบข้อความต้องสงสัย!',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ข้อความนี้อาจเป็น SCAM:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 12),
            Text(
              'AI Label: ${label.toUpperCase()} • Score: ${score.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('รายงาน'),
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: ไปหน้ารายงาน
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('เข้าใจแล้ว', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// ✅ ข้อความปลอดภัย
  void _showSafeNotification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('ข้อความปลอดภัย ✅'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// ❌ Error Dialog
  void _showErrorDialog(String title, String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('ปิด'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  /// ⚠ Error SnackBar
  void _showErrorSnackBar(String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Anti-Scam AI',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            colorSchemeSeed: Colors.deepPurple,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorSchemeSeed: Colors.deepPurple,
            useMaterial3: true,
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/reset-password': (context) => const ResetPasswordScreen(),
            '/permission': (context) => const PermissionScreen(),
            '/main': (context) =>
                MainScreen(themeModeNotifier: themeModeNotifier),
            '/home': (context) => const HomeScreen(),
            '/scan': (context) => const ScanScreen(),
            '/stats': (context) => const StatsScreen(),
            '/profile': (context) => const UserScreen(),
            '/login': (context) => const LoginScreen(),
            '/settings': (context) =>
                SettingsScreen(themeModeNotifier: themeModeNotifier),
            '/history': (context) => const HistoryScreen(),
            '/test-api': (context) => const ApiTestScreen(),
          },
        );
      },
    );
  }
}

// ✅ หน้าทดสอบ API (สำหรับ Debug)
class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final TextEditingController _controller = TextEditingController();
  String _result = '';
  bool _isLoading = false;

  Future<void> _testMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = 'กำลังตรวจสอบ...';
    });

    final result = await ApiService.checkMessage(text);

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _result = result['isScam'] == true
            ? '🚨 ข้อความน่าสงสัย (SCAM)'
            : '✅ ข้อความปลอดภัย (SAFE)';
      } else {
        _result = '❌ Error: ${result['error']}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทดสอบ Anti-Scam AI'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'พิมพ์ข้อความที่ต้องการตรวจสอบ',
                border: OutlineInputBorder(),
                hintText: 'เช่น: คุณได้รับรางวัล 1 ล้านบาท กดลิงก์เพื่อรับ...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _testMessage,
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('กำลังตรวจสอบ...'),
                        ],
                      )
                    : const Text('ตรวจสอบข้อความ'),
              ),
            ),
            const SizedBox(height: 24),
            if (_result.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _result.contains('SCAM')
                      ? Colors.red.withOpacity(0.1)
                      : _result.contains('SAFE')
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _result.contains('SCAM')
                        ? Colors.red
                        : _result.contains('SAFE')
                            ? Colors.green
                            : Colors.orange,
                  ),
                ),
                child: Text(
                  _result,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _result.contains('SCAM')
                        ? Colors.red
                        : _result.contains('SAFE')
                            ? Colors.green
                            : Colors.orange,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              'ตัวอย่างข้อความทดสอบ:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildExampleButton(
                'คุณได้รับรางวัล 1 ล้านบาท! กดลิงก์เพื่อรับทันที'),
            _buildExampleButton('ยืนยันบัญชีธนาคารของคุณ คลิกที่นี่'),
            _buildExampleButton('สวัสดี ทำงานอะไรอยู่'),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleButton(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {
            _controller.text = text;
          },
          child: Text(
            text,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
