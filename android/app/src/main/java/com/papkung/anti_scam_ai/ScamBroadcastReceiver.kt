package com.example.anti_scam_ai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.EventChannel

class ScamBroadcastReceiver(private val eventSink: EventChannel.EventSink?) : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == "com.papkung.antiscamai.SCAM_DETECTED") {
            val text = intent.getStringExtra("text")
            if (text != null && eventSink != null) {
                Log.d("ScamReceiver", "📡 ส่งข้อความไป Flutter: $text")
                eventSink.success(text)
            }
        }
    }
}
