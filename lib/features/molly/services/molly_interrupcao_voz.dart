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
///
/// Barulho de fundo (teste no aparelho, sessão 27: vídeo tocando ao lado):
/// o cancelamento de eco só tira a voz da própria Molly, e o som do vídeo
/// passava do −40 — ela se cortava sozinha e ficava ouvindo o vídeo. Por isso
/// o limiar sobe para [margemSobreFundoDb] acima do fundo (mediana dos
/// últimos [janelaDoFundo] pedaços que não eram voz). Em sala quieta o fundo
/// fica perto de −60/−90 e o limiar continua −40.
class DetectorDeVoz {
  DetectorDeVoz({
    this.limiarDb = -40,
    this.duracaoMinima = const Duration(milliseconds: 300),
    this.carenciaInicial = const Duration(milliseconds: 400),
    this.quedasToleradas = 1,
    this.margemSobreFundoDb = 10,
    this.janelaDoFundo = 25,
  });

  final double limiarDb;
  final Duration duracaoMinima;

  /// O cancelamento de eco leva um instante para se ajustar quando a Molly
  /// começa a falar — nada conta nesse começo (mas já mede o fundo).
  final Duration carenciaInicial;
  final int quedasToleradas;
  final double margemSobreFundoDb;

  /// Em pedaços (~80 ms cada no A07): 25 ≈ 2 s.
  final int janelaDoFundo;

  Duration _decorrido = Duration.zero;
  Duration _acimaDoLimiar = Duration.zero;
  int _quedasSeguidas = 0;
  final List<double> _fundo = [];

  /// Limiar em uso agora: [limiarDb], ou mais alto se o fundo for barulhento.
  double get limiarAtual {
    if (_fundo.isEmpty) return limiarDb;
    final ordenados = [..._fundo]..sort();
    return math.max(limiarDb, ordenados[ordenados.length ~/ 2] + margemSobreFundoDb);
  }

  void _medirFundo(double nivelDb) {
    _fundo.add(nivelDb);
    if (_fundo.length > janelaDoFundo) _fundo.removeAt(0);
  }

  /// Acrescenta um pedaço de [duracao] com volume [nivelDb]. Devolve `true`
  /// no pedaço em que a voz fica sustentada o bastante.
  bool adicionar(double nivelDb, Duration duracao) {
    _decorrido += duracao;
    if (_decorrido <= carenciaInicial) {
      _medirFundo(nivelDb);
      return false;
    }
    final limiar = limiarAtual;
    // Só o que não parece voz entra no fundo — senão quem fala por cima
    // subiria o próprio limiar.
    if (nivelDb < limiar) _medirFundo(nivelDb);
    if (nivelDb >= limiar) {
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
      _niveis.clear();
      _assinatura = fluxo.listen((bytes) {
        if (geracao != _geracao) return;
        final nivel = DetectorDeVoz.nivelDb(bytes);
        if (nivel == null) return;
        _niveis.add(nivel);
        final detectou = detector.adicionar(nivel, DetectorDeVoz.duracaoDoPedaco(bytes.length));
        _limiar = detector.limiarAtual;
        if (detectou) {
          _geracao++; // avisa uma vez só
          _disparou = true;
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

  // Calibração no aparelho (sessão 27): só números de volume, nunca áudio
  // nem texto — `adb logcat | Select-String MOLLY_VIGIA`.
  final List<double> _niveis = [];
  bool _disparou = false;
  double _limiar = -40;

  void _registrarNiveis() {
    if (_niveis.isEmpty) return;
    final ordenados = [..._niveis]..sort();
    String pct(double p) => ordenados[((ordenados.length - 1) * p).round()].toStringAsFixed(1);
    final ultimos = _niveis.length > 8 ? _niveis.sublist(_niveis.length - 8) : _niveis;
    debugPrint('MOLLY_VIGIA disparou=$_disparou n=${_niveis.length} limiar=${_limiar.toStringAsFixed(1)} '
        'mediana=${pct(0.5)} p90=${pct(0.9)} max=${pct(1)} '
        'ultimos=${ultimos.map((n) => n.toStringAsFixed(0)).join(',')}');
    _niveis.clear();
    _disparou = false;
  }

  Future<void> _fechar() async {
    _registrarNiveis();
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
