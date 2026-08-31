import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_proactive_service.dart';
import 'package:me_lembra_ai/models/reminder.dart';

/// Testes da proatividade da MOLLY (Fase 8 do prompt mestre): avisar
/// remédio atrasado sem o usuário precisar perguntar. Só cobre
/// [MollyProactiveService.gerarAviso] — a versão pura, que recebe a lista
/// já pronta e nunca toca `FirebaseAuth`/Firestore (mesmo padrão de
/// `MollyBriefingService.gerarDeLista`, achado da Tarefa 10: o primeiro
/// acesso a `FirebaseAuth.instance` num processo de teste não tem mock
/// completo neste projeto).
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
    test('avisa quando um remédio de hoje está atrasado há mais de 30 min', () {
      final lista = [remedio(dateTime: DateTime(2026, 8, 28, 8, 0))];
      final aviso = MollyProactiveService.gerarAviso(lista, agora: agora);
      expect(aviso, isNotNull);
      expect(aviso, contains('Losartana'));
      expect(aviso, contains('Já tomou?'));
    });

    test('não avisa quando o remédio já foi confirmado', () {
      final lista = [remedio(dateTime: DateTime(2026, 8, 28, 8, 0), confirmed: true)];
      expect(MollyProactiveService.gerarAviso(lista, agora: agora), isNull);
    });

    test('não avisa quando o atraso é menor que o mínimo (30 min)', () {
      final lista = [remedio(dateTime: DateTime(2026, 8, 28, 9, 45))];
      expect(MollyProactiveService.gerarAviso(lista, agora: agora), isNull);
    });

    test('não avisa pra lembrete de outro tipo (ex.: Consulta)', () {
      final lista = [remedio(dateTime: DateTime(2026, 8, 28, 8, 0), type: 'Consulta')];
      expect(MollyProactiveService.gerarAviso(lista, agora: agora), isNull);
    });

    test('não avisa pra remédio de outro dia (ontem)', () {
      final lista = [remedio(dateTime: DateTime(2026, 8, 27, 8, 0))];
      expect(MollyProactiveService.gerarAviso(lista, agora: agora), isNull);
    });

    test('reconhece o tipo "Tomar" (água) também', () {
      final lista = [remedio(dateTime: DateTime(2026, 8, 28, 8, 0), type: 'Tomar', title: 'Água')];
      expect(MollyProactiveService.gerarAviso(lista, agora: agora), isNotNull);
    });

    test('com mais de um atrasado, cita a quantidade e o mais antigo', () {
      final lista = [
        remedio(dateTime: DateTime(2026, 8, 28, 9, 0), title: 'Vitamina D'),
        remedio(dateTime: DateTime(2026, 8, 28, 8, 0), title: 'Losartana'),
      ];
      final aviso = MollyProactiveService.gerarAviso(lista, agora: agora);
      expect(aviso, contains('2 remédios'));
      expect(aviso, contains('Losartana'));
      expect(aviso, isNot(contains('Vitamina D')));
    });

    test('lista vazia não gera aviso', () {
      expect(MollyProactiveService.gerarAviso(const [], agora: agora), isNull);
    });
  });
}
