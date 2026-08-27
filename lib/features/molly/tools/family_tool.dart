import '../../../models/family_member.dart';
import '../../../services/chat_service.dart';
import '../../../services/family_service.dart';
import '../../../services/profile_service.dart';
import '../models/molly_risk_level.dart';
import '../models/molly_tool_definition.dart';
import '../models/molly_tool_result.dart';

/// Ferramentas de família da MOLLY (TAREFA 3 do prompt mestre) — wrappers
/// finos sobre `FamilyService`/`ChatService`, nenhuma chamada nova ao
/// Firestore.
class FamilyTool {
  static final MollyToolDefinition getFamilyMembers = MollyToolDefinition(
    nome: 'getFamilyMembers',
    descricao: 'Lista os familiares vinculados ao usuário.',
    risco: MollyRiskLevel.low,
    parametros: const [],
    executar: (_) async {
      final membros = await FamilyService.stream().first;
      if (membros.isEmpty) {
        return MollyToolResult.sucesso(
          'Você ainda não tem nenhum familiar vinculado.',
          acao: 'getFamilyMembers',
        );
      }
      final nomes = membros.map((m) => m.nome).toList();
      final frase = nomes.length == 1
          ? '${nomes.first} está vinculado à sua conta.'
          : '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last} estão vinculados à sua conta.';
      return MollyToolResult.sucesso(frase, acao: 'getFamilyMembers', dados: {'familiares': membros});
    },
  );

  static const MollyToolDefinition sendFamilyMessage = MollyToolDefinition(
    nome: 'sendFamilyMessage',
    descricao: 'Envia uma mensagem de texto a um familiar vinculado, pelo chat familiar.',
    risco: MollyRiskLevel.medium,
    parametros: [
      MollyToolParam(nome: 'nomeFamiliar', tipo: 'string', descricao: 'Nome do familiar destinatário.'),
      MollyToolParam(nome: 'mensagem', tipo: 'string', descricao: 'Texto da mensagem.'),
    ],
    executar: _sendFamilyMessage,
  );

  static Future<MollyToolResult> _sendFamilyMessage(Map<String, dynamic> p) async {
    final nomeFamiliar = (p['nomeFamiliar'] as String).trim();
    final mensagem = (p['mensagem'] as String).trim();
    final membro = await _encontrarFamiliarPorNome(nomeFamiliar);
    if (membro == null) {
      return MollyToolResult.falha('Não encontrei um familiar chamado $nomeFamiliar.', acao: 'sendFamilyMessage');
    }
    try {
      await ChatService.send(membro.uid, mensagem);
      return MollyToolResult.sucesso('Mensagem enviada para ${membro.nome}.', acao: 'sendFamilyMessage');
    } catch (_) {
      return MollyToolResult.falha('Não consegui enviar a mensagem agora.', acao: 'sendFamilyMessage');
    }
  }

  /// "Ligar" para um familiar. O app hoje não guarda telefone por
  /// familiar — só o(s) número(s) de SOS genéricos, sem vínculo com uma
  /// conta específica (gap documentado em
  /// `docs/MOLLY_ARCHITECTURE_ANALYSIS.md`, item 3 dos riscos). Por isso
  /// esta ferramenta não disca de verdade: avisa o familiar pelo chat para
  /// que ele ligue de volta. Continua CRITICAL (mesma categoria de
  /// "chamada telefônica" da TAREFA 4) porque, da perspectiva do usuário,
  /// a intenção é a mesma — sempre confirmar antes de executar.
  static const MollyToolDefinition callFamilyMember = MollyToolDefinition(
    nome: 'callFamilyMember',
    descricao: 'Avisa um familiar vinculado, pelo chat, para que ele ligue de volta.',
    risco: MollyRiskLevel.critical,
    parametros: [
      MollyToolParam(nome: 'nomeFamiliar', tipo: 'string', descricao: 'Nome do familiar a avisar.'),
    ],
    executar: _callFamilyMember,
  );

  static Future<MollyToolResult> _callFamilyMember(Map<String, dynamic> p) async {
    final nomeFamiliar = (p['nomeFamiliar'] as String).trim();
    final membro = await _encontrarFamiliarPorNome(nomeFamiliar);
    if (membro == null) {
      return MollyToolResult.falha('Não encontrei um familiar chamado $nomeFamiliar.', acao: 'callFamilyMember');
    }
    try {
      final meuNome = await ProfileService.getNameForSelectedProfile() ?? 'Familiar';
      await ChatService.send(membro.uid, '📞 $meuNome pediu para você ligar para ele(a).');
      return MollyToolResult.sucesso('Avisei ${membro.nome} para te ligar.', acao: 'callFamilyMember');
    } catch (_) {
      return MollyToolResult.falha('Não consegui avisar ${membro.nome} agora.', acao: 'callFamilyMember');
    }
  }

  static Future<FamilyMember?> _encontrarFamiliarPorNome(String nome) async {
    final membros = await FamilyService.stream().first;
    final alvo = nome.trim().toLowerCase();
    if (alvo.isEmpty) return null;
    for (final m in membros) {
      if (m.nome.trim().toLowerCase() == alvo) return m;
    }
    // Correspondência parcial (ex.: "Ana" bate com "Ana Paula").
    for (final m in membros) {
      final nomeMembro = m.nome.trim().toLowerCase();
      if (nomeMembro.contains(alvo) || alvo.contains(nomeMembro)) return m;
    }
    return null;
  }
}
