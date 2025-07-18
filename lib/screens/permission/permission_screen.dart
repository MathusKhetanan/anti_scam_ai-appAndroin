import 'package:flutter/material.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ขอสิทธิ์การเข้าถึง SMS'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
              size: 80,
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 24),
            const Text(
              'แอปต้องการสิทธิ์ในการเข้าถึงข้อความ SMS ของคุณ\nโปรดอนุญาตสิทธิ์ในหน้าการตั้งค่าของเครื่อง',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('ไปที่การตั้งค่า'),
              onPressed: () {
                // ปกติจะเปิดหน้า Setting ได้ด้วย package เช่น app_settings
                // แต่ที่นี่ทำแค่ pop กลับไปหน้าเดิมก่อน
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
