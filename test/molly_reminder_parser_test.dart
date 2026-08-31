import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_reminder_parser.dart';

/// Testes do extrator local de dia/hora/título/tipo/recorrência usado pela
/// coleta de lembrete da tela /molly (sessão 24, pré-requisito pra trocar
/// o "Falar Comando" pela Molly). 100% puro Dart, sem Firebase/plugins —
/// mesma lógica de `elderly_screen.dart`, só extraída pra cá.
void main() {
  group('MollyReminderParser.extrairData', () {
    test('reconhece "amanhã" e "hoje"', () {
      final amanha = MollyReminderParser.extrairData('marca amanhã');
      final hoje = MollyReminderParser.extrairData('marca hoje');
      final refAmanha = DateTime.now().add(const Duration(days: 1));
      final refHoje = DateTime.now();
      expect(amanha, isNotNull);
      expect(amanha!.dia, refAmanha.day);
      expect(hoje, isNotNull);
      expect(hoje!.dia, refHoje.day);
    });

    test('reconhece "28 de setembro"', () {
      final data = MollyReminderParser.extrairData('consulta dia 28 de setembro');
      expect(data, isNotNull);
      expect(data!.dia, 28);
      expect(data.mes, 9);
    });

    test('devolve null quando não acha nenhuma data', () {
      expect(MollyReminderParser.extrairData('não sei quando'), isNull);
    });
  });

  group('MollyReminderParser.extrairHora', () {
    test('reconhece "às 15h30" numa frase completa', () {
      final hora = MollyReminderParser.extrairHora('consulta às 15h30');
      expect(hora, isNotNull);
      expect(hora!.hora, 15);
      expect(hora.minuto, 30);
    });

    test('reconhece resposta curta "15" como resposta a "que horas?"', () {
      final hora = MollyReminderParser.extrairHora('15');
      expect(hora, isNotNull);
      expect(hora!.hora, 15);
    });

    test('converte "3 da tarde" pra 15h', () {
      final hora = MollyReminderParser.extrairHora('às 3 da tarde');
      expect(hora, isNotNull);
      expect(hora!.hora, 15);
    });

    test('reconhece meio-dia e meia-noite', () {
      final meioDia = MollyReminderParser.extrairHora('ao meio-dia');
      final meiaNoite = MollyReminderParser.extrairHora('à meia-noite');
      expect(meioDia, isNotNull);
      expect(meioDia!.hora, 12);
      expect(meiaNoite, isNotNull);
      expect(meiaNoite!.hora, 0);
    });

    test('devolve null quando não acha nenhuma hora', () {
      expect(MollyReminderParser.extrairHora('não sei'), isNull);
    });
  });

  group('MollyReminderParser.limparTitulo', () {
    test('remove trechos de data/hora, mantendo só o título', () {
      expect(
        MollyReminderParser.limparTitulo('consulta com o dentista às 15h'),
        'consulta com o dentista',
      );
      expect(
        MollyReminderParser.limparTitulo('remédio às 8h da manhã'),
        'remédio',
      );
    });

    test('limitação conhecida, herdada de elderly_screen.dart: não corta quando '
        '"amanhã"/"manhã" é a última palavra (a acentuação faz o \\b da regex '
        'não casar) — cosmético: não afeta a data/hora extraída, só deixa a '
        'palavra sobrando no título exibido', () {
      expect(
        MollyReminderParser.limparTitulo('remédio amanhã de manhã'),
        'remédio amanhã de manhã',
      );
    });
  });

  group('MollyReminderParser.inferirTipo', () {
    test('reconhece as categorias principais', () {
      expect(MollyReminderParser.inferirTipo('tomar remédio'), 'Remedio');
      expect(MollyReminderParser.inferirTipo('tomar água'), 'Tomar');
      expect(MollyReminderParser.inferirTipo('ir ao mercado'), 'Mercado');
      expect(MollyReminderParser.inferirTipo('consulta com o dentista'), 'Consulta');
      expect(MollyReminderParser.inferirTipo('aniversário da neta'), 'Aniversario');
      expect(MollyReminderParser.inferirTipo('reunião de família'), 'Reuniao');
    });

    test('cai em Lembrete genérico sem assumir Remédio por padrão', () {
      expect(MollyReminderParser.inferirTipo('ligar pro João'), 'Lembrete');
    });
  });

  group('MollyReminderParser.inferirRecorrencia', () {
    test('reconhece diário e semanal', () {
      expect(MollyReminderParser.inferirRecorrencia('todo dia às 8h'), 'diario');
      expect(MollyReminderParser.inferirRecorrencia('toda semana'), 'semanal');
      expect(MollyReminderParser.inferirRecorrencia('só amanhã'), 'unico');
    });
  });
}
