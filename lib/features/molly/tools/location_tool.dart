import '../../../services/location_service.dart';
import '../models/molly_risk_level.dart';
import '../models/molly_tool_definition.dart';
import '../models/molly_tool_result.dart';

/// Ferramenta de localização da MOLLY (TAREFA 3 do prompt mestre) —
/// wrapper fino sobre `LocationService`.
class LocationTool {
  static final MollyToolDefinition getCurrentLocation = MollyToolDefinition(
    nome: 'getCurrentLocation',
    descricao: 'Obtém a localização atual do usuário (GPS), para responder algo como "onde estou".',
    // MEDIUM, não LOW: ao contrário de "consultar lembretes" (dado já
    // salvo no Firestore), isto aciona o GPS do aparelho na hora — mais
    // sensível que ler algo já armazenado. Uma futura ferramenta de
    // COMPARTILHAR localização com um terceiro deve ser CRITICAL (exemplo
    // explícito da TAREFA 4 do prompt mestre); esta aqui só lê e devolve
    // ao próprio usuário.
    risco: MollyRiskLevel.medium,
    parametros: const [],
    executar: (_) async {
      try {
        final pos = await LocationService.getCurrentPosition();
        return MollyToolResult.sucesso(
          'Encontrei sua localização atual.',
          acao: 'getCurrentLocation',
          dados: {'latitude': pos.latitude, 'longitude': pos.longitude},
        );
      } catch (_) {
        // Mesmo espírito de mensagem da TAREFA 11 do prompt mestre
        // (linguagem simples, sem termo técnico, oferece tentar de novo).
        return MollyToolResult.falha(
          'Não consegui ver sua localização agora. Quer tentar novamente?',
          acao: 'getCurrentLocation',
        );
      }
    },
  );
}
