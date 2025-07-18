package com.papkung.antiscamai

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import io.flutter.plugin.common.EventChannel

class MyAccessibilityService : AccessibilityService() {

    companion object {
        var eventSink: EventChannel.EventSink? = null
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (event.eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {

            val rawText = event.text?.joinToString(" ")?.trim() ?: return
            if (rawText.isBlank()) return

            Log.d("AccessibilityLog", "📄 ข้อความ: $rawText")

            // ส่งข้อความไป Flutter ผ่าน EventSink
            eventSink?.success(rawText)
        }
    }

    override fun onInterrupt() {
        Log.d("AccessibilityLog", "🚫 การทำงานถูกขัดจังหวะ")
    }
}
