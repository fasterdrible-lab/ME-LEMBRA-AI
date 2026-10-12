import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_cache_service.dart';

/// TAREFA 26 — mecanismo do cache (rede com prazo → cópia do aparelho),
/// 100% puro: as funções de rede/local são simuladas, sem Firebase.
void main() {
  const prazoCurto = Duration(milliseconds: 50);
  late DateTime agora;

  setUp(() {
    MollyCache.reiniciar();
    agora = DateTime(2026, 10, 12, 9);
    MollyCache.relogio = () => agora;
  });

  Future<String> lento() => Completer<String>().future; // nunca termina

  test('rede respondeu a tempo: usa a rede e não toca no aparelho', () async {
    var usouLocal = false;
    final v = await MollyCache.lerComReserva<String>(
      rede: () async => 'rede',
      local: () async {
        usouLocal = true;
        return 'local';
      },
      vazio: '',
      prazo: prazoCurto,
    );
    expect(v, 'rede');
    expect(usouLocal, isFalse);
    expect(MollyCache.semRede, isFalse);
  });

  test('rede travada: cai na cópia do aparelho e marca sem rede', () async {
    final v = await MollyCache.lerComReserva<String>(
      rede: lento,
      local: () async => 'local',
      vazio: '',
      prazo: prazoCurto,
    );
    expect(v, 'local');
    expect(MollyCache.semRede, isTrue);
  });

  test('sem rede marcado: próximas leituras nem tentam a rede', () async {
    await MollyCache.lerComReserva<String>(rede: lento, local: () async => 'x', vazio: '', prazo: prazoCurto);
    var tentouRede = false;
    final v = await MollyCache.lerComReserva<String>(
      rede: () async {
        tentouRede = true;
        return 'rede';
      },
      local: () async => 'local',
      vazio: '',
    );
    expect(v, 'local');
    expect(tentouRede, isFalse);
  });

  test('depois da pausa, volta a tentar a rede', () async {
    await MollyCache.lerComReserva<String>(rede: lento, local: () async => 'x', vazio: '', prazo: prazoCurto);
    agora = agora.add(MollyCache.pausaSemRede + const Duration(seconds: 1));
    final v = await MollyCache.lerComReserva<String>(
      rede: () async => 'rede',
      local: () async => 'local',
      vazio: '',
    );
    expect(v, 'rede');
    expect(MollyCache.semRede, isFalse);
  });

  test('erro na rede (não demora): usa o aparelho sem marcar sem rede', () async {
    final v = await MollyCache.lerComReserva<String>(
      rede: () async => throw Exception('permissão'),
      local: () async => 'local',
      vazio: '',
    );
    expect(v, 'local');
    expect(MollyCache.semRede, isFalse);
  });

  test('rede e aparelho falham: devolve vazio, sem exceção', () async {
    final v = await MollyCache.lerComReserva<List<int>>(
      rede: () async => throw Exception('rede'),
      local: () async => throw Exception('sem cópia'),
      vazio: const [],
    );
    expect(v, isEmpty);
  });

  test('escrita confirmada a tempo: true', () async {
    expect(await MollyCache.escrever(() async {}, prazo: prazoCurto), isTrue);
  });

  test('escrita sem confirmação (sem internet): false, não trava e marca sem rede', () async {
    final enviado = await MollyCache.escrever(() => Completer<void>().future, prazo: prazoCurto);
    expect(enviado, isFalse);
    expect(MollyCache.semRede, isTrue);
  });

  test('escrita com erro de verdade: repassa a exceção', () async {
    expect(
      () => MollyCache.escrever(() async => throw StateError('negado'), prazo: prazoCurto),
      throwsStateError,
    );
  });
}
