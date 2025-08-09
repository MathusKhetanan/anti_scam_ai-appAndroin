class ScanResult {
  final String id; // ไอดีข้อความ (unique)
  final String sender; // ผู้ส่งข้อความ
  final String message; // เนื้อความ
  final String prediction; // ผลการทำนาย ('scam' / 'safe' / 'unknown')
  final double probability; // ความมั่นใจของ AI (0..1)  -> มีค่า default
  final DateTime dateTime; // เวลาแสดงผล
  final DateTime timestamp; // เวลา raw
  final String reason; // เหตุผลที่ตัดสินใจ
  final bool isScam; // true = มิจฉาชีพ
  final String label; // label ของ AI            -> มีค่า default
  final double score; // คะแนนความมั่นใจ (เผื่อ API ใช้สเกลอื่น)

  ScanResult({
    required this.id,
    required this.sender,
    required this.message,
    required this.prediction,
    this.probability = 0.0, // ✅ default
    required this.dateTime,
    required this.timestamp,
    required this.reason,
    required this.isScam,
    this.label = 'safe', // ✅ default
    required this.score,
  });

  ScanResult copyWith({
    String? id,
    String? sender,
    String? message,
    String? prediction,
    double? probability,
    DateTime? dateTime,
    DateTime? timestamp,
    String? reason,
    bool? isScam,
    String? label,
    double? score,
  }) {
    return ScanResult(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      message: message ?? this.message,
      prediction: prediction ?? this.prediction,
      probability: probability ?? this.probability,
      dateTime: dateTime ?? this.dateTime,
      timestamp: timestamp ?? this.timestamp,
      reason: reason ?? this.reason,
      isScam: isScam ?? this.isScam,
      label: label ?? this.label,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'message': message,
        'prediction': prediction,
        'probability': probability,
        'dateTime': dateTime.toIso8601String(),
        'timestamp': timestamp.toIso8601String(),
        'reason': reason,
        'isScam': isScam,
        'label': label,
        'score': score,
      };

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        id: json['id']?.toString() ?? '',
        sender: json['sender']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        prediction: (json['prediction'] ?? 'unknown').toString(),
        probability: (json['probability'] is num)
            ? (json['probability'] as num).toDouble()
            : 0.0, // ✅ รองรับ cache เก่าที่ไม่มี field
        dateTime: DateTime.tryParse((json['dateTime'] ?? '').toString()) ??
            DateTime.now(),
        timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
            DateTime.now(),
        reason: (json['reason'] ?? '').toString(),
        isScam: (json['isScam'] ?? false) == true,
        label: (json['label'] ?? 'safe').toString(), // ✅ default
        score: (json['score'] is num) ? (json['score'] as num).toDouble() : 0.0,
      );
}
