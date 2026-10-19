package com.niosmess.pulse

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class BluetoothMeshKeepAliveService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel("mesh", "Bluetooth", NotificationManager.IMPORTANCE_LOW))
        }
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "mesh") else Notification.Builder(this)
        val notification = builder.setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentTitle("NiosMess · Bluetooth")
            .setContentText("Передача зашифрованных сообщений рядом")
            .setContentIntent(open).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 29) {
            val type = if (Build.VERSION.SDK_INT >= 31) ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                       else ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            startForeground(17482, notification, type)
        } else startForeground(17482, notification)
        return START_NOT_STICKY
    }
}
