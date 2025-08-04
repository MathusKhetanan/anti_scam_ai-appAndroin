import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService {
  late Interpreter _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('models/sms_spam_model.tflite');
  }

  Future<bool> analyze(String message) async {
    // ต้องเขียน tokenizer ให้เหมือนกับ TextVectorizer ใน Python
    // สำหรับ demo: ใช้ input dummy ไปก่อน
    final input = List.filled(100, 0).reshape([1, 100]); // dummy
    final output = List.filled(1, 0.0).reshape([1, 1]);

    _interpreter.run(input, output);
    return output[0][0] > 0.5;
  }
}
