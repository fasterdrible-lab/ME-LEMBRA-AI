import 'dart:async';

import 'package:flutter/services.dart';

import 'settings_service.dart';
import 'sos_service.dart';

/// Escuta a sequência de 5 pressionamentos de volume (em até 3 segundos)
/// e dispara o SOS quando detectada.
///
/// A captura ocorre via [onKeyDown] na MainActivity (foreground do app).
/// Para captura com tela bloqueada, o Accessibility Service seria necessário
/// — isso requer consentimento explícito do usuário e não está habilitado aqui.
class VolumeSosService {
  static const _controlChannel = MethodChannel('com.melembra.ai/volume_sos_control');
  static const _eventChannel = EventChannel('com.melembra.ai/volume_sos_events');

  static StreamSubscription? _sub;

  static Future<void> start() async {
    _sub?.cancel();
    try {
      await _controlChannel.invokeMethod('enable');
    } catch (_) {}
    _sub = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event == 'sos') {
        SosService.trigger(motivo: 'volume');
      }
    });
    await SettingsService.setVolumeSos(true);
  }

  static Future<void> stop() async {
    _sub?.cancel();
    _sub = null;
    try {
      await _controlChannel.invokeMethod('disable');
    } catch (_) {}
    await SettingsService.setVolumeSos(false);
  }

  /// Restaura o estado persistido após reinício do app.
  static Future<void> restoreIfEnabled() async {
    final enabled = await SettingsService.getVolumeSos();
    if (enabled) await start();
  }
}
