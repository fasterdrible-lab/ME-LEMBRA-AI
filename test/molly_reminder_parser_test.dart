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

    test('corta "amanhã" mesmo no fim da frase (antes o \\b falhava depois do "ã")', () {
      expect(MollyReminderParser.limparTitulo('remédio amanhã de manhã'), 'remédio');
      expect(MollyReminderParser.limparTitulo('consulta amanhã'), 'consulta');
    });

    test('tira o pedido do começo ("me lembra de", "não deixa eu esquecer o")', () {
      expect(MollyReminderParser.limparTitulo('Me lembra do remédio às oito'), 'remédio');
      expect(MollyReminderParser.limparTitulo('não deixa eu esquecer o remédio às 8'), 'remédio');
    });

    test('"para a"/"as" sem horário depois não cortam o título', () {
      expect(MollyReminderParser.limparTitulo('ligar para a Ana às quatro'), 'ligar para a Ana');
      expect(MollyReminderParser.limparTitulo('buscar as crianças às 5'), 'buscar as crianças');
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

    test('"tomar banho/café" não é remédio; "tomar a losartana" é', () {
      expect(MollyReminderParser.inferirTipo('tomar banho'), 'Lembrete');
      expect(MollyReminderParser.inferirTipo('tomar café'), 'Lembrete');
      expect(MollyReminderParser.inferirTipo('tomar a losartana'), 'Remedio');
    });
  });

  group('MollyReminderParser.inferirRecorrencia', () {
    test('reconhece diário e semanal', () {
      expect(MollyReminderParser.inferirRecorrencia('todo dia às 8h'), 'diario');
      expect(MollyReminderParser.inferirRecorrencia('toda semana'), 'semanal');
      expect(MollyReminderParser.inferirRecorrencia('só amanhã'), 'unico');
    });
  });

  // Segunda-feira, 12/10/2026, 9h — fixo pra data/hora não depender do dia.
  final agora = DateTime(2026, 10, 12, 9);

  group('horários por extenso e período (sessão 26)', () {
    test('"às oito e meia", "oito", "vinte e uma horas"', () {
      expect(MollyReminderParser.extrairHora('remédio às oito e meia'), (hora: 8, minuto: 30));
      expect(MollyReminderParser.extrairHora('oito'), (hora: 8, minuto: 0));
      expect(MollyReminderParser.extrairHora('vinte e uma horas'), (hora: 21, minuto: 0));
      expect(MollyReminderParser.extrairHora('às oito da noite'), (hora: 20, minuto: 0));
    });

    test('1 a 5 horas sem período é da tarde; com "da manhã" não', () {
      expect(MollyReminderParser.extrairHora('ligar às quatro'), (hora: 16, minuto: 0));
      expect(MollyReminderParser.extrairHora('às 5 da manhã'), (hora: 5, minuto: 0));
    });

    test('"as duas caixas" não é horário', () {
      expect(MollyReminderParser.horasPorExtensoEmDigitos('comprar as duas caixas'), 'comprar as duas caixas');
      expect(MollyReminderParser.extrairHora('comprar as duas caixas'), isNull);
    });
  });

  group('extrairData — novos casos (sessão 26)', () {
    test('"depois de amanhã" é +2, não amanhã', () {
      expect(MollyReminderParser.extrairData('depois de amanhã', agora: agora), (dia: 14, mes: 10, ano: 2026));
    });

    test('dia da semana: a próxima; "na segunda" dito na segunda = semana que vem', () {
      expect(MollyReminderParser.extrairData('na quinta', agora: agora), (dia: 15, mes: 10, ano: 2026));
      expect(MollyReminderParser.extrairData('sexta-feira', agora: agora), (dia: 16, mes: 10, ano: 2026));
      expect(MollyReminderParser.extrairData('na segunda', agora: agora), (dia: 19, mes: 10, ano: 2026));
    });

    test('"da segunda dose" não é dia da semana', () {
      expect(MollyReminderParser.extrairData('tomar a vacina da segunda dose', agora: agora), isNull);
    });

    test('"dia 5" sem mês: o próximo dia 5', () {
      expect(MollyReminderParser.extrairData('consulta dia 5', agora: agora), (dia: 5, mes: 11, ano: 2026));
      expect(MollyReminderParser.extrairData('consulta dia 20', agora: agora), (dia: 20, mes: 10, ano: 2026));
    });
  });

  group('interpretarPedido — lembrete sem IA (sessão 26)', () {
    test('as frases do prompt mestre com gatilho viram o mesmo lembrete', () {
      for (final frase in ['Me lembra do remédio às oito.', 'Não deixa eu esquecer o remédio às oito.']) {
        final p = MollyReminderParser.interpretarPedido(frase, agora: agora)!;
        expect(p.titulo, 'Remédio', reason: frase);
        expect(p.tipo, 'Remedio', reason: frase);
        // 8h já passou às 9h: a próxima vez é amanhã.
        expect(p.dataHora, DateTime(2026, 10, 13, 8), reason: frase);
      }
    });

    test('critério de aceitação: "me lembra de ligar para Ana às quatro"', () {
      final p = MollyReminderParser.interpretarPedido('me lembra de ligar para Ana às quatro', agora: agora)!;
      expect(p.titulo, 'Ligar para Ana');
      expect(p.tipo, 'Lembrete');
      expect(p.dataHora, DateTime(2026, 10, 12, 16));
    });

    test('recorrência, dia da semana e "depois de amanhã"', () {
      final diario = MollyReminderParser.interpretarPedido('me lembra do remédio todo dia às oito da noite', agora: agora)!;
      expect((diario.titulo, diario.recorrencia, diario.dataHora), ('Remédio', 'diario', DateTime(2026, 10, 12, 20)));

      final quinta = MollyReminderParser.interpretarPedido('me lembra da reunião na quinta às 10', agora: agora)!;
      expect((quinta.titulo, quinta.tipo, quinta.dataHora), ('Reunião', 'Reuniao', DateTime(2026, 10, 15, 10)));

      final pao = MollyReminderParser.interpretarPedido('me lembra de comprar pão depois de amanhã às 9', agora: agora)!;
      expect((pao.titulo, pao.dataHora), ('Comprar pão', DateTime(2026, 10, 14, 9)));
    });

    test('"daqui a vinte minutos" / "daqui meia hora"', () {
      final agua = MollyReminderParser.interpretarPedido('me lembra de tomar água daqui a vinte minutos', agora: agora)!;
      expect((agua.titulo, agua.tipo, agua.dataHora), ('Tomar água', 'Tomar', DateTime(2026, 10, 12, 9, 20)));
      final bolo = MollyReminderParser.interpretarPedido('me lembra de tirar o bolo do forno daqui meia hora', agora: agora)!;
      expect(bolo.dataHora, DateTime(2026, 10, 12, 9, 30));
    });

    test('sem hora: devolve o pedido com dataHora null (a Molly pergunta "Que horas?")', () {
      final p = MollyReminderParser.interpretarPedido('me lembra da consulta amanhã', agora: agora)!;
      expect(p.titulo, 'Consulta');
      expect(p.dataHora, isNull);
    });

    test('o que não é claro vai para a IA (null)', () {
      for (final frase in [
        'me lembra duas horas antes da consulta',
        'quais são meus lembretes',
        'me lembra às 8',
        'coloca um lembrete para oito horas',
        'às oito eu preciso tomar meu remédio', // sem gatilho no começo
        'me lembra de tomar o remédio quando acordar',
        'me lembra da consulta semana que vem',
        'me lembra de pagar a conta todo dia 5',
        'me lembra de ligar daqui a pouco',
      ]) {
        expect(MollyReminderParser.interpretarPedido(frase, agora: agora), isNull, reason: frase);
      }
    });
  });
}
