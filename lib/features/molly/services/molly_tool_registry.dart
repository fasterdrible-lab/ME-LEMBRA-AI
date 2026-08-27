import '../models/molly_tool_definition.dart';
import '../models/molly_tool_result.dart';
import '../tools/family_tool.dart';
import '../tools/location_tool.dart';
import '../tools/profile_tool.dart';
import '../tools/reminder_tool.dart';

/// Catálogo central de ferramentas que a MOLLY pode executar (TAREFA 3 do
/// prompt mestre — ver também `docs/MOLLY_ARCHITECTURE_ANALYSIS.md`,
/// seção 2, sobre por que o tool-calling é resolvido no lado Dart em vez
/// de trocar o backend por function-calling nativo da API).
///
/// Cada entrada é um wrapper fino sobre um serviço já existente do app —
/// o registro nunca acessa Firestore diretamente, só delega. A
/// classificação de risco de cada ferramenta é METADADO; a política de
/// quando confirmar por causa dele é aplicada por quem despacha (ver
/// TAREFA 4 / `molly_controller.dart`, ainda não construído).
///
/// Ferramentas deliberadamente fora deste catálogo inicial (ver TAREFA 3
/// do prompt mestre, que já não as lista): disparo de SOS (nunca deve ser
/// uma "ferramenta" que a IA decide executar — é sempre detecção local,
/// TAREFA 18) e ações de lista de compras/alertas (ainda resolvidas
/// internamente por `MollyAgentService`, não formalizadas como tool).
class MollyToolRegistry {
  static final Map<String, MollyToolDefinition> _ferramentas = {
    for (final tool in [
      ReminderTool.createReminder,
      ReminderTool.getTodayReminders,
      ReminderTool.getTomorrowReminders,
      ReminderTool.updateReminder,
      ReminderTool.deleteReminder,
      ReminderTool.confirmReminder,
      ReminderTool.getReminderHistory,
      FamilyTool.getFamilyMembers,
      FamilyTool.sendFamilyMessage,
      FamilyTool.callFamilyMember,
      LocationTool.getCurrentLocation,
      ProfileTool.getUserProfile,
    ])
      tool.nome: tool,
  };

  /// Todas as ferramentas registradas, para inspeção/documentação (ex.:
  /// montar a lista de `tools` de uma futura API de function-calling).
  static List<MollyToolDefinition> get todas => _ferramentas.values.toList(growable: false);

  static MollyToolDefinition? buscar(String nome) => _ferramentas[nome];

  /// Executa a ferramenta [nome] com os [parametros] dados, validando
  /// antes. Nunca lança — ferramenta inexistente ou parâmetro obrigatório
  /// ausente vira um `MollyToolResult` de falha, para quem chamou decidir
  /// o que falar ao usuário.
  static Future<MollyToolResult> executar(String nome, Map<String, dynamic> parametros) async {
    final tool = _ferramentas[nome];
    if (tool == null) {
      return MollyToolResult.falha('Não sei fazer isso ainda.', acao: nome);
    }
    final erro = tool.validar(parametros);
    if (erro != null) {
      return MollyToolResult.falha(erro, acao: nome);
    }
    return tool.executar(parametros);
  }
}
