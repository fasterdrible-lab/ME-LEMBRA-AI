import 'molly_risk_level.dart';
import 'molly_tool_result.dart';

/// Função que de fato executa uma ferramenta. Sempre delega a um serviço
/// já existente do app (`ReminderService`, `FamilyService`, etc.) — nunca
/// acessa Firestore diretamente.
typedef MollyToolHandler = Future<MollyToolResult> Function(Map<String, dynamic> parametros);

/// Um parâmetro aceito por uma ferramenta.
class MollyToolParam {
  final String nome;
  final String tipo; // 'string' | 'int' | 'datetime' | 'list<string>'
  final bool obrigatorio;
  final String descricao;

  const MollyToolParam({
    required this.nome,
    required this.tipo,
    this.obrigatorio = true,
    this.descricao = '',
  });
}

/// Descreve uma ferramenta que a MOLLY pode executar (TAREFA 3 do prompt
/// mestre): nome, o que faz, quais parâmetros aceita, nível de risco e a
/// função que executa. `validar` só checa presença/tipo básico dos
/// parâmetros obrigatórios — validação de conteúdo (ex.: "essa data faz
/// sentido?") é responsabilidade de cada `executar`.
class MollyToolDefinition {
  final String nome;
  final String descricao;
  final List<MollyToolParam> parametros;
  final MollyRiskLevel risco;
  final MollyToolHandler executar;

  const MollyToolDefinition({
    required this.nome,
    required this.descricao,
    required this.parametros,
    required this.risco,
    required this.executar,
  });

  /// Retorna uma mensagem de erro se algum parâmetro obrigatório estiver
  /// ausente ou vazio, ou `null` se [entrada] é válida.
  String? validar(Map<String, dynamic> entrada) {
    for (final p in parametros) {
      if (!p.obrigatorio) continue;
      final valor = entrada[p.nome];
      if (valor == null) return 'Parâmetro obrigatório ausente: ${p.nome}';
      if (valor is String && valor.trim().isEmpty) {
        return 'Parâmetro obrigatório vazio: ${p.nome}';
      }
    }
    return null;
  }
}
