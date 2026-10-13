import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_respostas.dart';
import 'package:me_lembra_ai/features/molly/services/molly_safety_service.dart';

/// Sessão 26 — conversa e desabafo: protocolo de crise (local, nunca da IA)
/// e respostas curtas por palavra inteira. 100% puro.
void main() {
  group('crise: reconhece', () {
    const frases = [
      'eu quero morrer',
      'Molly, às vezes eu queria morrer',
      'tenho vontade de morrer',
      'acho que vou me matar',
      'penso em tirar minha própria vida',
      'não quero mais viver',
      'não aguento mais viver assim',
      'cansei de viver',
      'estou cansada de viver',
      'a vida não tem mais sentido',
      'ninguém sentiria minha falta',
      'todo mundo ficaria melhor sem mim',
      'queria estar morta',
      'ontem pensei em me matar', // passado também merece cuidado
    ];
    for (final f in frases) {
      test(f, () => expect(MollySafetyService.classificar(f), MollySafetyIntent.crise));
    }
  });

  group('crise: não confunde', () {
    const frases = [
      'não quero morrer',
      'eu quero morrer de rir com esse programa',
      'esse calor vai me matar',
      'ele vai me matar de susto',
      'não aguento mais esse calor',
      'minha mãe morreu ano passado e sinto saudade', // luto: acolher, não é crise
      'que horas são',
    ];
    for (final f in frases) {
      test(f, () => expect(MollySafetyService.classificar(f), isNot(MollySafetyIntent.crise)));
    }
  });

  test('a fala de crise orienta o CVV 188 e o socorro, e vem antes de remédio', () {
    expect(MollySafetyService.falaCrise, contains('188'));
    expect(MollySafetyService.falaCrise, contains('socorro'));
    // "quero morrer, tomei dois comprimidos": crise vence o excesso de remédio.
    expect(MollySafetyService.classificar('quero morrer, tomei dois comprimidos'), MollySafetyIntent.crise);
  });

  group('sim/não por palavra inteira', () {
    test('sim', () {
      for (final f in ['sim', 'pode', 'pode sim', 'claro', 'sim, avisa', 'isso']) {
        expect(MollyRespostas.ehAfirmativo(f), isTrue, reason: f);
      }
    });

    test('qualquer "não" vence; "assim" não é sim', () {
      for (final f in ['não', 'não, pode deixar', 'nao precisa', 'nunca', 'assim mesmo', 'não sei', '']) {
        expect(MollyRespostas.ehAfirmativo(f), isFalse, reason: f);
      }
    });
  });

  group('despedida', () {
    test('encerra', () {
      for (final f in ['tchau', 'obrigada', 'muito obrigado', 'pode parar', 'era só isso', 'até logo, Molly']) {
        expect(MollyRespostas.ehDespedida(f), isTrue, reason: f);
      }
    });

    test('não encerra no meio de um desabafo nem com "chega" de chegar', () {
      for (final f in [
        'obrigada por me ouvir, mas ainda estou muito triste hoje',
        'minha filha chega amanhã de viagem e estou com saudade',
        'estou me sentindo sozinha',
      ]) {
        expect(MollyRespostas.ehDespedida(f), isFalse, reason: f);
      }
    });
  });
}
