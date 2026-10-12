import '../../../services/profile_service.dart';
import '../../../services/settings_service.dart';
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

  /// "Quem é meu contato de emergência?" (critério de aceitação, TAREFA 37
  /// do prompt mestre). Lê os números de `SettingsService` — locais, sem
  /// Firestore — então funciona sem internet (ver `OfflineIntentService`).
  static final MollyToolDefinition getEmergencyContacts = MollyToolDefinition(
    nome: 'getEmergencyContacts',
    descricao: 'Consulta os contatos de emergência (SOS) cadastrados e se o botão SOS está ligado.',
    risco: MollyRiskLevel.low,
    parametros: const [],
    executar: (_) async {
      final numeros = await SettingsService.getSosNumeros();
      final sosAtivo = await SettingsService.getSos();
      return MollyToolResult.sucesso(
        falaContatosEmergencia(numeros, sosAtivo: sosAtivo),
        acao: 'getEmergencyContacts',
        dados: {'numeros': numeros, 'sosAtivo': sosAtivo},
      );
    },
  );

  /// Monta a fala sobre os contatos de emergência — pura, testável sem
  /// SharedPreferences. Hoje os contatos SOS são só números (sem nome
  /// vinculado), então a fala usa o número. Com 2+, segue a regra de
  /// respostas curtas (TAREFA 12): diz quantos são e destaca só o primeiro,
  /// que é o chamado automaticamente no SOS.
  static String falaContatosEmergencia(List<String> numeros, {required bool sosAtivo}) {
    final validos = numeros.where((n) => n.replaceAll(RegExp(r'\D'), '').isNotEmpty).toList();
    final avisoSosDesligado =
        sosAtivo ? '' : ' Atenção: o botão SOS está desligado nas Configurações.';

    if (validos.isEmpty) {
      return 'Você ainda não cadastrou um contato de emergência. '
          'Dá para cadastrar em Configurações, no Botão de Pânico.$avisoSosDesligado';
    }
    final principal = numeroFalado(validos.first);
    if (validos.length == 1) {
      return 'Seu contato de emergência é o número $principal.$avisoSosDesligado';
    }
    return 'Você tem ${validos.length} contatos de emergência. '
        'O primeiro, que é chamado automaticamente no SOS, é o número $principal.'
        '$avisoSosDesligado';
  }

  /// Número de telefone em grupos de dígitos separados, pro TTS ler um
  /// dígito por vez ("9 8 7 6 5") em vez de "noventa e oito mil...".
  /// Ignora o +55 do Brasil, que não ajuda quem está ouvindo.
  static String numeroFalado(String numero) {
    var d = numero.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('55') && d.length >= 12) d = d.substring(2);
    String digitos(String s) => s.split('').join(' ');
    if (d.length == 11) {
      return '${digitos(d.substring(0, 2))}, ${digitos(d.substring(2, 7))}, ${digitos(d.substring(7))}';
    }
    if (d.length == 10) {
      return '${digitos(d.substring(0, 2))}, ${digitos(d.substring(2, 6))}, ${digitos(d.substring(6))}';
    }
    return digitos(d);
  }
}
