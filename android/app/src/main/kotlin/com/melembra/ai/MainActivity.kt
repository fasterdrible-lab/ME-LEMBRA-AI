package com.melembra.ai

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.telecom.TelecomManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Volume-key SOS: 5 pressionamentos em até 3 segundos dispara o SOS
    private val volumePressTimes = mutableListOf<Long>()
    private val volumeSosPressCount = 5
    private val volumeSosWindowMs = 3000L
    private var volumeSosEnabled = false
    private var volumeSosEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal: Widget de lembretes
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.melembra.ai/widget"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    RemindersWidget.updateAll(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Canal: Ligação automática SOS
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.melembra.ai/call"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "callNumber" -> {
                    val number = call.arguments as? String
                    if (!number.isNullOrBlank()) {
                        try {
                            placeCallReliable(number)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CALL_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_NUMBER", "Número SOS não configurado", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Canal: Foreground Service "Modo proteção ativo"
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.melembra.ai/protection"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    SosProtectionService.start(this)
                    result.success(null)
                }
                "stop" -> {
                    SosProtectionService.stop(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Canal: Ativar/desativar captura de teclas de volume para SOS
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.melembra.ai/volume_sos_control"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable"  -> { volumeSosEnabled = true;  result.success(null) }
                "disable" -> { volumeSosEnabled = false; volumePressTimes.clear(); result.success(null) }
                else -> result.notImplemented()
            }
        }

        // EventChannel: Notifica Flutter quando a sequência de volume é detectada
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.melembra.ai/volume_sos_events"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                volumeSosEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                volumeSosEventSink = null
            }
        })
    }

    /**
     * Liga usando TelecomManager.placeCall(), o caminho recomendado pelo Android
     * para apps discarem sem passar pela tela do discador (UserCallActivity).
     * Em alguns aparelhos/operadoras, uma chamada via Intent.ACTION_CALL
     * disparada por app de terceiros é cancelada pelo próprio discador do
     * fabricante poucos segundos depois de iniciar — placeCall() evita essa
     * tela intermediária. Mantém o Intent.ACTION_CALL como fallback.
     */
    private fun placeCallReliable(number: String) {
        val uri = Uri.fromParts("tel", number, null)
        val temPermissao = checkSelfPermission(Manifest.permission.CALL_PHONE) ==
            PackageManager.PERMISSION_GRANTED

        if (temPermissao) {
            try {
                val telecomManager = getSystemService(TELECOM_SERVICE) as TelecomManager
                telecomManager.placeCall(uri, null)
                return
            } catch (e: SecurityException) {
                // cai para o Intent abaixo
            }
        }

        val intent = Intent(Intent.ACTION_CALL, uri)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    /**
     * Captura pressionamentos de teclas de volume quando o app está em foreground.
     * 5 pressionamentos dentro de [volumeSosWindowMs] ms disparam o SOS.
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (volumeSosEnabled &&
            (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP)) {
            val now = System.currentTimeMillis()
            volumePressTimes.add(now)
            // Remove pressionamentos fora da janela de tempo
            volumePressTimes.removeAll { now - it > volumeSosWindowMs }

            if (volumePressTimes.size >= volumeSosPressCount) {
                volumePressTimes.clear()
                volumeSosEventSink?.success("sos")
                return true // consome o evento (não altera o volume)
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}

