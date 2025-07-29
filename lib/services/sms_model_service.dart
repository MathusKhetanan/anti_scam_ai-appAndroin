import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:flutter/foundation.dart' show compute;

import 'package:flutter/services.dart' show rootBundle;

class SMSModelService {
  static late Interpreter _interpreter;
  static late Tokenizer _tokenizer; // สมมติมีคลาสนี้ในโปรเจกต์ หรือใช้วิธีโหลดจาก tokenizer.pkl ในรูปแบบ JSON

  static const int maxLen = 100;

  static Future<void> init() async {
    // โหลดโมเดลจากไฟล์ assets
    final interpreterOptions = InterpreterOptions();
    _interpreter = await Interpreter.fromAsset('sms_model.tflite', options: interpreterOptions);

    // โหลด tokenizer
    final tokenizerJson = await rootBundle.loadString('assets/tokenizer.json');
    _tokenizer = Tokenizer.fromJson(jsonDecode(tokenizerJson));

    print("Model and tokenizer loaded");
  }

  static List<int> tokenize(String text) {
    // แปลงข้อความเป็นลำดับเลขโดยใช้ tokenizer
    return _tokenizer.textsToSequences([text])[0];
  }

  static List<int> padSequence(List<int> sequence) {
    if (sequence.length > maxLen) {
      return sequence.sublist(0, maxLen);
    } else if (sequence.length < maxLen) {
      return sequence + List.filled(maxLen - sequence.length, 0);
    }
    return sequence;
  }

  static double predict(String message) {
    final tokens = padSequence(tokenize(message));
    var input = [tokens];
    var output = List.filled(1, 0.0).reshape([1, 1]);
    _interpreter.run(input, output);
    return output[0][0];
  }
}
