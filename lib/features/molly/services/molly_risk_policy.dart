import '../models/molly_risk_level.dart';
import '../models/molly_tool_result.dart';
import 'molly_tool_registry.dart';

/// Política de confirmação por nível de risco (TAREFA 4 do prompt mestre).
///
/// Regras, aplicadas ao `MollyRiskLevel` de cada ferramenta em
/// `MollyToolRegistry`:
/// - **LOW**: executa automaticamente.
/// - **MEDIUM**: executa automaticamente, a menos que [ambiguo] seja
///   `true` — sinal que quem chama passa quando a própria resolução dos
///   parâmetros foi incerta (ex.: mais de um familiar corresponde ao nome
///   dito). Só então pede confirmação.
/// - **CRITICAL**: sempre pede confirmação, exceto quando
///   [emergenciaAutorizada] for `true` — reservado para um gatilho
///   explícito de emergência já autorizado. Isso NÃO se aplica ao SOS por
///   voz ("SOCORRO"): aquele fluxo nunca passa por aqui, nunca é uma
///   ferramenta que a IA decide chamar (ver TAREFA 18 e
///   `docs/MOLLY_ARCHITECTURE_ANALYSIS.md`) — o parâmetro existe para uma
///   futura ferramenta crítica que também tenha um caminho de emergência
///   legítimo sem confirmação prévia, não para abrir uma exceção genérica.
///
/// Esta classe nunca decide o resultado de uma ferramenta sozinha por
/// causa do risco: ela só decide "executa" ou "pede confirmação primeiro"
/// e delega a execução de fato ao [MollyToolRegistry].
class MollyRiskPolicy {
  /// Avalia o risco da ferramenta [nomeFerramenta] e executa direto, ou
  /// devolve um `MollyToolResult` pedindo confirmação (sem executar nada).
  /// Quem chama decide como perguntar "sim"/"não" ao usuário; a resposta
  /// afirmativa deve vir de volta como [confirmarEExecutar].
  static Future<MollyToolResult> executar(
    String nomeFerramenta,
    Map<String, dynamic> parametros, {
    bool ambiguo = false,
    bool emergenciaAutorizada = false,
  }) async {
    final tool = MollyToolRegistry.buscar(nomeFerramenta);
    if (tool == null) {
      return MollyToolResult.falha('Não sei fazer isso ainda.', acao: nomeFerramenta);
    }

    final precisaConfirmar = switch (tool.risco) {
      MollyRiskLevel.low => false,
      MollyRiskLevel.medium => ambiguo,
      MollyRiskLevel.critical => !emergenciaAutorizada,
    };

    if (precisaConfirmar) {
      return MollyToolResult.confirmar(
        _perguntaDeConfirmacao(tool.nome, parametros),
        acao: tool.nome,
        parametrosPendentes: parametros,
      );
    }

    return MollyToolRegistry.executar(nomeFerramenta, parametros);
  }

  /// Executa a ferramenta [nomeFerramenta] sem checar risco — para o
  /// momento em que o usuário já respondeu "sim" a uma pergunta de
  /// [MollyToolResult.confirmar]. Os parâmetros devem vir de
  /// `resultadoAnterior.dados['parametrosPendentes']`, não recalculados do
  /// zero (evita reinterpretar a frase e mudar o que será executado).
  static Future<MollyToolResult> confirmarEExecutar(
    String nomeFerramenta,
    Map<String, dynamic> parametrosPendentes,
  ) {
    return MollyToolRegistry.executar(nomeFerramenta, parametrosPendentes);
  }

  /// Pergunta curta e natural (TAREFA 11/12 do prompt mestre: linguagem
  /// simples, poucas frases) para cada ferramenta que pode pedir
  /// confirmação. Genérica por padrão — cada ferramenta nova que vier a
  /// precisar de uma pergunta mais específica pode ser adicionada aqui.
  static String _perguntaDeConfirmacao(String nomeFerramenta, Map<String, dynamic> parametros) {
    switch (nomeFerramenta) {
      case 'callFamilyMember':
        final nome = (parametros['nomeFamiliar'] as String?)?.trim();
        return (nome != null && nome.isNotEmpty)
            ? 'Você quer que eu avise $nome para te ligar?'
            : 'Você quer que eu avise seu familiar para te ligar?';
      case 'sendFamilyMessage':
        final nome = (parametros['nomeFamiliar'] as String?)?.trim();
        return (nome != null && nome.isNotEmpty)
            ? 'Posso mandar essa mensagem para $nome?'
            : 'Posso mandar essa mensagem?';
      case 'deleteReminder':
        return 'Você quer mesmo excluir esse lembrete? Essa ação não pode ser desfeita.';
      default:
        return 'Você confirma essa ação?';
    }
  }
}
