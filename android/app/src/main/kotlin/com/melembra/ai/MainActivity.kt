package com.melembra.ai

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

        // Canal: Ligação automática SOS (lógica em CallChannel.kt, reaproveitada
        // também pelo FlutterEngine headless do detector de queda em segundo plano)
        CallChannel.register(flutterEngine, this)

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

