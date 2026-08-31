import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/models/molly_tool_result.dart';
import 'package:me_lembra_ai/services/ai_command_service.dart';

/// Testes do gatilho de memória de longo prazo (sessão 24): a IA pode
/// sugerir, junto de qualquer ação, uma preferência durável do usuário
/// (`ComandoAction.memoria`) — `MollyToolResult.comPropostaDeMemoria`
/// anexa isso a um resultado já pronto sem perder nada do que já tinha.
/// 100% puro Dart — não cobre `MollyAgentService.processar` (esse toca
/// `SettingsService`/Firebase), só as duas peças de dados que sustentam a
/// regra "nunca salvar sozinho, sempre perguntar antes".
void main() {
  group('ComandoAction.fromJson — campo memoria', () {
    test('reconhece uma proposta válida (tipo + valor + confianca)', () {
      final acao = ComandoAction.fromJson({
        'acao': 'responder',
        'fala': 'Combinado!',
        'memoria': {'tipo': 'nome_preferido', 'valor': 'Seu Antônio', 'confianca': 0.9},
      });
      expect(acao.memoriaTipo, 'nome_preferido');
      expect(acao.memoriaValor, 'Seu Antônio');
      expect(acao.memoriaConfianca, 0.9);
    });

    test('ignora proposta incompleta (falta valor)', () {
      final acao = ComandoAction.fromJson({
        'acao': 'responder',
        'fala': 'Combinado!',
        'memoria': {'tipo': 'nome_preferido'},
      });
      expect(acao.memoriaTipo, isNull);
      expect(acao.memoriaValor, isNull);
    });

    test('sem campo memoria não quebra nada (caso comum)', () {
      final acao = ComandoAction.fromJson({'acao': 'ouvir_lembretes', 'fala': 'Você tem 2 lembretes.'});
      expect(acao.memoriaTipo, isNull);
      expect(acao.memoriaValor, isNull);
      expect(acao.memoriaConfianca, isNull);
    });
  });

  group('MollyToolResult.comPropostaDeMemoria', () {
    test('preserva fala/sucesso/acao do resultado original e liga a flag', () {
      final original = MollyToolResult.sucesso('Lembrete criado.', acao: 'createReminder');
      final comProposta = original.comPropostaDeMemoria(
        tipo: 'horario_rotina',
        valor: 'Almoça ao meio-dia',
        confianca: 0.8,
      );

      expect(comProposta.fala, 'Lembrete criado.');
      expect(comProposta.acao, 'createReminder');
      expect(comProposta.sucesso, isTrue);
      expect(comProposta.precisaConfirmacaoDeMemoria, isTrue);
      expect(comProposta.dados?['memoriaProposta'], {
        'tipo': 'horario_rotina',
        'valor': 'Almoça ao meio-dia',
        'confianca': 0.8,
      });
    });

    test('não mexe nas outras flags de confirmação', () {
      final original = MollyToolResult.confirmar(
        'Quer mesmo excluir?',
        acao: 'deleteReminder',
        parametrosPendentes: {'id': '123'},
      );
      final comProposta = original.comPropostaDeMemoria(tipo: 'x', valor: 'y', confianca: 0.5);

      expect(comProposta.precisaConfirmacao, isTrue);
      expect(comProposta.precisaConfirmacaoDeMemoria, isTrue);
      expect(comProposta.dados?['parametrosPendentes'], {'id': '123'});
      expect(comProposta.dados?['memoriaProposta'], isNotNull);
    });

    test('resultado sem proposta continua com a flag desligada', () {
      final resultado = MollyToolResult.sucesso('Você tem 1 lembrete.');
      expect(resultado.precisaConfirmacaoDeMemoria, isFalse);
      expect(resultado.dados?['memoriaProposta'], isNull);
    });
  });
}
