import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_proactive_service.dart';
import 'package:me_lembra_ai/models/reminder.dart';
import 'package:me_lembra_ai/services/notification_service.dart';

/// Proatividade da MOLLY (TAREFA 23 do prompt mestre): remédio atrasado há
/// 15 min → "Você conseguiu tomar seu remédio?" → se não, "Quer que eu
/// lembre novamente?". Só as partes puras — [MollyProactiveService.gerarAviso]
/// e [MollyProactiveService.classificarResposta] nunca tocam
/// `FirebaseAuth`/Firestore/plugins (achado da Tarefa 10: sem mock completo).
void main() {
  final agora = DateTime(2026, 8, 28, 10, 0);

  Reminder remedio({
    required DateTime dateTime,
    bool confirmed = false,
    String title = 'Losartana',
    String type = 'Remedio',
  }) =>
      Reminder(
        id: 'x',
        userId: 'u',
        title: title,
        type: type,
        description: '',
        dateTime: dateTime,
        repeat: 'unico',
        notification: '',
        confirmed: confirmed,
        perfil: 'Melhor Idade',
      );

  group('MollyProactiveService.gerarAviso', () {
    test('15 min de atraso: pergunta se conseguiu tomar (frase da TAREFA 23)', () {
      final lista = [remedio(dateTime: DateTime(2026, 8, 28, 9, 45))];
      final aviso = MollyProactiveService.gerarAviso(lista, agora: agora)!;
      expect(aviso.pergunta, 'Você conseguiu tomar Losartana, das 9 horas e 45 minutos?');
      expect(aviso.lembrete.title, 'Losartana');
    });

    test('não pergunta com menos de 15 min de atraso', () {
      final lista = [remedio(dateTime: DateTime(2026, 8, 28, 9, 50))];
      expect(MollyProactiveService.gerarAviso(lista, agora: agora), isNull);
    });

    test('não pergunta quando o remédio já foi confirmado', () {
      final lista = [remedio(dateTime: DateTime(2026, 8, 28, 8, 0), confirmed: true)];
      expect(MollyProactiveService.gerarAviso(lista, agora: agora), isNull);
    });

    test('não pergunta pra lembrete de outro tipo (ex.: Consulta)', () {
      final lista = [remedio(dateTime: DateTime(2026, 8, 28, 8, 0), type: 'Consulta')];
      expect(MollyProactiveService.gerarAviso(lista, agora: agora), isNull);
    });

    test('não pergunta pra remédio de outro dia (ontem)', () {
      final lista = [remedio(dateTime: DateTime(2026, 8, 27, 8, 0))];
      expect(MollyProactiveService.gerarAviso(lista, agora: agora), isNull);
    });

    test('reconhece o tipo "Tomar" também', () {
      final lista = [remedio(dateTime: DateTime(2026, 8, 28, 8, 0), type: 'Tomar', title: 'Água')];
      expect(MollyProactiveService.gerarAviso(lista, agora: agora), isNotNull);
    });

    test('com mais de um atrasado, cita a quantidade e pergunta do mais antigo', () {
      final lista = [
        remedio(dateTime: DateTime(2026, 8, 28, 9, 0), title: 'Vitamina D'),
        remedio(dateTime: DateTime(2026, 8, 28, 8, 0), title: 'Losartana'),
      ];
      final aviso = MollyProactiveService.gerarAviso(lista, agora: agora)!;
      expect(aviso.pergunta, contains('2 remédios'));
      expect(aviso.pergunta, contains('Losartana'));
      expect(aviso.pergunta, isNot(contains('Vitamina D')));
      expect(aviso.lembrete.title, 'Losartana');
    });

    test('lista vazia não gera aviso', () {
      expect(MollyProactiveService.gerarAviso(const [], agora: agora), isNull);
    });
  });

  group('MollyProactiveService.classificarResposta', () {
    test('sim', () {
      for (final f in ['sim', 'tomei', 'já tomei', 'tomei sim', 'Sim, tomei agora', 'pode lembrar', 'quero']) {
        expect(MollyProactiveService.classificarResposta(f), RespostaSimNao.sim, reason: f);
      }
    });

    test('não — e "não tomei" nunca vira sim', () {
      for (final f in ['não', 'ainda não', 'não tomei', 'nao tomei ainda', 'esqueci', 'não precisa']) {
        expect(MollyProactiveService.classificarResposta(f), RespostaSimNao.nao, reason: f);
      }
    });

    test('"assim" não contém "sim"; outro assunto vira pedido normal', () {
      expect(MollyProactiveService.classificarResposta('assim mesmo'), RespostaSimNao.outra);
      expect(MollyProactiveService.classificarResposta('que horas são'), RespostaSimNao.outra);
      expect(MollyProactiveService.classificarResposta(''), RespostaSimNao.outra);
    });
  });

  group('NotificationService — ids e deteccao de remedio', () {
    test('acompanhamento e relembrete nao colidem com o lembrete nem com o bom dia', () {
      final id = NotificationService.idDoLembrete('Losartana', DateTime(2026, 8, 28, 8));
      final acompanhamento = NotificationService.idAcompanhamento(id);
      expect(acompanhamento, isNot(id));
      expect(acompanhamento, isNot(8000));
      expect(acompanhamento, greaterThanOrEqualTo(0));
      expect(NotificationService.idRelembrar('abc', 0), isNot(NotificationService.idRelembrar('abc', 1)));
    });

    test('remedio sim, agua nao ("Tomar" = "Hora de tomar água!")', () {
      expect(NotificationService.pareceRemedio('Remedio', 'Losartana'), isTrue);
      expect(NotificationService.pareceRemedio('\u{1F48A} Hora do remédio!', 'Losartana'), isTrue);
      expect(NotificationService.pareceRemedio('\u{1F4A7} Hora de tomar água!', 'Água'), isFalse);
      expect(NotificationService.pareceRemedio('Consulta', 'Dentista'), isFalse);
    });
  });
}
