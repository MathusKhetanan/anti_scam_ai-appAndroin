class ScamDetector {
  // แบ่ง keyword เป็นกลุ่ม ร้ายแรงกับทั่วไป
  static final List<String> highRiskKeywords = [
    'รางวัล', 'ชนะ', 'แจ็คพอต', 'โบนัส', 'ฟรี', 'รับเงิน'
  ];

  static final List<String> mediumRiskKeywords = [
    'โอนเงิน', 'บัญชี', 'OTP', 'ฝาก', 'แจ้งเตือน', 'ยืนยัน', 'โอน'
  ];

  // ฟังก์ชัน normalize ข้อความ เช่น ตัดช่องว่าง, lower case
  static String normalize(String text) {
    return text.trim().toLowerCase();
  }

  // คำนวณ score ความน่าจะเป็น scam (0.0-1.0)
  static double scamProbability(String message) {
    final normalized = normalize(message);

    int score = 0;

    for (var kw in highRiskKeywords) {
      if (normalized.contains(kw)) {
        score += 3; // น้ำหนักสูง
      }
    }

    for (var kw in mediumRiskKeywords) {
      if (normalized.contains(kw)) {
        score += 1; // น้ำหนักปานกลาง
      }
    }

    // กำหนด max score สมมติว่า 15
    final maxScore = highRiskKeywords.length * 3 + mediumRiskKeywords.length;

    double probability = score / maxScore;

    // ตัดให้ไม่เกิน 1.0
    return probability.clamp(0.0, 1.0);
  }

  // เช็คว่าเป็น scam หรือไม่โดยใช้ threshold (default 0.5)
  static bool isScam(String message, {double threshold = 0.5}) {
    return scamProbability(message) >= threshold;
  }
}
