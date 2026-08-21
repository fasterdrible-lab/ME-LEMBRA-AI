package com.melembra.ai

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.telecom.TelecomManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Registro do canal "com.melembra.ai/call" (ligação automática do SOS).
 *
 * Extraído de MainActivity pra poder ser reaproveitado também pelo
 * FlutterEngine headless criado por SosProtectionService (detector de
 * queda com o app fechado) — TelecomManager.placeCall() e
 * startActivity(..., FLAG_ACTIVITY_NEW_TASK) funcionam com qualquer
 * Context, não só Activity, então essa extração não muda o comportamento
 * do caminho em primeiro plano.
 */
object CallChannel {
    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "com.melembra.ai/call"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "callNumber" -> {
                    val number = call.arguments as? String
                    if (!number.isNullOrBlank()) {
                        try {
                            placeCallReliable(context, number)
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
    }

    /**
     * Liga usando TelecomManager.placeCall(), o caminho recomendado pelo Android
     * para apps discarem sem passar pela tela do discador (UserCallActivity).
     * Em alguns aparelhos/operadoras, uma chamada via Intent.ACTION_CALL
     * disparada por app de terceiros é cancelada pelo próprio discador do
     * fabricante poucos segundos depois de iniciar — placeCall() evita essa
     * tela intermediária. Mantém o Intent.ACTION_CALL como fallback.
     */
    private fun placeCallReliable(context: Context, number: String) {
        val uri = Uri.fromParts("tel", number, null)
        val temPermissao = context.checkSelfPermission(Manifest.permission.CALL_PHONE) ==
            PackageManager.PERMISSION_GRANTED

        if (temPermissao) {
            try {
                val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                telecomManager.placeCall(uri, null)
                return
            } catch (e: SecurityException) {
                // cai para o Intent abaixo
            }
        }

        val intent = Intent(Intent.ACTION_CALL, uri)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }
}
