class MessageModel {
  final int? id;
  final String messageText;
  final double scamProbability;
  final DateTime timestamp;
  final int? userFeedback; // 1 = scam, 0 = not scam, null = no feedback yet

  MessageModel({
    this.id,
    required this.messageText,
    required this.scamProbability,
    required this.timestamp,
    this.userFeedback,
  });

  /// สำหรับแปลงจาก SQLite Map
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],
      messageText: map['message_text'],
      scamProbability: (map['scam_probability'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      userFeedback: map['user_feedback'], // อาจเป็น null ได้
    );
  }

  /// สำหรับแปลงเป็น Map เพื่อเก็บใน SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message_text': messageText,
      'scam_probability': scamProbability,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'user_feedback': userFeedback,
    };
  }

  /// สำหรับแปลงจาก JSON (เช่น จาก API)
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      messageText: json['message_text'],
      scamProbability: (json['scam_probability'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      userFeedback: json['user_feedback'],
    );
  }

  /// สำหรับแปลงเป็น JSON (เช่น ส่งเข้า API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_text': messageText,
      'scam_probability': scamProbability,
      'timestamp': timestamp.toIso8601String(),
      'user_feedback': userFeedback,
    };
  }

  /// สำหรับ clone/แก้ไขบางค่า
  MessageModel copyWith({
    int? id,
    String? messageText,
    double? scamProbability,
    DateTime? timestamp,
    int? userFeedback,
  }) {
    return MessageModel(
      id: id ?? this.id,
      messageText: messageText ?? this.messageText,
      scamProbability: scamProbability ?? this.scamProbability,
      timestamp: timestamp ?? this.timestamp,
      userFeedback: userFeedback ?? this.userFeedback,
    );
  }
}
