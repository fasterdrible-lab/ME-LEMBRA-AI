import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_medication_service.dart';
import 'package:me_lembra_ai/features/molly/services/molly_safety_service.dart';
import 'package:me_lembra_ai/features/molly/services/offline_intent_service.dart';
import 'package:me_lembra_ai/features/molly/tools/family_tool.dart';
import 'package:me_lembra_ai/models/family_member.dart';
import 'package:me_lembra_ai/models/reminder.dart';

/// TAREFAs 21 (medicamentos), 22 (prompt safety) e os cenários da TAREFA 29
/// (testes de segurança) do prompt mestre. 100% puro Dart.
void main() {
  group('TAREFA 29: cenarios literais do prompt mestre', () {
    test('"tomei dois comprimidos" -> orienta buscar ajuda, nunca tranquiliza', () {
      final i = MollySafetyService.classificar('Molly, tomei dois comprimidos.');
      expect(i, MollySafetyIntent.possivelExcessoDeRemedio);
      final fala = MollySafetyService.respostaSegura(i)!;
      expect(fala, contains('médico'));
      expect(fala, contains('192'));
    });

    test('"qual medicamento eu deveria tomar?" -> nunca indica remedio', () {
      final i = MollySafetyService.classificar('Molly, qual medicamento eu deveria tomar?');
      expect(i, MollySafetyIntent.conselhoMedico);
      expect(MollySafetyService.respostaSegura(i), contains('médico'));
    });

    test('"estou passando mal" continua sendo emergencia (prioridade sobre seguranca)', () {
      expect(
        OfflineIntentService.classificar('Molly, estou passando mal.'),
        OfflineIntent.possivelEmergencia,
      );
    });

    test('"exclua todos os meus lembretes" -> nunca exclui pela voz', () {
      expect(
        OfflineIntentService.classificar('Molly, exclua todos os meus lembretes.'),
        OfflineIntent.excluirLembretes,
      );
      for (final f in ['apaga o lembrete do dentista', 'deleta minha agenda', 'apaga tudo', 'cancela meus compromissos']) {
        expect(OfflineIntentService.classificar(f), OfflineIntent.excluirLembretes, reason: f);
      }
      for (final f in [
        'me lembra de limpar a casa todos os dias',
        'me lembra de cancelar a consulta amanhã',
        'apaga a luz',
        'quais são meus lembretes de hoje',
      ]) {
        expect(OfflineIntentService.classificar(f), isNot(OfflineIntent.excluirLembretes), reason: f);
      }
    });

    test('"liga para qualquer pessoa" -> pergunta quem, nunca escolhe ao acaso', () {
      const ana = FamilyMember(uid: '1', nome: 'Ana', perfil: 'Família', papel: 'cuidador');
      const pedro = FamilyMember(uid: '2', nome: 'Pedro', perfil: 'Família', papel: 'cuidador');
      expect(OfflineIntentService.classificar('Molly, liga para qualquer pessoa.'), OfflineIntent.ligarPara);
      for (final alvo in ['qualquer pessoa', 'alguém', 'qualquer um', 'todo mundo']) {
        final r = FamilyTool.resolverFamiliar([ana, pedro], alvo);
        expect(r.membro, isNull, reason: alvo);
        expect(r.falaProblema, contains('Para quem?'), reason: alvo);
        expect(r.falaProblema, contains('socorro'), reason: alvo);
      }
      // Mesmo com um familiar só: "qualquer pessoa" não vira ele.
      expect(FamilyTool.resolverFamiliar([ana], 'qualquer pessoa').membro, isNull);
    });

    test('IA dizendo que fez algo que nao pode fazer e bloqueada', () {
      for (final f in ['Pronto, excluí todos os seus lembretes.', 'Liguei para sua filha.', 'Já avisei sua família.', 'Acionei o SOS.']) {
        expect(MollySafetyService.filtrarFalaDaIA(f), MollySafetyService.falaAcaoInventada, reason: f);
      }
      expect(MollySafetyService.filtrarFalaDaIA('Você quer que eu avise sua filha?'), 'Você quer que eu avise sua filha?');
    });

    test('"ontem eu estava passando mal" nao dispara emergencia nem orientacao medica', () {
      expect(
        OfflineIntentService.classificar('Molly, ontem eu estava passando mal.'),
        isNot(OfflineIntent.possivelEmergencia),
      );
      expect(
        MollySafetyService.classificar('Molly, ontem eu estava passando mal.'),
        MollySafetyIntent.nenhuma,
      );
    });
  });

  group('MollySafetyService.classificar — conselho medico', () {
    test('dose, indicacao, troca, suspensao, combinacao e diagnostico', () {
      const frases = [
        'quantos comprimidos eu devo tomar',
        'que remédio é bom pra dor de cabeça',
        'posso tomar dipirona pra febre',
        'posso parar de tomar a losartana',
        'posso trocar o remédio da pressão',
        'devo aumentar a dose',
        'posso tomar o remédio com cerveja',
        'será que estou com dengue',
        'acho que estou doente',
        'que doença eu tenho',
        'isso é grave?',
        'qual remédio devo tomar agora pra dor de cabeça',
      ];
      for (final f in frases) {
        expect(MollySafetyService.classificar(f), MollySafetyIntent.conselhoMedico, reason: f);
      }
    });

    test('nao bloqueia pedidos normais (falsos positivos evitados)', () {
      const frases = [
        'Me lembra do remédio às oito.',
        'O que eu tenho hoje?',
        'confirmar remédio',
        'qual remédio eu devo tomar agora',
        'qual remédio eu tenho que tomar hoje',
        'posso trocar o horário do lembrete',
        'acho que estou com fome',
        'já tomei meu remédio hoje',
        'tomei meu remédio',
        'quem é meu contato de emergência',
      ];
      for (final f in frases) {
        expect(MollySafetyService.classificar(f), MollySafetyIntent.nenhuma, reason: f);
      }
    });
  });

  group('MollySafetyService.classificar — remedio a mais', () {
    test('variacoes de tomar remedio a mais ou errado', () {
      const frases = [
        'tomei duas pílulas',
        'tomei o remédio duas vezes',
        'acho que tomei remédio demais',
        'tomei o remédio errado',
        'tomei o dobro',
        'tomei o remédio do meu marido',
      ];
      for (final f in frases) {
        expect(MollySafetyService.classificar(f), MollySafetyIntent.possivelExcessoDeRemedio, reason: f);
      }
    });
  });

  group('MollySafetyService.filtrarFalaDaIA — camada de saida', () {
    test('bloqueia tranquilizar, dispensar medico, mudar dose e diagnosticar', () {
      const falas = [
        'Fique tranquilo, você está seguro.',
        'Não é nada grave.',
        'Você não precisa ir ao médico.',
        'A emergência já foi resolvida.',
        'Pode aumentar a dose hoje.',
        'Tome mais um comprimido.',
        'Você está com uma virose.',
        'Você vai ficar bem.',
      ];
      for (final f in falas) {
        expect(MollySafetyService.filtrarFalaDaIA(f), MollySafetyService.falaSaidaBloqueada, reason: f);
      }
    });

    test('deixa passar respostas normais', () {
      const falas = [
        'Você tem dois compromissos hoje. Um às dez e outro às três.',
        'Seu remédio Losartana 50 mg está marcado para as 8 horas.',
        'Você está bem? Quer que eu leia seus lembretes?',
        'Para qual dia?',
      ];
      for (final f in falas) {
        expect(MollySafetyService.filtrarFalaDaIA(f), f, reason: f);
      }
    });
  });

  group('TAREFA 21: MollyMedicationService', () {
    final agora = DateTime(2026, 10, 11, 14, 0);
    Reminder r(String type, DateTime dt, {bool confirmed = false}) => Reminder(
          id: 'x',
          userId: 'u',
          title: 'Remédio',
          type: type,
          description: '',
          dateTime: dt,
          repeat: 'unico',
          notification: '',
          confirmed: confirmed,
          perfil: 'Melhor Idade',
        );

    test('reconhece a pergunta "ja tomei meu remedio hoje?"', () {
      expect(MollyMedicationService.ehPerguntaRemediosDeHoje('já tomei meu remédio hoje'), isTrue);
      expect(MollyMedicationService.ehPerguntaRemediosDeHoje('falta tomar algum remédio'), isTrue);
      expect(MollyMedicationService.ehPerguntaRemediosDeHoje('histórico do remédio'), isTrue);
      expect(MollyMedicationService.ehPerguntaRemediosDeHoje('me lembra do remédio às oito'), isFalse);
      expect(MollyMedicationService.ehPerguntaRemediosDeHoje('tomei meu remédio'), isFalse);
    });

    test('sem remedio hoje', () {
      expect(
        MollyMedicationService.falaRemediosDeHoje([r('Consulta', agora)], agora),
        'Não encontrei nenhum remédio marcado para hoje.',
      );
    });

    test('todos tomados', () {
      final fala = MollyMedicationService.falaRemediosDeHoje(
        [r('Remedio', DateTime(2026, 10, 11, 8), confirmed: true)],
        agora,
      );
      expect(fala, 'Sim. Seu remédio das 8 horas já foi marcado como tomado.');
    });

    test('um tomado e um atrasado', () {
      final fala = MollyMedicationService.falaRemediosDeHoje([
        r('Remedio', DateTime(2026, 10, 11, 8), confirmed: true),
        r('Tomar', DateTime(2026, 10, 11, 12)),
      ], agora);
      expect(fala, 'Você já marcou 1 remédio como tomado hoje. O das 12 horas ainda não foi marcado como tomado.');
    });

    test('nenhum tomado, proximo no futuro; ignora remedio de outro dia', () {
      final fala = MollyMedicationService.falaRemediosDeHoje([
        r('Remedio', DateTime(2026, 10, 11, 20)),
        r('Remedio', DateTime(2026, 10, 10, 8)),
      ], agora);
      expect(fala, 'Você tem 1 remédio hoje, e nenhum foi marcado como tomado ainda. O próximo é às 20 horas.');
    });
  });
}
