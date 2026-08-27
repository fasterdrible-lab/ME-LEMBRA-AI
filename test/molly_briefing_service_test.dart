import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_briefing_service.dart';
import 'package:me_lembra_ai/models/reminder.dart';

/// Testes puros da TAREFA 13 (briefing matinal) — `gerarDeLista` recebe
/// os lembretes já prontos, então não toca Firestore/FirebaseAuth (mesmo
/// cuidado da Tarefa 10, pra não repetir o achado de teste instável com
/// `FirebaseAuth.instance`).
void main() {
  Reminder lembrete({required String type, required int hora, String title = ''}) {
    final agora = DateTime.now();
    return Reminder(
      id: 'id-$type-$hora',
      userId: 'uid',
      title: title,
      type: type,
      description: '',
      dateTime: DateTime(agora.year, agora.month, agora.day, hora),
      repeat: 'unico',
      notification: '',
      perfil: 'Vovô / Vovó',
    );
  }

  group('MollyBriefingService.gerarDeLista', () {
    test('sem lembretes, so cumprimenta', () {
      expect(MollyBriefingService.gerarDeLista(const []), 'Bom dia. Você não tem lembretes hoje.');
    });

    test('um lembrete: conta 1 e nomeia por tipo', () {
      final fala = MollyBriefingService.gerarDeLista([lembrete(type: 'Remedio', hora: 8)]);
      expect(fala, 'Bom dia. Você tem 1 lembrete hoje. Seu remédio é às 8 horas. Quer que eu leia tudo?');
    });

    test('exemplo literal da TAREFA 13: remedio as 8h e consulta as 14h', () {
      final fala = MollyBriefingService.gerarDeLista([
        lembrete(type: 'Remedio', hora: 8),
        lembrete(type: 'Consulta', hora: 14),
      ]);
      expect(
        fala,
        'Bom dia. Você tem 2 lembretes hoje. '
        'Seu remédio é às 8 horas. Sua consulta é às 14 horas. '
        'Quer que eu leia tudo?',
      );
    });

    test('tres ou mais lembretes: destaca so os dois primeiros, nunca a lista inteira', () {
      final fala = MollyBriefingService.gerarDeLista([
        lembrete(type: 'Remedio', hora: 8),
        lembrete(type: 'Consulta', hora: 10),
        lembrete(type: 'Reuniao', hora: 15),
        lembrete(type: 'Aniversario', hora: 19),
      ]);
      expect(fala, contains('Você tem 4 lembretes hoje.'));
      expect(fala, contains('Seu remédio é às 8 horas.'));
      expect(fala, contains('Sua consulta é às 10 horas.'));
      expect(fala.contains('reunião'), isFalse);
      expect(fala.contains('aniversário'), isFalse);
      expect(fala, endsWith('Quer que eu leia tudo?'));
    });

    test('tipo sem sujeito conhecido usa o titulo, com fallback pro tipo', () {
      final comTitulo =
          MollyBriefingService.gerarDeLista([lembrete(type: 'Mercado', hora: 9, title: 'Feira')]);
      expect(comTitulo, contains('Feira é às 9 horas.'));

      final semTitulo = MollyBriefingService.gerarDeLista([lembrete(type: 'Mercado', hora: 9)]);
      expect(semTitulo, contains('Mercado é às 9 horas.'));
    });
  });
}
