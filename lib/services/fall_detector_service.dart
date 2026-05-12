import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

import 'sos_service.dart';
import 'voice_service.dart';

/// Detecta uma possível queda usando o acelerômetro.
///
/// Algoritmo simples:
/// 1. Pico de aceleração total acima de [_impactThreshold] (m/s²) — impacto.
/// 2. Após o impacto, observa janela curta de "imobilidade" (variação baixa).
/// 3. Se ambos ocorrem, dispara o SOS automaticamente.
class FallDetectorService {
  static const double _impactThreshold = 25.0; // ~2.5g
  static const double _stillnessThreshold = 1.5;
  static const Duration _stillnessWindow = Duration(seconds: 2);

  static StreamSubscription<UserAccelerometerEvent>? _sub;
  static DateTime? _lastImpactAt;
  static bool _running = false;

  /// Inicia o monitoramento. Idempotente.
  static void start() {
    if (_running) return;
    _running = true;
    _sub = userAccelerometerEventStream().listen(_onSample);
  }

  /// Para o monitoramento.
  static Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    _lastImpactAt = null;
  }

  static void _onSample(UserAccelerometerEvent e) {
    final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);

    if (_lastImpactAt == null) {
      if (magnitude >= _impactThreshold) {
        _lastImpactAt = DateTime.now();
      }
      return;
    }

    final dt = DateTime.now().difference(_lastImpactAt!);
    if (dt > _stillnessWindow) {
      // Janela passou sem confirmar → reset.
      _lastImpactAt = null;
      return;
    }

    // Dentro da janela: se a magnitude está próxima da gravidade (parado),
    // consideramos uma queda confirmada.
    if (magnitude < _stillnessThreshold) {
      _lastImpactAt = null;
      _onFallDetected();
    }
  }

  static Future<void> _onFallDetected() async {
    await VoiceService.speak('Possível queda detectada. Acionando emergência.');
    await SosService.trigger(motivo: 'queda_detectada');
  }
}
