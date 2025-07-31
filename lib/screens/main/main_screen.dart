import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'user_screen.dart';
import 'bottom_nav_bar.dart';
import '../models/scan_result.dart'; // เพิ่ม import

class MainScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const MainScreen({super.key, required this.themeModeNotifier});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  // เพิ่ม list สำหรับเก็บ scan results
  List<ScanResult> _scanResults = [];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // สร้าง list ของหน้าจอ พร้อมส่งพารามิเตอร์ที่จำเป็น
    _screens = [
      const HomeScreen(),
      const ScanScreen(),
      StatsScreen(scanResults: _scanResults), // เพิ่ม scanResults parameter
      SettingsScreen(themeModeNotifier: widget.themeModeNotifier),
      const UserScreen(),
    ];
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // เพิ่ม method สำหรับอัพเดท scan results
  void _updateScanResults(List<ScanResult> newResults) {
    setState(() {
      _scanResults = newResults;
      // อัพเดท StatsScreen ด้วย
      _screens[2] = StatsScreen(scanResults: _scanResults);
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