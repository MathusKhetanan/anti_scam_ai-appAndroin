import 'package:flutter/material.dart';

import 'home_screen.dart' as home_screen;
import 'scan_screen.dart' as scan_screen;
import 'package:anti_scam_ai/screens/stats/stats_screen.dart' as stats_screen;
import '../profile/settings_screen.dart' as settings_screen;
import '../widgets/app_navigation.dart';

class MainScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const MainScreen({super.key, required this.themeModeNotifier});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const home_screen.HomeScreen(),
      const scan_screen.ScanScreen(),
      const stats_screen.StatsScreen(), // เปลี่ยนเป็น StatsScreen
      settings_screen.SettingsScreen(themeModeNotifier: widget.themeModeNotifier),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: AppNavigation(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
