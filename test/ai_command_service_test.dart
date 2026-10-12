import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/services/ai_command_service.dart';

/// Acesso à internet da Molly (sessão 25): a localização só vai para o
/// backend em perguntas de tempo — mesmas palavras de `internet.py`.
void main() {
  test('perguntas de tempo mandam a localizacao', () {
    for (final f in ['Vai chover hoje?', 'como está o tempo', 'qual a temperatura', 'previsão do tempo',
        'vai fazer frio amanhã', 'preciso levar guarda-chuva']) {
      expect(AiCommandService.pareceTempo(f), isTrue, reason: f);
    }
  });

  test('outras frases nao mandam localizacao', () {
    for (final f in ['quanto tempo falta pro almoço', 'o que eu tenho hoje', 'quais as notícias',
        'me conta uma curiosidade', 'me lembra do remédio às oito']) {
      expect(AiCommandService.pareceTempo(f), isFalse, reason: f);
    }
  });
}
