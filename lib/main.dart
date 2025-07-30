import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/permission/permission_screen.dart';
import 'screens/main/sms_history_screen.dart'; // import history
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

// Native Channels (ปรับให้ตรงกับ Android package)
const MethodChannel methodChannel = MethodChannel('message_monitor');
const EventChannel eventChannel = EventChannel('com.example.anti_scam_ai/accessibility');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // โหลดโมเดล AI และ tokenizer ก่อนเริ่มแอป (await เพื่อไม่ให้แอปเริ่มก่อนโหลดเสร็จ)
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
