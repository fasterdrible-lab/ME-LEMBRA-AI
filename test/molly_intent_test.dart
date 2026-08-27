import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/models/molly_intent.dart';

/// Testes puros das TAREFAs 14 (comandos naturais) e 15 (Modo Companhia)
/// — sem Firebase, sem plugins, sem rede: confirma que frases bem
/// diferentes geram o mesmo sinal de intenção.
void main() {
  group('MollyIntentHints.pareceCriarLembrete', () {
    test('reconhece as quatro frases de exemplo literais da TAREFA 14', () {
      const frases = [
        'Me lembra do remédio às oito.',
        'Coloca um lembrete para oito horas.',
        'Às oito eu preciso tomar meu remédio.',
        'Não deixa eu esquecer o remédio às oito.',
      ];
      for (final frase in frases) {
        expect(MollyIntentHints.pareceCriarLembrete(frase), isTrue, reason: frase);
      }
    });

    test('ignora maiusculas/minusculas e acentuacao', () {
      expect(MollyIntentHints.pareceCriarLembrete('ME LEMBRA DO REMÉDIO ÀS OITO'), isTrue);
      expect(MollyIntentHints.pareceCriarLembrete('nao deixa eu esquecer a consulta'), isTrue);
    });

    test('nao reconhece frases de outras intencoes', () {
      expect(MollyIntentHints.pareceCriarLembrete('Quais são meus lembretes de hoje?'), isFalse);
      expect(MollyIntentHints.pareceCriarLembrete('Adiciona leite na lista de compras'), isFalse);
      expect(MollyIntentHints.pareceCriarLembrete('SOCORRO'), isFalse);
      expect(MollyIntentHints.pareceCriarLembrete('Quais são meus alertas?'), isFalse);
    });
  });

  group('MollyIntentHints.pareceBuscarCompanhia (TAREFA 15)', () {
    test('reconhece as cinco frases de exemplo literais da TAREFA 15', () {
      const frases = [
        'Molly, converse comigo.',
        'Molly, estou sozinho.',
        'Molly, conte uma história.',
        'Molly, me fale alguma coisa boa.',
        'Molly, quero falar com minha filha.',
      ];
      for (final frase in frases) {
        expect(MollyIntentHints.pareceBuscarCompanhia(frase), isTrue, reason: frase);
      }
    });

    test('ignora maiusculas/minusculas e acentuacao', () {
      expect(MollyIntentHints.pareceBuscarCompanhia('CONTE UMA HISTÓRIA'), isTrue);
      expect(MollyIntentHints.pareceBuscarCompanhia('conta uma historia legal'), isTrue);
    });

    test('nao reconhece comandos claramente de outra intencao', () {
      expect(MollyIntentHints.pareceBuscarCompanhia('Me lembra do remédio às oito.'), isFalse);
      expect(MollyIntentHints.pareceBuscarCompanhia('Quais são meus lembretes de hoje?'), isFalse);
      expect(MollyIntentHints.pareceBuscarCompanhia('SOCORRO'), isFalse);
    });
  });
}
