// lib/screens/main/scan_screen.dart
import 'package:flutter/material.dart';
import '../../services/scam_detection_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ScamDetectionService _scamService = ScamDetectionService();
  final TextEditingController _controller = TextEditingController();

  String _resultText = '';
  bool _isScanning = false;

  Future<void> _onScanPressed() async {
    final message = _controller.text.trim();
    if (message.isEmpty) {
      setState(() {
        _resultText = 'กรุณากรอกข้อความก่อนสแกน';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _resultText = '';
    });

    try {
      final isScam = await _scamService.analyzeMessage(message);

      setState(() {
        _resultText = isScam
            ? '❗️ ข้อความน่าสงสัย! ระวังสแปมหรือหลอกลวง'
            : '✅ ข้อความปลอดภัย';
      });
    } catch (e) {
      setState(() {
        _resultText = 'เกิดข้อผิดพลาดในการวิเคราะห์: $e';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สแกนข้อความสแปม'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'พิมพ์ข้อความที่ต้องการตรวจสอบ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isScanning ? null : _onScanPressed,
              child: _isScanning
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('สแกนข้อความ'),
            ),
            const SizedBox(height: 24),
            Text(
              _resultText,
              style: TextStyle(
                fontSize: 18,
                color: _resultText.contains('น่าสงสัย')
                    ? Colors.red
                    : Colors.green,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
