import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/register_screen.dart';

import 'screens/auth/login_screen.dart';
import 'screens/permission/permission_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/main/home_screen.dart';
import 'screens/main/scan_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'screens/profile/settings_screen.dart';

// ตัวแปร global เก็บสถานะธีมแอป
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

// สำหรับแสดง Dialog/Alert จาก EventChannel
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// MethodChannel สำหรับขอ permission
const MethodChannel methodChannel = MethodChannel('message_monitor');
// EventChannel สำหรับรับข้อความจาก native
const EventChannel eventChannel = EventChannel('message_monitor_event');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zcqubcxrnwehbtvvxuip.supabase.co', // ← ใส่ URL จริงของคุณ
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjcXViY3hybndlaGJ0dnZ4dWlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI4MDM1MzYsImV4cCI6MjA2ODM3OTUzNn0.ETtbrZJ-asQDaVOUdCNLFfzLG9bLA70QyCwiBIePWGo',               // ← ใส่ anon key จาก Supabase
  );

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
    listenNotifications();
  }

  // ขอ permission ผ่าน MethodChannel
  Future<void> requestPermissions() async {
    try {
      final granted = await methodChannel.invokeMethod<bool>('requestPermissions');
      if (granted == false) {
        await methodChannel.invokeMethod('requestNotificationListenerPermission');
      }
    } on PlatformException catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  // ฟัง notification ผ่าน EventChannel
  void listenNotifications() {
    eventChannel.receiveBroadcastStream().listen((event) {
      debugPrint('🚨 Received notification event: $event');

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          title: 'Anti-Scam AI',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
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
          themeMode: currentThemeMode,
          initialRoute: isLoggedIn ? '/' : '/login', // 🔁 เช็กสถานะผู้ใช้
          routes: {
  '/': (context) => MainScreen(themeModeNotifier: themeModeNotifier),
  '/login': (context) => const LoginScreen(),
  '/register': (context) => RegisterScreen(),  // <-- เพิ่มตรงนี้
  '/home': (context) => const HomeScreen(),
  '/scan': (context) => const ScanScreen(),
  '/stats': (context) => StatsScreen(),
  '/permission': (context) => const PermissionScreen(),
  '/settings': (context) => SettingsScreen(themeModeNotifier: themeModeNotifier),
          },
        );
      },
    );
  }
}
