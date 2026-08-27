import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_prompt_service.dart';

/// Testes puros das TAREFAs 11 (personalidade) e 12 (respostas curtas) —
/// sem Firebase, sem plugins.
void main() {
  group('MollyPromptService', () {
    test('exemplo ruim do prompt mestre e detectado como linguagem tecnica', () {
      expect(MollyPromptService.contemLinguagemTecnica(MollyPromptService.exemploRuim), isTrue);
    });

    test('exemplo bom do prompt mestre passa na checagem', () {
      expect(MollyPromptService.contemLinguagemTecnica(MollyPromptService.exemploBom), isFalse);
    });

    test('detecta termos tecnicos comuns, ignorando maiusculas/minusculas', () {
      expect(MollyPromptService.contemLinguagemTecnica('O SISTEMA apresentou um erro.'), isTrue);
      expect(MollyPromptService.contemLinguagemTecnica('Processando sua solicitação.'), isTrue);
    });

    test('frases simples e diretas nao disparam a checagem', () {
      expect(MollyPromptService.contemLinguagemTecnica('Não consegui ouvir agora.'), isFalse);
      expect(MollyPromptService.contemLinguagemTecnica('Lembrete criado para amanhã às 8 horas.'), isFalse);
    });
  });

  group('MollyPromptService.resumoCurto (TAREFA 12)', () {
    String descrever(String s) => s;

    test('lista vazia devolve string vazia', () {
      expect(
        MollyPromptService.resumoCurto<String>(
          itens: const [],
          nomeSingular: 'lembrete',
          nomePlural: 'lembretes',
          descrever: descrever,
        ),
        isEmpty,
      );
    });

    test('um item vira uma unica frase nomeando o item', () {
      final fala = MollyPromptService.resumoCurto<String>(
        itens: const ['Consulta, às 14 horas'],
        nomeSingular: 'lembrete',
        nomePlural: 'lembretes',
        descrever: descrever,
      );
      expect(fala, 'Você tem 1 lembrete: Consulta, às 14 horas.');
    });

    test('dois itens seguem o exemplo literal da TAREFA 12', () {
      final fala = MollyPromptService.resumoCurto<String>(
        itens: const ['um às dez da manhã', 'outro às três da tarde'],
        nomeSingular: 'compromisso',
        nomePlural: 'compromissos',
        descrever: descrever,
      );
      expect(fala, 'Você tem 2 compromissos. Um é um às dez da manhã, e o outro é outro às três da tarde.');
    });

    test('tres ou mais itens nao leem a lista inteira, so o primeiro', () {
      final fala = MollyPromptService.resumoCurto<String>(
        itens: const ['Remédio 8h', 'Consulta 10h', 'Reunião 15h', 'Aniversário 19h'],
        nomeSingular: 'lembrete',
        nomePlural: 'lembretes',
        descrever: descrever,
      );
      expect(fala, 'Você tem 4 lembretes. O primeiro é Remédio 8h.');
      expect(fala.contains('Consulta 10h'), isFalse);
      expect(fala.contains('Reunião 15h'), isFalse);
      expect(fala.split('.').where((s) => s.trim().isNotEmpty).length, lessThanOrEqualTo(3));
    });
  });
}
