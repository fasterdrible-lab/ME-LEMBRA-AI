import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/memory/short_term_memory.dart';

/// Testes puros da TAREFA 7 (memória de curto prazo) — sem Firebase, sem
/// plugins de plataforma: `ShortTermMemory` não depende de nada disso.
void main() {
  group('ShortTermMemory', () {
    test('conta turnos e reconhece o limite', () {
      final memoria = ShortTermMemory();
      expect(memoria.turnos, 0);
      expect(memoria.atingiuLimiteDeTurnos, isFalse);

      for (var i = 0; i < ShortTermMemory.maxTurnos; i++) {
        memoria.avancarTurno();
      }
      expect(memoria.turnos, ShortTermMemory.maxTurnos);
      expect(memoria.atingiuLimiteDeTurnos, isTrue);
    });

    test('guarda so a primeira fala da conversa, ignorando chamadas seguintes', () {
      final memoria = ShortTermMemory();
      memoria.registrarPrimeiraFalaSeNecessario('marcar consulta ginecologista');
      memoria.registrarPrimeiraFalaSeNecessario('outra frase qualquer');
      expect(memoria.primeiraFala, 'marcar consulta ginecologista');
    });

    test('nao registra primeira fala se ja estiver coletando um lembrete', () {
      final memoria = ShortTermMemory()..coletandoLembrete = true;
      memoria.registrarPrimeiraFalaSeNecessario('15h');
      expect(memoria.primeiraFala, isNull);
    });

    test('historico para IA respeita o limite de trocas, descartando as mais antigas', () {
      final memoria = ShortTermMemory();
      for (var i = 0; i < ShortTermMemory.maxTrocas + 2; i++) {
        memoria.registrarTroca('pergunta $i', 'resposta $i');
      }
      final historico = memoria.historicoParaIA;

      expect(historico.length, ShortTermMemory.maxTrocas);
      expect(historico.last.usuario, 'pergunta ${ShortTermMemory.maxTrocas + 1}');
      expect(historico.any((t) => t.usuario == 'pergunta 0'), isFalse);
    });

    test('mesclarSlots preenche dia e hora sem sobrescrever o que ja foi confirmado', () {
      final memoria = ShortTermMemory();
      memoria.mesclarSlots(data: (dia: 28, mes: 9, ano: 2026), hora: null);
      expect(memoria.temDia, isTrue);
      expect(memoria.temHora, isFalse);

      memoria.mesclarSlots(data: null, hora: (hora: 15, minuto: 0));
      expect(memoria.slotDia, 28);
      expect(memoria.temHora, isTrue);
      expect(memoria.slotHora, 15);
    });

    test('encerrar limpa historico, turnos, primeira fala e slots', () {
      final memoria = ShortTermMemory()
        ..avancarTurno()
        ..registrarPrimeiraFalaSeNecessario('oi')
        ..registrarTroca('pergunta', 'resposta')
        ..mesclarSlots(data: (dia: 1, mes: 1, ano: 2026), hora: (hora: 8, minuto: 0));

      memoria.encerrar();

      expect(memoria.turnos, 0);
      expect(memoria.primeiraFala, isNull);
      expect(memoria.historicoParaIA, isEmpty);
      expect(memoria.temDia, isFalse);
      expect(memoria.temHora, isFalse);
      expect(memoria.coletandoLembrete, isFalse);
    });
  });
}
