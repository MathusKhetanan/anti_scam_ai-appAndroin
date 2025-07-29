import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/permission/permission_screen.dart';
import 'screens/main/sms_history_screen.dart'; // เพิ่ม import
import 'screens/main/main_screen.dart';
import 'screens/main/home_screen.dart';
import 'screens/main/scan_screen.dart';
import 'screens/main/stats_screen.dart';
import 'screens/main/user_screen.dart';
import 'screens/main/settings_screen.dart';
import 'services/sms_model_service.dart'; // import service ของเรา

  // ✅ Global Notifiers
  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ✅ Native Channel communication - แก้ไขชื่อให้ตรงกับ Android
  const MethodChannel methodChannel = MethodChannel('message_monitor');
  const EventChannel eventChannel = EventChannel('com.example.anti_scam_ai/accessibility'); // ✅ แก้ package name ให้ตรง

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // โหลดโมเดล AI และ tokenizer ก่อนเริ่มแอป
  await SMSModelService.init();

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
      requestPermissions();
      listenToNativeEvents();
    }

    // ✅ แก้ไขการขอสิทธิ์ให้เรียก method ที่มีใน Android
    Future<void> requestPermissions() async {
      try {
        // เรียกขอสิทธิ์ SMS ก่อน
        final smsGranted = await methodChannel.invokeMethod<bool>('requestSmsPermission');
        debugPrint('📱 SMS Permission granted: $smsGranted');
        
        // เรียกขอสิทธิ์ Notification Listener
        final notifGranted = await methodChannel.invokeMethod<bool>('requestNotificationListenerPermission');
        debugPrint('🔔 Notification Permission granted: $notifGranted');
        
        // หากต้องการขอสิทธิ์ Accessibility (ถ้ามี)
        try {
          final accessibilityGranted = await methodChannel.invokeMethod<bool>('requestAccessibilityPermission');
          debugPrint('♿ Accessibility Permission granted: $accessibilityGranted');
        } catch (e) {
          debugPrint('ℹ️ Accessibility permission method not found: $e');
        }
        
      } catch (e) {
        debugPrint('❌ Error requesting permissions: $e');
        // แสดง dialog แจ้งผู้ใช้
        final context = navigatorKey.currentContext;
        if (context != null) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('เกิดข้อผิดพลาด'),
              content: Text('ไม่สามารถขอสิทธิ์ได้: $e'),
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
    }

    // ✅ ฟัง EventChannel จาก Native แล้วแจ้งเตือน
    void listenToNativeEvents() {
      eventChannel.receiveBroadcastStream().listen((event) {
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
                  child: const Text('ปิด'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        }
      }, onError: (error) {
        debugPrint('⚠️ EventChannel error: $error');
        
        // แสดง error ให้ผู้ใช้เห็น (เฉพาะใน debug mode)
        final context = navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('การเชื่อมต่อ Native มีปัญหา: $error'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
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
              '/stats': (context) => const StatsScreen(),
              '/profile': (context) => const UserScreen(),
              '/login': (context) => const LoginScreen(),
              '/settings': (context) => SettingsScreen(themeModeNotifier: themeModeNotifier),
              '/history': (context) => const HistoryScreen(),
            },
          );
        },
      );
    }
  }