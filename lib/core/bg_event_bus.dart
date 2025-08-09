// lib/core/bg_event_bus.dart
import 'dart:async';

class BgUpdate {
  final String sender;
  final String text;
  final String label;
  final double score;
  final bool isScam;
  final int timestampMs;

  BgUpdate({
    required this.sender,
    required this.text,
    required this.label,
    required this.score,
    required this.isScam,
    required this.timestampMs,
  });

  factory BgUpdate.fromMap(Map data) {
    final label = (data['label']?.toString() ?? 'safe').toLowerCase();
    final score = double.tryParse(data['score']?.toString() ?? '0') ?? 0.0;
    return BgUpdate(
      sender: data['sender']?.toString() ?? 'ไม่ทราบเบอร์',
      text: data['text']?.toString() ?? '',
      label: label,
      score: score,
      isScam: data['isScam'] == true || label == 'scam',
      timestampMs: int.tryParse('${data['timestampMs'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'sender': sender,
        'text': text,
        'label': label,
        'score': score,
        'isScam': isScam,
        'timestampMs': timestampMs,
      };
}

class BgEventBus {
  static final _controller = StreamController<BgUpdate>.broadcast();
  static Stream<BgUpdate> get stream => _controller.stream;
  static void emit(BgUpdate e) => _controller.add(e);
}
