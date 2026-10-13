import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../../services/voice_service.dart';

/// EXPERIMENTO (branch feature/molly-interromper-voz) — não vai para a
/// versão do usuário. Mede, no aparelho, se dá para a Molly ouvir a pessoa
/// ENQUANTO fala (interromper pela voz — TAREFA 33, ver
/// `docs/MOLLY_VOZ_LEVANTAMENTO.md` §3b).
///
/// Grava o volume do microfone (dBFS, por pedaço de áudio) em cinco fases e
/// escreve no log com o prefixo `ECO_TESTE`:
/// 1. silêncio (ruído do ambiente), com cancelamento de eco;
/// 2. a Molly falando sozinha, com cancelamento de eco — quanto da voz dela
///    "vaza" no microfone;
/// 3. a Molly falando sozinha, SEM cancelamento — referência;
/// 4. a pessoa falando sozinha, com cancelamento;
/// 5. a Molly e a pessoa falando juntas, com cancelamento.
/// Dá certo se (2) ficar perto de (1) e bem abaixo de (4)/(5).
/// Rota `/molly-eco-teste`, aberta por adb (`--es route /molly-eco-teste`).
class MollyEcoTesteScreen extends StatefulWidget {
  const MollyEcoTesteScreen({super.key});

  @override
  State<MollyEcoTesteScreen> createState() => _MollyEcoTesteScreenState();
}

class _MollyEcoTesteScreenState extends State<MollyEcoTesteScreen> {
  String _instrucao = 'Preparando...';
  final List<String> _resultados = [];

  static const _fraseLonga =
      'Este é um teste do eco da Molly. Estou falando uma frase bem comprida para medir '
      'quanto da minha própria voz o microfone escuta enquanto eu falo. '
      'Continue em silêncio até eu pedir, por favor. Obrigada pela paciência.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rodar());
  }

  void _instruir(String texto) {
    debugPrint('ECO_TESTE instrucao: $texto');
    if (mounted) setState(() => _instrucao = texto);
  }

  Future<void> _rodar() async {
    final permitido = await AudioRecorder().hasPermission();
    if (!permitido) {
      _instruir('Sem permissão de microfone.');
      return;
    }
    _instruir('Fique em SILÊNCIO.');
    await Future<void>.delayed(const Duration(seconds: 3));
    await _medir('1_silencio_aec', const Duration(seconds: 4), aec: true);

    _instruir('SILÊNCIO — a Molly vai falar.');
    await _medir('2_molly_aec', const Duration(seconds: 9), aec: true, falar: true);
    await Future<void>.delayed(const Duration(seconds: 2));

    _instruir('SILÊNCIO — a Molly vai falar de novo.');
    await _medir('3_molly_sem_aec', const Duration(seconds: 9), aec: false, falar: true);
    await Future<void>.delayed(const Duration(seconds: 2));

    _instruir('Agora FALE você: conte devagar de 1 até 15.');
    await VoiceService.speak('Agora fale você. Conte devagar de um até quinze.');
    await _medir('4_voce_aec', const Duration(seconds: 7), aec: true);
    await Future<void>.delayed(const Duration(seconds: 2));

    _instruir('Agora FALE JUNTO com a Molly: conte de 1 até 20 enquanto ela fala.');
    await VoiceService.speak('Agora fale junto comigo. Conte de um até vinte enquanto eu falo. Começando.');
    await _medir('5_molly_e_voce_aec', const Duration(seconds: 9), aec: true, falar: true);

    _instruir('Pronto! Teste terminado.');
    debugPrint('ECO_TESTE fim');
  }

  /// Grava [duracao] e registra mediana, p90 e máximo do volume (dBFS).
  Future<void> _medir(String fase, Duration duracao, {required bool aec, bool falar = false}) async {
    final gravador = AudioRecorder();
    final niveis = <double>[];
    final fluxo = await gravador.startStream(RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      echoCancel: aec,
      noiseSuppress: aec,
      // A fala da Molly toma o foco de áudio: sem isto a gravação pausa.
      audioInterruption: AudioInterruptionMode.none,
      androidConfig: AndroidRecordConfig(
        audioSource: aec ? AndroidAudioSource.voiceCommunication : AndroidAudioSource.mic,
      ),
    ));
    final assinatura = fluxo.listen((bytes) {
      final nivel = _dbfs(bytes);
      if (nivel != null) niveis.add(nivel);
    });
    if (falar) unawaited(VoiceService.speak(_fraseLonga));
    await Future<void>.delayed(duracao);
    if (falar) await VoiceService.stop();
    await gravador.stop();
    await assinatura.cancel();
    await gravador.dispose();

    if (niveis.isEmpty) {
      debugPrint('ECO_TESTE $fase sem_amostras');
      return;
    }
    niveis.sort();
    double pct(double p) => niveis[((niveis.length - 1) * p).round()];
    final linha = '$fase aec=$aec n=${niveis.length} '
        'mediana=${pct(0.5).toStringAsFixed(1)} p90=${pct(0.9).toStringAsFixed(1)} '
        'max=${niveis.last.toStringAsFixed(1)} dBFS';
    debugPrint('ECO_TESTE $linha');
    if (mounted) setState(() => _resultados.add(linha));
  }

  /// Volume do pedaço de áudio PCM 16 bits (dBFS: 0 = máximo, -90 = silêncio).
  static double? _dbfs(Uint8List bytes) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teste de eco (experimento)')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_instrucao, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            for (final r in _resultados) Text(r, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
