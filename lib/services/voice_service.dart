import 'dart:async';
import 'dart:collection';

import 'package:flutter_tts/flutter_tts.dart';

/// Serviço de Text-to-Speech com fila, controle de estado e callbacks.
class VoiceService {
  // Instância padrão — voz normal para leitura de lembretes
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  static bool _isSpeaking = false;
  static final Queue<String> _queue = Queue<String>();

  // Instância dedicada para alertas — pitch e velocidade fixos, nunca partilhados
  static final FlutterTts _alertTts = FlutterTts();
  static bool _alertInitialized = false;

  static Future<void> _ensureInit() async {
    if (_initialized) return;
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.48);  // levemente mais natural que 0.45
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _processNext();
    });
    _tts.setErrorHandler((_) {
      _isSpeaking = false;
      _processNext();
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _initialized = true;
  }

  static Future<void> _ensureAlertInit() async {
    if (_alertInitialized) return;
    // Tenta usar Google TTS (melhor qualidade de voz)
    await _alertTts.setEngine('com.google.android.tts').catchError((_) {});
    await _alertTts.setLanguage('pt-BR');
    await _alertTts.setSpeechRate(0.50);  // ritmo de conversa natural
    await _alertTts.setVolume(1.0);
    await _alertTts.setPitch(1.08);      // leve entonação sem soar robótico
    await _alertTts.awaitSpeakCompletion(true);
    _alertInitialized = true;
  }

  /// Fala imediatamente, interrompendo qualquer fala/fila atual.
  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    _queue.clear();
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Enfileira um texto para ser falado após o atual.
  static Future<void> enqueue(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    _queue.add(text);
    if (!_isSpeaking) {
      await _processNext();
    }
  }

  /// Fala vários textos em sequência.
  static Future<void> speakAll(Iterable<String> textos) async {
    for (final t in textos) {
      await enqueue(t);
    }
  }

  static Future<void> _processNext() async {
    if (_queue.isEmpty || _isSpeaking) return;
    final next = _queue.removeFirst();
    await _tts.speak(next);
  }

  /// Fala com entonação de alerta usando instância dedicada (pitch 1.45).
  /// Não afeta a instância normal — sem race condition.
  static Future<void> speakAlert(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureAlertInit();
    await _alertTts.stop();
    await _alertTts.speak(text);
  }

  /// Para a fala em andamento e limpa a fila.
  static Future<void> stop() async {
    await _ensureInit();
    _queue.clear();
    await _tts.stop();
    _isSpeaking = false;
  }

  /// Pausa a fala atual (quando suportado pela plataforma).
  static Future<void> pause() async {
    await _ensureInit();
    await _tts.pause();
  }

  /// Indica se há fala em andamento.
  static bool get isSpeaking => _isSpeaking;
}
