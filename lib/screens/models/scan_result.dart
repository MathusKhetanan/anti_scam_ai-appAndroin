class ScanResult {
  final String id;
  final String message;
  final String prediction;
  final bool isScam;
  final DateTime timestamp;
  final String? source; // SMS, WhatsApp, etc.
  
  // เพิ่ม properties สำหรับ home_screen.dart
  final String sender;
  final DateTime dateTime;
  final double score;
  final String reason;

  ScanResult({
    required this.id,
    required this.message,
    required this.prediction,
    required this.isScam,
    required this.timestamp,
    this.source,
    // เพิ่ม parameters ใหม่
    required this.sender,
    DateTime? dateTime,
    this.score = 0.0,
    this.reason = '',
  }) : dateTime = dateTime ?? timestamp;

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'prediction': prediction,
      'isScam': isScam,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
      'sender': sender,
      'dateTime': dateTime.toIso8601String(),
      'score': score,
      'reason': reason,
    };
  }

  // Create from JSON
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      id: json['id'],
      message: json['message'],
      prediction: json['prediction'],
      isScam: json['isScam'],
      timestamp: DateTime.parse(json['timestamp']),
      source: json['source'],
      sender: json['sender'] ?? '',
      dateTime: json['dateTime'] != null ? DateTime.parse(json['dateTime']) : null,
      score: (json['score'] ?? 0.0).toDouble(),
      reason: json['reason'] ?? '',
    );
  }

  @override
  String toString() {
    return 'ScanResult(id: $id, prediction: $prediction, isScam: $isScam)';
  }
}