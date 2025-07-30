import 'package:flutter_test/flutter_test.dart';
import 'package:anti_scam_ai/services/sms_model_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();  // เพิ่มบรรทัดนี้

  group('SMSModelService Tests', () {
    late SMSModelService modelService;

    setUpAll(() async {
      modelService = SMSModelService.instance;
      // Try to initialize, but don't fail if model files don't exist
      try {
        await modelService.init();
      } catch (e) {
        print('Model initialization failed, will use fallback: $e');
      }
    });

    test('should get SMS model service instance', () {
      expect(modelService, isNotNull);
      expect(modelService, equals(SMSModelService.instance)); // Singleton test
    });

    test('should analyze spam message', () async {
      // Test with a sample spam message - escape the dollar sign
      final spamMessage = "Congratulations! You've won \$1000. Click here to claim your prize!";

      final result = await modelService.analyze(spamMessage);
      expect(result, isA<bool>());

      // This should likely be detected as spam due to keywords
      expect(result, isTrue);
    });

    test('should analyze legitimate message', () async {
      final legitimateMessage = "Hi, how are you today? Let's meet for lunch.";

      final result = await modelService.analyze(legitimateMessage);
      expect(result, isA<bool>());

      // This should likely be detected as not spam
      expect(result, isFalse);
    });

    test('should handle empty message', () async {
      final result = await modelService.analyze("");
      expect(result, isA<bool>());
      // Empty message should not be spam
      expect(result, isFalse);
    });

    test('should work with classifyMessage method', () async {
      final testMessage = "Free money! Click now!";
      final result = await modelService.classifyMessage(testMessage);
      expect(result, isA<bool>());
    });

    test('should work with predictSpam method', () async {
      final testMessage = "Hello, this is a normal message";
      final result = await modelService.predictSpam(testMessage);
      expect(result, isA<bool>());
    });

    test('should provide detailed analysis', () async {
      final testMessage = "Urgent! Limited time offer!";
      final result = await modelService.analyzeDetailed(testMessage);

      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('isSpam'), isTrue);
      expect(result.containsKey('confidence'), isTrue);
      expect(result.containsKey('method'), isTrue);
      expect(result.containsKey('modelReady'), isTrue);
    });

    test('should handle Thai spam keywords', () async {
      final thaiSpamMessage = "ยินดีด้วย! คุณได้รางวัล เงินฟรี!";
      final result = await modelService.analyze(thaiSpamMessage);
      expect(result, isA<bool>());
      // Should detect Thai spam keywords
      expect(result, isTrue);
    });
  });
}
