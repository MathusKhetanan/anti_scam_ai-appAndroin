  import 'package:flutter/material.dart';

  class AppNavigation extends StatelessWidget {
    final int currentIndex;
    final ValueChanged<int> onTap;

    const AppNavigation({
      Key? key,
      required this.currentIndex,
      required this.onTap,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      final theme = Theme.of(context);
      return BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.disabledColor,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'หน้าหลัก',
            tooltip: 'แสดงภาพรวมการป้องกัน และสถิติประจำวัน',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'ตรวจสอบ',
            tooltip: 'สแกน SMS ด้วยตนเอง และแสดงผลวิเคราะห์',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'สถิติ',
            tooltip: 'สรุปสถิติการตรวจสอบย้อนหลัง',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'ตั้งค่า',
            tooltip: 'ตั้งค่าการแจ้งเตือนและกฎการตรวจจับ',
          ),
          BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'ผู้ใช้',
          tooltip: 'เข้าสู่ระบบ / บัญชีผู้ใช้',
        ),
        ],
      );
    }
  }
