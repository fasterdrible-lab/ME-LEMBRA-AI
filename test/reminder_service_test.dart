import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/services/reminder_service.dart';
import 'package:me_lembra_ai/models/reminder.dart';

void main() {
  group('ReminderService', () {
    test('Adicionar lembrete não deve lançar erro com usuário nulo', () async {
      final reminder = Reminder(
        id: '',
        userId: '',
        title: 'Teste',
        type: 'Remedio',
        description: 'Descrição',
        dateTime: DateTime.now(),
        repeat: 'unico',
        notification: '',
        perfil: 'Adulto',
      );
      // Não deve lançar erro mesmo sem usuário autenticado
      await ReminderService.add(reminder);
    });

    test('Stream de lembretes sem usuário retorna vazio', () async {
      final stream = ReminderService.stream();
      expect(await stream.isEmpty, true);
    });

    test('Atualizar lembrete não deve lançar erro', () async {
      final reminder = Reminder(
        id: 'fakeId',
        userId: '',
        title: 'Teste Update',
        type: 'Remedio',
        description: 'Descrição',
        dateTime: DateTime.now(),
        repeat: 'unico',
        notification: '',
        perfil: 'Adulto',
      );
      // Não deve lançar erro mesmo sem usuário autenticado
      await ReminderService.update(reminder);
    });

    test('Deletar lembrete não deve lançar erro', () async {
      // Não deve lançar erro mesmo sem usuário autenticado
      await ReminderService.delete('fakeId', notificationId: 123);
    });

    test('Confirmar lembrete não deve lançar erro', () async {
      // Não deve lançar erro mesmo sem usuário autenticado
      await ReminderService.confirm('fakeId');
    });

    test('Migração de dados antigos não deve lançar erro', () async {
      await ReminderService.migrarSharedPreferences([
        'Remedio|Teste|Descrição|unico|10:00'
      ], 'Adulto');
    });
  });
}
