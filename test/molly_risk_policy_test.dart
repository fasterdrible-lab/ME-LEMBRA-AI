import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_risk_policy.dart';

/// Testa só o portão de confirmação (TAREFA 4 do prompt mestre) — a parte
/// crítica de segurança da política. Os três casos aqui nunca chegam a
/// chamar o serviço de verdade por trás da ferramenta (o `switch` de
/// `MollyRiskPolicy.executar` retorna antes disso), então rodam sem
/// Firebase inicializado. Testar o caminho "executa direto" (LOW, ou
/// MEDIUM sem ambiguidade) exigiria mocks de Firebase que o projeto ainda
/// não tem para este módulo — ver `docs/MOLLY_ARCHITECTURE_ANALYSIS.md`,
/// item 6 dos riscos, e a futura TAREFA 28.
void main() {
  group('MollyRiskPolicy', () {
    test('ferramenta CRITICAL sem emergência autorizada pede confirmação, sem executar', () async {
      final resultado = await MollyRiskPolicy.executar(
        'deleteReminder',
        {'id': 'id-qualquer'},
      );
      expect(resultado.precisaConfirmacao, isTrue);
      expect(resultado.sucesso, isTrue);
      expect(resultado.dados?['parametrosPendentes'], {'id': 'id-qualquer'});
    });

    test('ferramenta CRITICAL com emergência autorizada não pede confirmação (chega a tentar executar)', () async {
      // "Chega a tentar executar" e não "executa com sucesso": sem
      // FirebaseAuth inicializado, a chamada real de callFamilyMember
      // lança — o que já prova que o portão de confirmação foi
      // corretamente pulado (senão o erro seria outro/nenhum).
      await expectLater(
        MollyRiskPolicy.executar(
          'callFamilyMember',
          {'nomeFamiliar': 'Ana'},
          emergenciaAutorizada: true,
        ),
        throwsA(anything),
      );
    });

    test('ferramenta MEDIUM com ambiguidade pede confirmação, sem executar', () async {
      final resultado = await MollyRiskPolicy.executar(
        'sendFamilyMessage',
        {'nomeFamiliar': 'Ana', 'mensagem': 'Oi'},
        ambiguo: true,
      );
      expect(resultado.precisaConfirmacao, isTrue);
      expect(resultado.fala, contains('Ana'));
    });

    test('ferramenta inexistente falha sem lançar exceção', () async {
      final resultado = await MollyRiskPolicy.executar('naoExisteEssaFerramenta', const {});
      expect(resultado.sucesso, isFalse);
      expect(resultado.precisaConfirmacao, isFalse);
    });
  });
}
