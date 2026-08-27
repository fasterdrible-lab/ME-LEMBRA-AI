import '../../../services/profile_service.dart';
import '../models/molly_risk_level.dart';
import '../models/molly_tool_definition.dart';
import '../models/molly_tool_result.dart';

/// Ferramenta de perfil da MOLLY (TAREFA 3 do prompt mestre) — wrapper
/// fino sobre `ProfileService`.
class ProfileTool {
  static final MollyToolDefinition getUserProfile = MollyToolDefinition(
    nome: 'getUserProfile',
    descricao: 'Consulta o nome e o perfil (idoso, adulto, criança, família) do usuário atual.',
    risco: MollyRiskLevel.low,
    parametros: const [],
    executar: (_) async {
      final perfil = await ProfileService.getProfile();
      if (perfil == null) {
        return MollyToolResult.falha('Não consegui verificar seu perfil agora.', acao: 'getUserProfile');
      }
      final nome = await ProfileService.getNameForSelectedProfile();
      final nomeFrase =
          (nome != null && nome.trim().isNotEmpty) ? 'Seu nome é $nome' : 'Não encontrei um nome salvo';
      return MollyToolResult.sucesso(
        '$nomeFrase e seu perfil é $perfil.',
        acao: 'getUserProfile',
        dados: {'perfil': perfil, 'nome': nome},
      );
    },
  );
}
