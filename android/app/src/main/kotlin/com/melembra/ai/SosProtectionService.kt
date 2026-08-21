package com.melembra.ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Foreground Service que exibe notificação persistente "Modo proteção ativo".
 *
 * Mantém o processo Android vivo, mas isso sozinho NÃO mantém nenhum código
 * Dart rodando: MainActivity usa o ciclo de vida padrão do FlutterActivity,
 * então o FlutterEngine (e tudo que roda nele) é destruído junto com a
 * Activity quando o usuário fecha o app. Por isso este serviço cria seu
 * próprio FlutterEngine headless (sem UI), rodando o entrypoint
 * `fallDetectorEntrypoint` (lib/main.dart) — é isso que mantém o detector de
 * queda funcionando de verdade com o app fechado. O canal "call" é
 * registrado nesse engine também, pra caso o detector precise ligar pro
 * contato de SOS.
 *
 * Iniciado e parado via MethodChannel "com.melembra.ai/protection".
 */
class SosProtectionService : Service() {

    companion object {
        private const val CHANNEL_ID = "sos_protection"
        private const val NOTIFICATION_ID = 9001

        fun start(context: Context) {
            val intent = Intent(context, SosProtectionService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SosProtectionService::class.java))
        }
    }

    private var flutterEngine: FlutterEngine? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        startHeadlessFlutterIfNeeded()
        return START_STICKY
    }

    override fun onDestroy() {
        flutterEngine?.destroy()
        flutterEngine = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startHeadlessFlutterIfNeeded() {
        if (flutterEngine != null) return
        val engine = FlutterEngine(applicationContext)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "fallDetectorEntrypoint"
            )
        )
        CallChannel.register(engine, applicationContext)
        flutterEngine = engine
    }

    private fun buildNotification(): Notification {
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val pendingIntent = PendingIntent.getActivity(this, 0, mainIntent, pendingFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Modo proteção ativo")
            .setContentText("Me Lembra Aí está monitorando emergências.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Modo Proteção",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitoramento de emergências em segundo plano"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
