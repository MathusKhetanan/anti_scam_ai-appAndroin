  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'firebase_options.dart'; // เพิ่มบรรทัดนี้
  import 'screens/auth/login_screen.dart'; // เพิ่มตรงนี้
  import 'screens/auth/register_screen.dart'; // << เพิ่มตรงนี้
  import 'screens/permission/permission_screen.dart';
  import 'package:anti_scam_ai/screens/auth/forgot_password_screen.dart';
  import 'screens/main/main_screen.dart';
  import 'screens/main/home_screen.dart';
  import 'screens/main/scan_screen.dart';
  import 'screens/stats/stats_screen.dart';
  import 'screens/profile/settings_screen.dart';
  import 'package:anti_scam_ai/screens/profile/profile_screen.dart';

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

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, // เพิ่มบรรทัดนี้
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
        debugPrint('❌ Error requesting permissions: $e');
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
            initialRoute: '/',
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
