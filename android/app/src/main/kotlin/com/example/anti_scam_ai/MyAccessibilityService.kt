package com.example.anti_scam_ai

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class MyAccessibilityService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        // ตรวจจับเฉพาะ event ที่สนใจ
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) {
            val rawText = event.text?.joinToString(" ")?.trim() ?: return
            if (rawText.isBlank()) return

            val sourceApp = event.packageName?.toString() ?: "unknown"

            Log.d("AccessibilityLog", "📲 จากแอป: $sourceApp | 📄 ข้อความ: $rawText")

            val scamData = mapOf(
                "app" to sourceApp,
                "text" to rawText
            )

            // ส่งข้อมูลกลับ Flutter ผ่าน EventSink
            MainActivity.sharedEventSink?.success(scamData)
        }
    }

    override fun onInterrupt() {
        Log.d("AccessibilityLog", "🚫 AccessibilityService ถูกขัดจังหวะ")
    }
}
