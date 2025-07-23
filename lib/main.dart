import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Firebase config
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/permission/permission_screen.dart';

import 'screens/main/main_screen.dart';
import 'screens/main/home_screen.dart';
import 'screens/main/scan_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'screens/profile/settings_screen.dart';
import 'screens/profile/user_screen.dart';
import 'package:anti_scam_ai/screens/auth/reset_password_screen.dart';

// Global ThemeMode notifier
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

// Global Navigator key for showing dialogs anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// MethodChannel & EventChannel for permission and native events
const MethodChannel methodChannel = MethodChannel('message_monitor');
const EventChannel eventChannel = EventChannel('message_monitor_event');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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

  // Request required permissions via native method channel
  Future<void> requestPermissions() async {
    try {
      final granted = await methodChannel.invokeMethod<bool>('requestPermissions');
      if (granted == false) {
        await methodChannel.invokeMethod('requestNotificationListenerPermission');
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
    }
  }

  // Listen to notification events from native side via event channel
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
          initialRoute: '/', // ✅ ยังคงใช้ route เริ่มต้นชื่อ '/'
            routes: {
              '/': (context) => const LoginScreen(), // ✅ ให้ route '/' เป็น LoginScreen แทน
              '/main': (context) => MainScreen(themeModeNotifier: themeModeNotifier), // ✅ เปลี่ยน MainScreen ไปอยู่ที่ /main
              '/register': (context) => const RegisterScreen(),
              '/home': (context) => const HomeScreen(),
              '/scan': (context) => const ScanScreen(),
              '/stats': (context) => const StatsScreen(),
              '/permission': (context) => const PermissionScreen(),
              '/profile': (context) => const UserScreen(),
              '/settings': (context) => SettingsScreen(themeModeNotifier: themeModeNotifier),
              '/reset-password': (context) => const ResetPasswordScreen(), // ✅ ต้องมีบรรทัดนี้!
            },
        );
      },
    );
  }
}
