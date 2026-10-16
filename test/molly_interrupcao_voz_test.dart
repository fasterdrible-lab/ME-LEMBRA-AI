import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_interrupcao_voz.dart';
import 'package:me_lembra_ai/features/molly/services/molly_telemetria.dart';

/// MOLLY-44 — decisão de "a pessoa está falando por cima da Molly", com os
/// números medidos no A07 (MOLLY-43, docs/MOLLY_VOZ_LEVANTAMENTO.md §5).
void main() {
  const pedaco = Duration(milliseconds: 80); // ~o tamanho medido no aparelho

  /// Alimenta o detector e devolve em qual pedaço disparou (ou null).
  int? disparo(DetectorDeVoz d, List<double> niveis) {
    for (var i = 0; i < niveis.length; i++) {
      if (d.adicionar(niveis[i], pedaco)) return i;
    }
    return null;
  }

  // Passa da carência inicial (400 ms = 5 pedaços) em silêncio.
  final carencia = List<double>.filled(5, -90);

  test('eco da Molly (fase 2: mediana -90, p90 -58, picos -41) não dispara', () {
    final eco = [for (var i = 0; i < 120; i++) i % 10 == 0 ? -40.8 : (i.isEven ? -90.0 : -57.9)];
    expect(disparo(DetectorDeVoz(), [...carencia, ...eco]), isNull);
  });

  test('pico isolado acima do limiar não basta', () {
    expect(disparo(DetectorDeVoz(), [...carencia, -20, -90, -90, -20, -90, -90, -20, -90]), isNull);
  });

  test('voz sustentada (fase 4/5: -37 a -20) dispara em ~300 ms', () {
    final i = disparo(DetectorDeVoz(), [...carencia, -36.9, -30, -25, -20.7, -19.6, -22]);
    expect(i, isNotNull);
    expect(i! - carencia.length, 3); // 4 pedaços de 80 ms = 320 ms
  });

  test('uma pausa curta entre sílabas não zera a contagem', () {
    expect(disparo(DetectorDeVoz(), [...carencia, -30, -30, -55, -30, -30]), isNotNull);
  });

  test('duas quedas seguidas zeram a contagem', () {
    expect(disparo(DetectorDeVoz(), [...carencia, -30, -30, -60, -60, -30, -30]), isNull);
  });

  test('nada conta durante a carência inicial (cancelamento de eco se ajustando)', () {
    expect(disparo(DetectorDeVoz(), [-20, -20, -20, -20, -20]), isNull);
  });

  // Sessão 27: vídeo tocando ao lado — fala contínua em torno de −35 dBFS,
  // acima do −40 fixo. O cancelamento de eco não tira esse som.
  final video = [for (var i = 0; i < 120; i++) [-36.0, -33.0, -38.0, -30.0, -41.0][i % 5]];

  test('vídeo tocando ao lado (fundo ~−35) não dispara', () {
    final d = DetectorDeVoz();
    expect(disparo(d, video), isNull);
    expect(d.limiarAtual, greaterThan(-30));
  });

  test('pessoa falando alto por cima do vídeo ainda dispara', () {
    expect(disparo(DetectorDeVoz(), [...video.take(25), -20, -18, -22, -19, -21]), isNotNull);
  });

  test('sala quieta: limiar continua −40', () {
    final d = DetectorDeVoz();
    disparo(d, [...carencia, -90, -58, -90, -58]);
    expect(d.limiarAtual, -40);
  });

  test('quem fala por cima não sobe o próprio limiar', () {
    final d = DetectorDeVoz(duracaoMinima: const Duration(seconds: 2));
    disparo(d, [...carencia, for (var i = 0; i < 20; i++) -25.0]);
    expect(d.limiarAtual, -40);
  });

  test('nivelDb: silêncio, metade e máximo', () {
    Uint8List pcm(int valor, [int amostras = 160]) {
      final b = ByteData(amostras * 2);
      for (var i = 0; i < amostras; i++) {
        b.setInt16(i * 2, valor, Endian.little);
      }
      return b.buffer.asUint8List();
    }

    expect(DetectorDeVoz.nivelDb(Uint8List(0)), isNull);
    expect(DetectorDeVoz.nivelDb(pcm(0)), -90);
    expect(DetectorDeVoz.nivelDb(pcm(16384))!, closeTo(-6.0, 0.1));
    expect(DetectorDeVoz.nivelDb(pcm(32767))!, closeTo(0.0, 0.1));
  });

  test('duracaoDoPedaco: 16 kHz, 16 bits mono', () {
    expect(DetectorDeVoz.duracaoDoPedaco(2560), const Duration(milliseconds: 80));
  });

  test('telemetria da interrupção só aceita voz/toque', () {
    expect(MollyTelemetria.limparParametros({'modo': 'voz'}), {'modo': 'voz'});
    expect(MollyTelemetria.limparParametros({'modo': 'toque'}), {'modo': 'toque'});
    expect(MollyTelemetria.limparParametros({'modo': 'para de falar'}), isEmpty);
  });
}
