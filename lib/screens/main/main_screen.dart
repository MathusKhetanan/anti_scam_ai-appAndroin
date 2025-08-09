import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'user_screen.dart';
import 'bottom_nav_bar.dart';

class MainScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const MainScreen({super.key, required this.themeModeNotifier});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const ScanScreen(),
      const StatsScreen(), // ← ไม่ส่งพารามิเตอร์แล้ว
      SettingsScreen(themeModeNotifier: widget.themeModeNotifier),
      const UserScreen(),
    ];
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
