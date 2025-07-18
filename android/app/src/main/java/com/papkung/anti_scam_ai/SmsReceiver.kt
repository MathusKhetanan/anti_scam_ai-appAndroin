package com.example.anti_scam_ai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SmsReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val smsMessages = Telephony.Sms.Intents.getMessagesFromIntent(intent)

            for (smsMessage in smsMessages) {
                processSmsMessage(smsMessage)
            }
        }
    }

    private fun processSmsMessage(smsMessage: SmsMessage) {
        val phoneNumber = smsMessage.displayOriginatingAddress
        val messageBody = smsMessage.messageBody

        Log.d(TAG, "SMS received from $phoneNumber: $messageBody")

        analyzeSmsMessage(messageBody, phoneNumber)
    }

    private fun analyzeSmsMessage(message: String, phoneNumber: String) {
        val scamKeywords = listOf(
            "รางวัลใหญ่", "คลิกที่นี่", "ยืนยันบัตรเครดิต", "โอนเงินด่วน",
            "ลงทุนได้กำไรแน่นอน", "กดลิงก์", "แจ้งปิดบัญชี", "ด่วน! มีเงื่อนไข",
            "ได้รับเลือก", "กรุณาโอน", "รับรางวัล", "แจ้งเตือนธนาคาร",
            "OTP", "PIN", "รหัสผ่าน"
        )

        var riskScore = 0.0
        val detectedKeywords = mutableListOf<String>()

        for (keyword in scamKeywords) {
            if (message.contains(keyword, ignoreCase = true)) {
                riskScore += when (keyword) {
                    "ยืนยันบัตรเครดิต", "โอนเงินด่วน", "รางวัลใหญ่" -> 0.4
                    "OTP", "PIN", "รหัสผ่าน" -> 0.3
                    else -> 0.2
                }
                detectedKeywords.add(keyword)
            }
        }

        val urlPattern = Regex("""https?://[^\s]+""")
        if (urlPattern.containsMatchIn(message)) {
            riskScore += 0.3
            detectedKeywords.add("ลิงก์ที่น่าสงสัย")
        }

        if (isSuspiciousPhoneNumber(phoneNumber)) {
            riskScore += 0.2
            detectedKeywords.add("เบอร์โทรน่าสงสัย")
        }

        val riskLevel = when {
            riskScore >= 0.7 -> "สูง"
            riskScore >= 0.4 -> "กลาง"
            else -> "ต่ำ"
        }

        if (riskScore >= 0.4) {
            val alertData = mapOf(
                "message" to if (message.length > 50) "${message.substring(0, 50)}..." else message,
                "riskLevel" to riskLevel,
                "riskScore" to (riskScore * 100).coerceAtMost(100.0),
                "app" to "SMS",
                "phoneNumber" to phoneNumber,
                "detectedKeywords" to detectedKeywords,
                "timestamp" to System.currentTimeMillis(),
                "type" to "sms_scam_alert"
            )

            NotificationListenerService.eventSink?.success(alertData)

            Log.w(TAG, "Potential SMS scam detected from $phoneNumber: $message (Risk: $riskLevel)")
        }
    }

    private fun isSuspiciousPhoneNumber(phoneNumber: String): Boolean {
        val suspiciousPatterns = listOf(
            Regex("""^\+?1\d{10}$"""),
            Regex("""^\+?86\d{11}$"""),
            Regex("""^\+?91\d{10}$"""),
            Regex("""^0[2-9]\d{7}$"""),
            Regex("""^1\d{3}$""")
        )
        return suspiciousPatterns.any { it.matches(phoneNumber) }
    }
}
