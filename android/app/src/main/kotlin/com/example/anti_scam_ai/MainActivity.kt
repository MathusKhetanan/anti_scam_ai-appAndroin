package com.example.anti_scam_ai

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "message_monitor"
    private val EVENT_CHANNEL = "com.example.anti_scam_ai/accessibility"
    private val BG_NOTIFY_CHANNEL = "bg_notifier"
    private val BG_UPDATES_EVENT = "com.example.anti_scam_ai/bg_updates"

    private val SMS_PERMISSION_REQUEST_CODE = 1001
    private val NOTIFICATION_PERMISSION_REQUEST_CODE = 1002

    // Android notification channel ids
    private val ANDROID_CHANNEL_ID = "sms_alerts"
    private val ANDROID_CHANNEL_NAME = "SMS Alerts"

    // เก็บผลลัพธ์ callback ของ permission request ไว้ตอบกลับ Flutter
    private var permissionResult: MethodChannel.Result? = null

    companion object {
        var sharedEventSink: EventChannel.EventSink? = null
        var bgUpdatesSink: EventChannel.EventSink? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        android.util.Log.d("MainActivity", "🚀 configureFlutterEngine called!")

        // ---------- MethodChannel หลัก ----------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkPermissions" -> {
                        val smsGranted =
                            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                        val phoneGranted =
                            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
                        val notificationGranted =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                            } else {
                                true
                            }
                        val notificationListenerGranted = isNotificationServiceEnabled()
                        val accessibilityGranted = isAccessibilityServiceEnabled()

                        val map = mapOf(
                            "sms" to smsGranted,
                            "phone" to phoneGranted,
                            "notification" to notificationGranted,
                            "notificationListener" to notificationListenerGranted,
                            "accessibility" to accessibilityGranted
                        )
                        result.success(map)
                    }

                    "requestSmsPermission" -> requestSmsPermissions(result)

                    "requestNotificationListenerPermission" -> {
                        try {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("error", "Failed to open notification listener settings: ${e.message}", null)
                        }
                    }

                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            val notificationGranted = ContextCompat.checkSelfPermission(
                                this, Manifest.permission.POST_NOTIFICATIONS
                            ) == PackageManager.PERMISSION_GRANTED
                            if (notificationGranted) {
                                result.success(true)
                            } else {
                                if (permissionResult != null) {
                                    result.error("already_requesting", "Permission request is already in progress.", null)
                                    return@setMethodCallHandler
                                }
                                permissionResult = result
                                ActivityCompat.requestPermissions(
                                    this,
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    NOTIFICATION_PERMISSION_REQUEST_CODE
                                )
                            }
                        } else {
                            result.success(true)
                        }
                    }

                    "requestAccessibilityPermission" -> {
                        try {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("error", "Failed to open accessibility settings: ${e.message}", null)
                        }
                    }

                    "openAppSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = Uri.parse("package:$packageName")
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("error", "Failed to open app settings: ${e.message}", null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // ---------- EventChannel Accessibility ----------
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sharedEventSink = events
                    events?.success("🔥 Accessibility EventChannel connected!")
                }

                override fun onCancel(arguments: Any?) {
                    sharedEventSink = null
                }
            })

        // ---------- EventChannel สำหรับ BG updates ----------
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BG_UPDATES_EVENT)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    bgUpdatesSink = events
                    android.util.Log.d("MainActivity", "✅ BG updates channel connected")
                }

                override fun onCancel(arguments: Any?) {
                    bgUpdatesSink = null
                }
            })

        // ---------- BG NOTIFIER: ยิง Notification + ส่ง Event ----------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BG_NOTIFY_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "notify") {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    try {
                        // 1) เด้ง Notification
                        showNotificationFromArgs(args)

                        // 2) ส่ง Event ให้ Flutter ถ้ามี listener
                        try {
                            bgUpdatesSink?.success(args)
                            android.util.Log.d("MainActivity", "📡 Sent BG update event to Flutter")
                        } catch (e: Exception) {
                            android.util.Log.w("MainActivity", "Failed to emit BG update: ${e.message}")
                        }

                        result.success(true)
                    } catch (e: Exception) {
                        result.error("notify_error", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun showNotificationFromArgs(args: Map<*, *>) {
        val title = (args["title"] as? String) ?: "Anti-Scam AI"
        val body = (args["body"] as? String) ?: ""

        ensureNotificationChannel()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                android.util.Log.w("MainActivity", "No POST_NOTIFICATIONS permission")
                return
            }
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, piFlags)

        val smallIcon = applicationInfo.icon.takeIf { it != 0 } ?: android.R.drawable.ic_dialog_info

        val notification = NotificationCompat.Builder(this, ANDROID_CHANNEL_ID)
            .setSmallIcon(smallIcon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(this).notify(
            (System.currentTimeMillis() % Int.MAX_VALUE).toInt(),
            notification
        )
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ANDROID_CHANNEL_ID,
                ANDROID_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply { description = "Anti-Scam alerts for incoming SMS" }

            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun requestSmsPermissions(result: MethodChannel.Result) {
        val permissionsToRequest = mutableListOf<String>()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.READ_SMS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.RECEIVE_SMS)
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.READ_PHONE_STATE)
        }

        if (permissionsToRequest.isEmpty()) {
            result.success(true)
        } else {
            if (permissionResult != null) {
                result.error("already_requesting", "Permission request is already in progress.", null)
                return
            }
            permissionResult = result
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest.toTypedArray(),
                SMS_PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return !enabledListeners.isNullOrEmpty() && enabledListeners.contains(packageName)
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityEnabled = Settings.Secure.getInt(contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 0)
        if (accessibilityEnabled == 0) return false
        val enabledServices = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        return !enabledServices.isNullOrEmpty() && enabledServices.contains(packageName)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        when (requestCode) {
            SMS_PERMISSION_REQUEST_CODE -> {
                val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                permissionResult?.success(granted)
                permissionResult = null
            }
            NOTIFICATION_PERMISSION_REQUEST_CODE -> {
                val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
                permissionResult?.success(granted)
                permissionResult = null
            }
            else -> {
                super.onRequestPermissionsResult(requestCode, permissions, grantResults)
            }
        }
    }
}
