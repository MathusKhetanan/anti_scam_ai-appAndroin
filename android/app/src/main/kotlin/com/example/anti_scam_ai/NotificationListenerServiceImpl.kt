package com.example.anti_scam_ai

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.EventChannel

class NotificationListenerServiceImpl : NotificationListenerService() {

    companion object {
        // ตัวแปรสำหรับส่งข้อมูลกลับ Flutter ผ่าน EventChannel
        @Volatile
        var eventSink: EventChannel.EventSink? = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName ?: return
        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""

        Log.d("NotificationListener", "Notification from $packageName : $title - $text")

        val message = "[$packageName] $title : $text"

        try {
            eventSink?.success(message)
        } catch (e: Exception) {
            Log.e("NotificationListener", "Failed to send event: ${e.message}")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // ไม่ต้องทำอะไร ถ้าไม่ต้องการ handle การลบ notification
    }
}
