// test/flutter_test_config.dart
import 'dart:io';

Future<void> testExecutable(Future<void> Function() testMain) async {
  // ตั้งค่า current directory ให้มองเห็น assets
  Directory.current = Directory('./');
  await testMain();
}
