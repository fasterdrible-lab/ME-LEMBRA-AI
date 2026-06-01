import 'package:flutter/services.dart';
import 'settings_service.dart';

/// Controla o Foreground Service nativo "Modo proteção ativo".
///
/// Quando ativo, exibe notificação persistente que impede o Android de
/// encerrar o processo Flutter, mantendo o SosListenerService e o FCM ativos
/// mesmo com o app em segundo plano ou fechado pelo usuário.
class SosProtectionService {
  static const _channel = MethodChannel('com.melembra.ai/protection');

  static Future<void> start() async {
    try {
      await _channel.invokeMethod('start');
      await SettingsService.setModoProtecao(true);
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
      await SettingsService.setModoProtecao(false);
    } catch (_) {}
  }

  /// Restaura o estado persistido após reinício do app.
  static Future<void> restoreIfEnabled() async {
    final enabled = await SettingsService.getModoProtecao();
    if (enabled) await start();
  }
}
