package com.example.anti_scam_ai

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.EventChannel

class NotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "NotificationListener"
        private val MONITORED_APPS = setOf(
            "com.linecorp.line.android",
            "com.whatsapp",
            "com.facebook.orca",
            "org.telegram.messenger",
            "com.viber.voip",
            "com.android.mms",
            "com.google.android.apps.messaging"
        )

        var instance: NotificationListenerService? = null
        var eventSink: EventChannel.EventSink? = null
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "NotificationListenerService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.d(TAG, "NotificationListenerService destroyed")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)

        sbn?.let { notification ->
            val packageName = notification.packageName

            if (MONITORED_APPS.contains(packageName)) {
                processNotification(notification)
            }
        }
    }

    private fun processNotification(sbn: StatusBarNotification) {
        try {
            val extras = sbn.notification?.extras
            if (extras != null) {
                val title = extras.getCharSequence("android.title")?.toString() ?: ""
                val text = extras.getCharSequence("android.text")?.toString() ?: ""
                val bigText = extras.getCharSequence("android.bigText")?.toString() ?: text

                val messageData = mapOf(
                    "app" to getAppName(sbn.packageName),
                    "title" to title,
                    "message" to bigText,
                    "packageName" to sbn.packageName,
                    "timestamp" to System.currentTimeMillis()
                )

                eventSink?.success(messageData)

                analyzeMessage(bigText, getAppName(sbn.packageName))

                Log.d(TAG, "Message from ${getAppName(sbn.packageName)}: $bigText")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification: ${e.message}")
        }
    }

    private fun getAppName(packageName: String): String {
        return when (packageName) {
            "com.linecorp.line.android" -> "LINE"
            "com.whatsapp" -> "WhatsApp"
            "com.facebook.orca" -> "Messenger"
            "org.telegram.messenger" -> "Telegram"
            "com.viber.voip" -> "Viber"
            "com.android.mms", "com.google.android.apps.messaging" -> "SMS"
            else -> packageName
        }
    }

    private fun analyzeMessage(message: String, appName: String) {
        val scamKeywords = listOf(
            "รางวัลใหญ่", "คลิกที่นี่", "ยืนยันบัตรเครดิต", "โอนเงินด่วน",
            "ลงทุนได้กำไรแน่นอน", "กดลิงก์", "แจ้งปิดบัญชี", "ด่วน! มีเงื่อนไข",
            "ได้รับเลือก", "กรุณาโอน", "รับรางวัล", "แจ้งเตือนธนาคาร"
        )

        var riskScore = 0.0
        val detectedKeywords = mutableListOf<String>()

        for (keyword in scamKeywords) {
            if (message.contains(keyword, ignoreCase = true)) {
                riskScore += 0.3
                detectedKeywords.add(keyword)
            }
        }

        val urlPattern = Regex("""https?://[^\s]+""")
        if (urlPattern.containsMatchIn(message)) {
            riskScore += 0.2
            detectedKeywords.add("ลิงก์ที่น่าสงสัย")
        }

        val phonePattern = Regex("""\b0[0-9]{8,9}\b""")
        if (phonePattern.containsMatchIn(message)) {
            riskScore += 0.1
        }

        val riskLevel = when {
            riskScore >= 0.6 -> "สูง"
            riskScore >= 0.3 -> "กลาง"
            else -> "ต่ำ"
        }

        if (riskScore >= 0.3) {
            val alertData = mapOf(
                "message" to if (message.length > 50) "${message.substring(0, 50)}..." else message,
                "riskLevel" to riskLevel,
                "riskScore" to (riskScore * 100).coerceAtMost(100.0),
                "app" to appName,
                "detectedKeywords" to detectedKeywords,
                "timestamp" to System.currentTimeMillis(),
                "type" to "scam_alert"
            )

            eventSink?.success(alertData)
            Log.w(TAG, "Potential scam detected in $appName: $message (Risk: $riskLevel)")
        }
    }
}
