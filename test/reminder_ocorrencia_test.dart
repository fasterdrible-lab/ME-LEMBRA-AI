import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_medication_service.dart';
import 'package:me_lembra_ai/features/molly/services/molly_proactive_service.dart';
import 'package:me_lembra_ai/models/reminder.dart';

/// Sessão 26 (pré-requisito da TAREFA 21): lembrete diário/semanal e
/// confirmação por dia. Antes, um remédio "todo dia às 8h" criado em outro
/// dia sumia da Molly, e confirmado uma vez ficava "tomado" para sempre.
void main() {
  // Segunda, 12/10/2026, 10h.
  final agora = DateTime(2026, 10, 12, 10);

  Reminder remedio({
    required DateTime inicio,
    String repeat = 'unico',
    bool confirmed = false,
    List<String> confirmedDates = const [],
  }) =>
      Reminder(
        id: 'r1',
        userId: 'u',
        title: 'Losartana',
        type: 'Remedio',
        description: '',
        dateTime: inicio,
        repeat: repeat,
        notification: '',
        perfil: 'Melhor Idade',
        confirmed: confirmed,
        confirmedDates: confirmedDates,
      );

  group('Reminder.ocorreEm / horarioEm', () {
    test('único: só no próprio dia', () {
      final r = remedio(inicio: DateTime(2026, 10, 12, 8));
      expect(r.ocorreEm(agora), isTrue);
      expect(r.ocorreEm(DateTime(2026, 10, 13)), isFalse);
    });

    test('diário: do primeiro dia em diante, nunca antes', () {
      final r = remedio(inicio: DateTime(2026, 10, 1, 8), repeat: 'diario');
      expect(r.ocorreEm(agora), isTrue);
      expect(r.ocorreEm(DateTime(2026, 9, 30)), isFalse);
      expect(r.horarioEm(agora), DateTime(2026, 10, 12, 8));
    });

    test('semanal: só no mesmo dia da semana', () {
      final r = remedio(inicio: DateTime(2026, 10, 5, 8), repeat: 'semanal'); // segunda
      expect(r.ocorreEm(agora), isTrue);
      expect(r.ocorreEm(DateTime(2026, 10, 13)), isFalse);
    });
  });

  group('Reminder.confirmadoEm', () {
    test('diário confirmado ontem não está confirmado hoje (o confirmed antigo não vale)', () {
      final r = remedio(
        inicio: DateTime(2026, 10, 1, 8),
        repeat: 'diario',
        confirmed: true,
        confirmedDates: const ['2026-10-11'],
      );
      expect(r.confirmadoEm(agora), isFalse);
      expect(r.confirmadoEm(DateTime(2026, 10, 11)), isTrue);
    });

    test('único confirmado antes de confirmedDates existir continua confirmado', () {
      expect(remedio(inicio: DateTime(2026, 10, 12, 8), confirmed: true).confirmadoEm(agora), isTrue);
    });

    test('chaveDia no formato que o servidor também usa', () {
      expect(Reminder.chaveDia(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    });
  });

  group('a Molly enxerga o remédio diário criado em outro dia', () {
    final diario = remedio(inicio: DateTime(2026, 10, 1, 8), repeat: 'diario', confirmed: true,
        confirmedDates: const ['2026-10-11']);

    test('aviso de remédio atrasado', () {
      final aviso = MollyProactiveService.gerarAviso([diario], agora: agora);
      expect(aviso, isNotNull);
      expect(aviso!.pergunta, contains('Losartana'));
    });

    test('"já tomei meu remédio hoje?"', () {
      final fala = MollyMedicationService.falaRemediosDeHoje([diario], agora);
      expect(fala, contains('nenhum foi marcado como tomado'));
    });

    test('confirmado hoje: sem aviso, e "sim, já foi marcado"', () {
      final hoje = diario.copyWith(confirmedDates: const ['2026-10-11', '2026-10-12']);
      expect(MollyProactiveService.gerarAviso([hoje], agora: agora), isNull);
      expect(MollyMedicationService.falaRemediosDeHoje([hoje], agora), startsWith('Sim.'));
    });
  });
}
