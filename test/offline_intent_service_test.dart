import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/offline_intent_service.dart';

/// Testes das TAREFAs 17 (modo offline), 18 (SOS por voz) e 19 (prevenção
/// de falsos positivos nas frases suaves de emergência da TAREFA 18).
/// `classificar()` é puro — sem Firebase, sem IA, sem rede — e é onde
/// mora o que essas tarefas realmente pedem (detecção local). `tentar()`
/// só é testado nos casos que não tocam Firestore ("que horas são" e
/// "possível emergência", que só monta um `MollyToolResult` sem executar
/// nada) — os demais delegam a serviços que tocam `FirebaseAuth`, cujo
/// primeiro uso num processo de teste tem o problema de platform channel
/// sem mock já documentado na Tarefa 10 (evitado aqui de propósito).
void main() {
  group('OfflineIntentService.classificar', () {
    test('reconhece os cinco comandos de exemplo literais da TAREFA 17', () {
      expect(OfflineIntentService.classificar('Molly, socorro.'), OfflineIntent.socorro);
      expect(OfflineIntentService.classificar('Molly, ligar para Ana.'), OfflineIntent.ligarPara);
      expect(OfflineIntentService.classificar('Molly, meus lembretes.'), OfflineIntent.meusLembretes);
      expect(OfflineIntentService.classificar('Molly, que horas são?'), OfflineIntent.queHoras);
      expect(
        OfflineIntentService.classificar('Molly, confirmar remédio.'),
        OfflineIntent.confirmarRemedio,
      );
    });

    test('SOCORRO em qualquer caixa e mesmo dentro de uma frase maior', () {
      expect(OfflineIntentService.classificar('socorro'), OfflineIntent.socorro);
      expect(OfflineIntentService.classificar('SOCORRO'), OfflineIntent.socorro);
      expect(OfflineIntentService.classificar('me ajuda, SOCORRO!'), OfflineIntent.socorro);
    });

    test('extrai o nome de variações de "ligar para"', () {
      expect(OfflineIntentService.classificar('liga pra Ana'), OfflineIntent.ligarPara);
      expect(OfflineIntentService.classificar('Molly, ligar para minha filha'), OfflineIntent.ligarPara);
    });

    test('nao confunde "ligar para o medico as 8" com um pedido de ligacao', () {
      // Isso é um lembrete disfarçado (tem hora), não uma chamada agora.
      expect(
        OfflineIntentService.classificar('Ligar para o médico às 8'),
        isNot(OfflineIntent.ligarPara),
      );
      expect(
        OfflineIntentService.classificar('não deixa eu esquecer de ligar pro médico às 8'),
        isNot(OfflineIntent.ligarPara),
      );
    });

    test('frases que nao comecam pedindo uma ligacao nao viram ligarPara', () {
      expect(
        OfflineIntentService.classificar('preciso ligar pra Ana mais tarde, mas antes me lembra do remédio'),
        isNot(OfflineIntent.ligarPara),
      );
    });

    test('reconhece variacoes de "meus lembretes" e "que horas"', () {
      expect(OfflineIntentService.classificar('quais são meus lembretes de hoje'), OfflineIntent.meusLembretes);
      expect(OfflineIntentService.classificar('que horas são agora'), OfflineIntent.queHoras);
      expect(OfflineIntentService.classificar('me diz que hora é'), OfflineIntent.queHoras);
    });

    test('reconhece variacoes de "confirmar remedio"', () {
      expect(OfflineIntentService.classificar('confirma o remedio'), OfflineIntent.confirmarRemedio);
      expect(OfflineIntentService.classificar('quero confirmar o medicamento'), OfflineIntent.confirmarRemedio);
    });

    test('frases de outras intencoes ou fora do escopo local nao sao reconhecidas', () {
      expect(OfflineIntentService.classificar('Me lembra do remédio às oito.'), OfflineIntent.nenhuma);
      expect(OfflineIntentService.classificar('Adiciona leite na lista de compras'), OfflineIntent.nenhuma);
      expect(OfflineIntentService.classificar('Conte uma história'), OfflineIntent.nenhuma);
      expect(OfflineIntentService.classificar(''), OfflineIntent.nenhuma);
      expect(OfflineIntentService.classificar('   '), OfflineIntent.nenhuma);
    });

    test('reconhece as cinco frases mais suaves de emergencia da TAREFA 18', () {
      const frases = [
        'me ajuda',
        'chama minha filha',
        'chama alguém',
        'estou passando mal',
        'preciso de ajuda',
      ];
      for (final frase in frases) {
        expect(OfflineIntentService.classificar(frase), OfflineIntent.possivelEmergencia, reason: frase);
      }
    });

    test('SOCORRO tem prioridade sobre as frases mais suaves quando aparecem juntas', () {
      expect(OfflineIntentService.classificar('preciso de ajuda, SOCORRO'), OfflineIntent.socorro);
    });

    test('TAREFA 19: nao confunde uma frase suave embutida dentro de outra palavra', () {
      // "ajudaram" contém "ajuda" como prefixo, mas não é a mesma palavra.
      expect(
        OfflineIntentService.classificar('ontem eles me ajudaram muito com a mudança'),
        isNot(OfflineIntent.possivelEmergencia),
      );
    });

    test('TAREFA 19: uma negacao logo antes da frase suave nao dispara a emergencia', () {
      expect(
        OfflineIntentService.classificar('não preciso de ajuda, já resolvi sozinho'),
        isNot(OfflineIntent.possivelEmergencia),
      );
      expect(
        OfflineIntentService.classificar('nunca preciso de ajuda pra essas coisas'),
        isNot(OfflineIntent.possivelEmergencia),
      );
    });

    test('TAREFA 19: relato de algo do passado ja resolvido nao dispara a emergencia', () {
      expect(
        OfflineIntentService.classificar('ontem eu disse que preciso de ajuda, mas já passou'),
        isNot(OfflineIntent.possivelEmergencia),
      );
    });

    test('TAREFA 19: a frase suave real continua reconhecida sem negacao/passado por perto', () {
      expect(
        OfflineIntentService.classificar('mãe, eu realmente preciso de ajuda agora'),
        OfflineIntent.possivelEmergencia,
      );
    });
  });

  group('OfflineIntentService.tentar', () {
    test('"que horas sao" e respondido sem tocar Firebase', () async {
      final resultado = await OfflineIntentService.tentar('Molly, que horas são?');
      expect(resultado, isNotNull);
      expect(resultado!.sucesso, isTrue);
      expect(resultado.acao, 'que_horas');
      expect(resultado.fala, contains('Agora são'));
    });

    test('frase nao reconhecida devolve null (quem chama tenta a IA)', () async {
      final resultado = await OfflineIntentService.tentar('Me lembra do remédio às oito.');
      expect(resultado, isNull);
    });

    test('frase de possivel emergencia (TAREFA 18) pede confirmacao visual, sem tocar Firebase', () async {
      final resultado = await OfflineIntentService.tentar('Molly, estou passando mal.');
      expect(resultado, isNotNull);
      expect(resultado!.precisaConfirmacaoDeEmergencia, isTrue);
      expect(resultado.sucesso, isTrue);
      expect(resultado.fala, 'Parece que você precisa de ajuda.');
      expect(resultado.dados?['motivo'], 'Molly, estou passando mal.');
      // Não é o mesmo tipo de confirmação de risco (TAREFA 4) — são
      // fluxos de UI diferentes (contagem visual vs. sim/não falado).
      expect(resultado.precisaConfirmacao, isFalse);
    });
  });
}
