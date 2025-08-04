import 'package:flutter_test/flutter_test.dart';
import 'package:anti_scam_ai/services/sms_model_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SMS Model Service Tests', () {
    final service = SMSModelService.instance;

    setUpAll(() async {
      await service.init();
    });

    test('Detects spam message', () async {
      final isSpam = await service.analyze('คุณได้รับรางวัลฟรี กดลิงก์ที่นี่!');
      expect(isSpam, true);
    });

    test('Detects legitimate message', () async {
      final isSpam = await service.analyze('วันนี้อากาศดีมาก');
      expect(isSpam, false);
    });
  });
}
