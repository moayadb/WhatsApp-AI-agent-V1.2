package com.sanayed.analyzer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // FCM never creates notification channels — if this one doesn't exist,
        // Android 8+ files every alert under the generic "Miscellaneous"
        // fallback and users can't tune Sanayed alerts in system settings.
        // createNotificationChannel is idempotent, so every launch is fine.
        //
        // The id must match BOTH the manifest meta-data
        // (default_notification_channel_id) and android.notification.channel_id
        // in the payload n8n sends (n8n/build-fcm-payloads.js).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "sanayed_alerts",
                // Shown in system settings. Arabic-first, like the app.
                "تنبيهات العملاء",
                // HIGH = heads-up banner + sound, matching the iOS behaviour.
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "تنبيهات فورية عند وصول رسالة عميل تحتاج تدخّل المدير"
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }
}
