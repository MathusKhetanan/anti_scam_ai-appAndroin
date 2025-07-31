class ScanResult {
  final String id;
  final String sender;
  final String message;
  final bool isScam;
  final DateTime dateTime;
  final double score;
  final String reason;

  ScanResult({
    required this.id,
    required this.sender,
    required this.message,
    required this.isScam,
    required this.dateTime,
    required this.score,
    required this.reason,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'message': message,
      'isScam': isScam,
      'dateTime': dateTime.toIso8601String(),
      'score': score,
      'reason': reason,
    };
  }

  // Create from JSON
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      id: json['id'] ?? '',
      sender: json['sender'] ?? '',
      message: json['message'] ?? '',
      isScam: json['isScam'] ?? false,
      dateTime: DateTime.tryParse(json['dateTime'] ?? '') ?? DateTime.now(),
      score: (json['score'] ?? 0.0).toDouble(),
      reason: json['reason'] ?? '',
    );
  }

  // Copy with modifications
  ScanResult copyWith({
    String? id,
    String? sender,
    String? message,
    bool? isScam,
    DateTime? dateTime,
    double? score,
    String? reason,
  }) {
    return ScanResult(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      message: message ?? this.message,
      isScam: isScam ?? this.isScam,
      dateTime: dateTime ?? this.dateTime,
      score: score ?? this.score,
      reason: reason ?? this.reason,
    );
  }
}