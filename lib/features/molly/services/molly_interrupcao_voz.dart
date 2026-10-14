import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Decide, pedaço a pedaço de áudio, se a pessoa começou a falar por cima da
/// Molly (MOLLY-44, TAREFA 33). Puro, sem microfone — testável.
///
/// Números da medição no Galaxy A07 (MOLLY-43, `docs/MOLLY_VOZ_LEVANTAMENTO.md`
/// §5), com cancelamento de eco: a Molly sozinha fica em p90 −57,9 dBFS, mas
/// com picos de −40,8 (iguais aos do silêncio); a pessoa falando, mediana
/// −36,9 e p90 −20,7. Por isso o limiar fica em −40 e um pico isolado nunca
/// basta: precisa de [duracaoMinima] de som acima dele, tolerando só uma
/// pausa curta entre sílabas ([quedasToleradas] pedaços seguidos abaixo).
class DetectorDeVoz {
  DetectorDeVoz({
    this.limiarDb = -40,
    this.duracaoMinima = const Duration(milliseconds: 300),
    this.carenciaInicial = const Duration(milliseconds: 400),
    this.quedasToleradas = 1,
  });

  final double limiarDb;
  final Duration duracaoMinima;

  /// O cancelamento de eco leva um instante para se ajustar quando a Molly
  /// começa a falar — nada conta nesse começo.
  final Duration carenciaInicial;
  final int quedasToleradas;

  Duration _decorrido = Duration.zero;
  Duration _acimaDoLimiar = Duration.zero;
  int _quedasSeguidas = 0;

  /// Acrescenta um pedaço de [duracao] com volume [nivelDb]. Devolve `true`
  /// no pedaço em que a voz fica sustentada o bastante.
  bool adicionar(double nivelDb, Duration duracao) {
    _decorrido += duracao;
    if (_decorrido <= carenciaInicial) return false;
    if (nivelDb >= limiarDb) {
      _acimaDoLimiar += duracao;
      _quedasSeguidas = 0;
    } else if (++_quedasSeguidas > quedasToleradas) {
      _acimaDoLimiar = Duration.zero;
    }
    return _acimaDoLimiar >= duracaoMinima;
  }

  /// Volume de um pedaço PCM 16 bits little-endian, em dBFS (0 = máximo,
  /// −90 = silêncio). Mesma conta da tela de medição.
  static double? nivelDb(Uint8List bytes) {
    final amostras = bytes.length ~/ 2;
    if (amostras == 0) return null;
    final dados = ByteData.sublistView(bytes);
    var soma = 0.0;
    for (var i = 0; i < amostras; i++) {
      final v = dados.getInt16(i * 2, Endian.little).toDouble();
      soma += v * v;
    }
    final rms = math.sqrt(soma / amostras);
    if (rms <= 0) return -90;
    return 20 * math.log(rms / 32768) / math.ln10;
  }

  /// Duração de um pedaço PCM 16 bits mono na [taxa] dada.
  static Duration duracaoDoPedaco(int bytes, {int taxa = VigiaDeInterrupcao.taxa}) =>
      Duration(microseconds: (bytes ~/ 2) * 1000000 ~/ taxa);
}

/// Escuta o microfone ENQUANTO a Molly fala e avisa uma vez quando a pessoa
/// fala por cima. Mesma configuração medida na MOLLY-43: fonte
/// `voiceCommunication` com cancelamento de eco e supressão de ruído (tira a
/// voz da própria Molly) e `audioInterruption: none` (a fala da Molly toma o
/// foco de áudio; o padrão pausaria a gravação).
///
/// Não usa o `speech_to_text` para detectar: o reconhecedor do sistema não
/// garante o cancelamento de eco. Quando detecta, o gravador é fechado ANTES
/// do aviso — quem recebe pode abrir o reconhecimento de voz em seguida sem
/// disputar o microfone.
class VigiaDeInterrupcao {
  static const taxa = 16000;

  AudioRecorder? _gravador;
  StreamSubscription<Uint8List>? _assinatura;

  /// Cada [iniciar]/[parar] troca a geração: uma abertura do microfone que
  /// termine depois de um [parar] vê que ficou velha e fecha sozinha.
  int _geracao = 0;
  Future<void>? _iniciando;

  /// Começa a vigiar. Não espera o microfone abrir — quem fala não atrasa.
  void iniciar({required void Function() aoDetectarVoz}) {
    final geracao = ++_geracao;
    _iniciando = _abrir(geracao, aoDetectarVoz);
  }

  Future<void> _abrir(int geracao, void Function() aoDetectarVoz) async {
    await _fechar();
    if (geracao != _geracao) return;
    final gravador = AudioRecorder();
    try {
      // Só confere: o microfone já foi autorizado para a Molly ouvir. Sem
      // permissão, segue sem interrupção por voz (o toque continua valendo).
      if (!await gravador.hasPermission(request: false) || geracao != _geracao) {
        await gravador.dispose();
        return;
      }
      final fluxo = await gravador.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: taxa,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        audioInterruption: AudioInterruptionMode.none,
        androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceCommunication),
      ));
      _gravador = gravador;
      if (geracao != _geracao) {
        await _fechar();
        return;
      }
      final detector = DetectorDeVoz();
      _assinatura = fluxo.listen((bytes) {
        if (geracao != _geracao) return;
        final nivel = DetectorDeVoz.nivelDb(bytes);
        if (nivel == null) return;
        if (detector.adicionar(nivel, DetectorDeVoz.duracaoDoPedaco(bytes.length))) {
          _geracao++; // avisa uma vez só
          unawaited(_fechar().then((_) => aoDetectarVoz()));
        }
      });
    } catch (e) {
      debugPrint('VigiaDeInterrupcao: não consegui ouvir durante a fala ($e)');
      if (_gravador == gravador) {
        await _fechar();
      } else {
        try {
          await gravador.dispose();
        } catch (_) {}
      }
    }
  }

  /// Para de vigiar e só volta quando o microfone estiver fechado — o
  /// reconhecimento de voz pode abrir logo em seguida. Pode ser chamado
  /// várias vezes.
  Future<void> parar() async {
    _geracao++;
    final iniciando = _iniciando;
    if (iniciando != null) await iniciando;
    await _fechar();
  }

  Future<void> _fechar() async {
    final assinatura = _assinatura;
    final gravador = _gravador;
    _assinatura = null;
    _gravador = null;
    try {
      await assinatura?.cancel();
      await gravador?.stop();
      await gravador?.dispose();
    } catch (_) {}
  }
}
