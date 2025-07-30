import 'dart:async';
import 'dart:convert'; // Add this missing import
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SMSModelService {
  SMSModelService._privateConstructor();
  static final SMSModelService instance = SMSModelService._privateConstructor();

  late Interpreter _interpreter;
  late Tokenizer _tokenizer;

  // Fixed file paths to match pubspec.yaml
  static const String modelFile = 'models/sms_spam_model.tflite';
  static const String tokenizerFile = 'assets/models/tokenizer.json';

  bool _isReady = false;

  /// เริ่มต้นโหลดโมเดลและ tokenizer
  Future<void> init() async {
    if (_isReady) return;
    try {
      await loadModel();
      await loadTokenizer();
      _isReady = true;
      print('✅ SMS Model Service initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize SMS Model Service: $e');
      // Don't rethrow - allow graceful fallback
    }
  }

  /// โหลดโมเดล tflite จาก assets
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(modelFile);
      print('✅ Loaded TFLite model');
    } catch (e) {
      print('❌ Failed to load model: $e');
      rethrow;
    }
  }

  /// โหลด tokenizer (สมมุติใช้ไฟล์ JSON)
  Future<void> loadTokenizer() async {
    try {
      final jsonString = await rootBundle.loadString(tokenizerFile);
      _tokenizer = Tokenizer.fromJson(jsonString);
      print('✅ Loaded tokenizer');
    } catch (e) {
      print('❌ Failed to load tokenizer: $e');
      rethrow;
    }
  }

  /// วิเคราะห์ข้อความ SMS ว่าเป็นมิจฉาชีพหรือไม่
  /// คืนค่า true = spam / false = not spam
  Future<bool> analyze(String text) async {
    if (!_isReady) {
      print('⚠️ Model not ready, using fallback detection');
      return _fallbackSpamDetection(text);
    }

    try {
      // แปลงข้อความเป็น tokens ตาม tokenizer ที่โหลดมา
      List<int> inputIds = _tokenizer.tokenize(text);

      // แปลงเป็น tensor input shape ตามโมเดล (เช่น [1, sequenceLength])
      var input = List.filled(100, 0);
      for (int i = 0; i < inputIds.length && i < 100; i++) {
        input[i] = inputIds[i];
      }

      // Fixed output tensor creation
      var output = List.generate(1, (index) => List.filled(1, 0.0));

      _interpreter.run([input], output);

      double score = output[0][0];
      print('🧠 AI score: $score');

      // สมมุติ threshold 0.5
      return score > 0.5;
    } catch (e) {
      print('❌ ML analysis failed: $e, using fallback');
      return _fallbackSpamDetection(text);
    }
  }

  /// Fallback spam detection using keywords
  bool _fallbackSpamDetection(String text) {
    final spamKeywords = [
      'congratulations', 'winner', 'prize', 'free', 'urgent', 'limited time',
      'click here', 'call now', 'cash', 'money', 'lottery', 'reward',
      'bitcoin', 'investment', 'loan', 'credit', 'debt', 'offer',
      'ยินดี', 'รางวัล', 'ฟรี', 'เงิน', 'ด่วน', 'กดลิงก์', 'โอนเงิน'
    ];

    final lowerText = text.toLowerCase();
    int spamScore = 0;

    for (final keyword in spamKeywords) {
      if (lowerText.contains(keyword.toLowerCase())) {
        spamScore++;
      }
    }

    final isSpam = spamScore >= 2;
    print('🔍 Keyword-based detection: score=$spamScore, isSpam=$isSpam');
    return isSpam;
  }

  /// Additional methods for testing compatibility
  Future<bool> classifyMessage(String message) async {
    return await analyze(message);
  }

  Future<bool> predictSpam(String message) async {
    return await analyze(message);
  }

  Future<Map<String, dynamic>> analyzeDetailed(String text) async {
    final isSpam = await analyze(text);
    return {
      'isSpam': isSpam,
      'confidence': isSpam ? 0.8 : 0.2,
      'method': _isReady ? 'ml_model' : 'keyword_fallback',
      'modelReady': _isReady,
    };
  }

  /// ปิดทรัพยากร
  void dispose() {
    _interpreter.close();
    _isReady = false;
  }
}

/// ตัวช่วยแปลงข้อความเป็น token (คร่าว ๆ)
class Tokenizer {
  final Map<String, int> _wordIndex;

  Tokenizer(this._wordIndex);

  factory Tokenizer.fromJson(String jsonString) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(
      json.decode(jsonString) as Map,
    );
    return Tokenizer(map.map((key, value) => MapEntry(key, value as int)));
  }

  List<int> tokenize(String text) {
    final words = text.toLowerCase().split(RegExp(r'\W+'));
    return words.map((word) => _wordIndex[word] ?? 0).toList();
  }
}