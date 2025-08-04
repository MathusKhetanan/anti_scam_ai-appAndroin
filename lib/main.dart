import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firebase_options.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/permission/permission_screen.dart';
<<<<<<< HEAD
import 'screens/main/sms_history_screen.dart';
=======
import 'screens/main/sms_history_screen.dart'; // import history
>>>>>>> dcb51031a26fa5e977b1ab5746bd5a7fb78ac375
import 'screens/main/main_screen.dart';
import 'screens/main/home_screen.dart';
import 'screens/main/scan_screen.dart';
import 'screens/main/stats_screen.dart';
import 'screens/main/user_screen.dart';
import 'screens/main/settings_screen.dart';

import 'services/sms_model_service.dart';

// Global Notifiers
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

<<<<<<< HEAD
// ✅ Native Channel communication
const MethodChannel methodChannel = MethodChannel('message_monitor');
const EventChannel eventChannel = EventChannel('com.example.anti_scam_ai/accessibility');

// ✅ API Configuration - แก้ไข URL ตรงนี้หลัง Deploy บน Render
class ApiService {
  static const String baseUrl = 'https://backend-api-j5m6.onrender.com/'; // ⚠️ เปลี่ยน URL ให้ตรงกับ Render
  static const String predictEndpoint = '/predict';
  
  // ตรวจสอบข้อความผ่าน API
  static Future<Map<String, dynamic>> checkMessage(String message) async {
    final url = Uri.parse('$baseUrl$predictEndpoint');
    
    try {
      debugPrint('🌐 Calling API: $url');
      debugPrint('📤 Message: $message');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'message': message}),
      ).timeout(const Duration(seconds: 30));

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'prediction': data['prediction'],
          'isScam': data['prediction'] == 'scam',
        };
      } else {
        return {
          'success': false,
          'error': 'API returned status ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('❌ API Error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
  
  // ทดสอบการเชื่อมต่อ API
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Accept': 'text/html'},
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Connection test failed: $e');
      return false;
    }
  }
}
=======
// Native Channels (ปรับให้ตรงกับ Android package)
const MethodChannel methodChannel = MethodChannel('message_monitor');
const EventChannel eventChannel = EventChannel('com.example.anti_scam_ai/accessibility');
>>>>>>> dcb51031a26fa5e977b1ab5746bd5a7fb78ac375

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
<<<<<<< HEAD
  
  // ทดสอบการเชื่อมต่อ API เมื่อเริ่มแอป
  final connected = await ApiService.testConnection();
  debugPrint('🌐 API Connection: ${connected ? "✅ Connected" : "❌ Failed"}');
  
=======

  // โหลดโมเดล AI และ tokenizer ก่อนเริ่มแอป (await เพื่อไม่ให้แอปเริ่มก่อนโหลดเสร็จ)
  await SMSModelService.init();

>>>>>>> dcb51031a26fa5e977b1ab5746bd5a7fb78ac375
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _listenToNativeEvents();
  }

  /// ขอสิทธิ์ที่จำเป็นผ่าน MethodChannel
  Future<void> _requestPermissions() async {
    try {
      final smsGranted = await methodChannel.invokeMethod<bool>('requestSmsPermission');
      debugPrint('📱 SMS Permission granted: $smsGranted');

      final notifGranted = await methodChannel.invokeMethod<bool>('requestNotificationListenerPermission');
      debugPrint('🔔 Notification Permission granted: $notifGranted');

      try {
        final accessibilityGranted = await methodChannel.invokeMethod<bool>('requestAccessibilityPermission');
        debugPrint('♿ Accessibility Permission granted: $accessibilityGranted');
      } catch (e) {
        debugPrint('ℹ️ Accessibility permission method not found: $e');
      }
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
<<<<<<< HEAD
      _showErrorDialog('เกิดข้อผิดพลาด', 'ไม่สามารถขอสิทธิ์ได้: $e');
    }
  }

  // ✅ ฟัง EventChannel จาก Native แล้วตรวจสอบข้อความผ่าน AI
  void listenToNativeEvents() {
    eventChannel.receiveBroadcastStream().listen((event) async {
      debugPrint('📲 Event received: $event');

      // ตรวจสอบข้อความผ่าน AI API
      if (event != null && event.toString().isNotEmpty) {
        final result = await ApiService.checkMessage(event.toString());
        
        final context = navigatorKey.currentContext;
        if (context != null) {
          if (result['success'] == true) {
            if (result['isScam'] == true) {
              // แจ้งเตือนข้อความ Scam
              _showScamAlert(context, event.toString(), result['prediction']);
            } else {
              // ข้อความปลอดภัย - อาจจะไม่ต้องแจ้งเตือน หรือแจ้งแบบเบาๆ
              debugPrint('✅ Message is safe: $event');
              _showSafeNotification(context);
            }
          } else {
            // API Error
            _showErrorDialog('ข้อผิดพลาด API', result['error'] ?? 'Unknown error');
          }
        }
      }
    }, onError: (error) {
      debugPrint('⚠️ EventChannel error: $error');
      _showErrorSnackBar('การเชื่อมต่อ Native มีปัญหา: $error');
    });
=======
      final context = navigatorKey.currentContext;
      if (context != null) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('เกิดข้อผิดพลาด'),
            content: Text('ไม่สามารถขอสิทธิ์ได้: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ปิด'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// ฟัง EventChannel จาก Native เพื่อรับเหตุการณ์จาก Accessibility หรือ Notification
  void _listenToNativeEvents() {
    eventChannel.receiveBroadcastStream().listen(
      (event) {
        debugPrint('📲 Event received: $event');
        final context = navigatorKey.currentContext;
        if (context != null) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('ตรวจพบข้อความน่าสงสัย'),
              content: Text(event.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ปิด'),
                ),
              ],
            ),
          );
        }
      },
      onError: (error) {
        debugPrint('⚠️ EventChannel error: $error');
        final context = navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('การเชื่อมต่อ Native มีปัญหา: $error'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
    );
>>>>>>> dcb51031a26fa5e977b1ab5746bd5a7fb78ac375
  }

  // แสดง Alert เมื่อพบข้อความ Scam
  void _showScamAlert(BuildContext context, String message, String prediction) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.red, size: 48),
        title: const Text('🚨 ตรวจพบข้อความต้องสงสัย!', 
                         style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
            Text('AI Prediction: ${prediction.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
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
            child: const Text('เข้าใจแล้ว', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // แจ้งเตือนเบาๆ เมื่อข้อความปลอดภัย
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

  // แสดง Error Dialog
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

  // แสดง Error SnackBar
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
            '/main': (context) => MainScreen(themeModeNotifier: themeModeNotifier),
            '/home': (context) => const HomeScreen(),
            '/scan': (context) => const ScanScreen(),
'/stats': (context) => const StatsScreen(scanResults: []), // เพิ่ม scanResults: []
            '/profile': (context) => const UserScreen(),
            '/login': (context) => const LoginScreen(),
            '/settings': (context) => SettingsScreen(themeModeNotifier: themeModeNotifier),
            '/history': (context) => const HistoryScreen(),
            '/test-api': (context) => const ApiTestScreen(), // เพิ่มหน้าทดสอบ API
          },
        );
      },
    );
  }
}
<<<<<<< HEAD

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
            _buildExampleButton('คุณได้รับรางวัล 1 ล้านบาท! กดลิงก์เพื่อรับทันที'),
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
=======
>>>>>>> dcb51031a26fa5e977b1ab5746bd5a7fb78ac375
