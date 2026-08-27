import '../../../models/reminder.dart';
import '../../../services/reminder_service.dart';
import '../../../services/sos_service.dart';
import '../models/molly_tool_result.dart';
import '../tools/molly_fala_utils.dart';
import 'molly_risk_policy.dart';

/// Os cinco comandos críticos reconhecidos localmente (TAREFA 17 do
/// prompt mestre) — um por exemplo dado na tarefa, na mesma ordem — mais
/// [possivelEmergencia] (TAREFA 18: frases de emergência mais suaves que
/// "SOCORRO", que pedem confirmação com contagem regressiva em vez de
/// disparo imediato).
enum OfflineIntent {
  socorro,
  possivelEmergencia,
  queHoras,
  meusLembretes,
  ligarPara,
  confirmarRemedio,
  nenhuma,
}

/// Comandos críticos que funcionam sem IA (TAREFA 17 do prompt mestre).
///
/// Fluxo pedido pela tarefa, seguido à risca: entrada → detecção local
/// ([classificar], puro, sem Firebase/IA) → intenção reconhecida? →
/// SIM: [tentar] executa localmente (devolve um `MollyToolResult`) →
/// NÃO: devolve `null`, e quem chama (`MollyAgentService.processar`)
/// tenta a IA. Isso garante que os cinco comandos abaixo funcionam mesmo
/// sem internet, com o backend de IA fora do ar, ou com a Groq fora do
/// catálogo de novo (já aconteceu duas vezes — sessões 19 e 21, ver
/// `docs/CURRENT_STATE.md`).
///
/// "SOCORRO" já tem um caminho MAIS RÁPIDO e independente disto: a
/// checagem ao vivo durante a escuta (`aoOuvirParcial` em
/// `molly_screen.dart`), que dispara o SOS antes mesmo do reconhecimento
/// final da fala chegar — continua sendo o caminho principal, e por isso
/// `_processarFala` nem chega a chamar [tentar] quando isso já
/// aconteceu. A checagem aqui, sobre a transcrição final, é uma segunda
/// camada de segurança pra qualquer chamador que não faça aquela
/// checagem ao vivo (ex.: texto digitado, ou um controller futuro
/// diferente) — e, como todo o resto desta classe, nunca depende da IA.
///
/// TAREFA 18 (SOS por voz): frases mais suaves de possível emergência
/// ("me ajuda", "chama minha filha", "chama alguém", "estou passando
/// mal", "preciso de ajuda") são tratadas DIFERENTE de "SOCORRO" — nunca
/// disparam o SOS na hora. [tentar] devolve
/// `MollyToolResult.possivelEmergencia`, sinalizando que quem chama
/// precisa mostrar uma confirmação visual com contagem regressiva
/// cancelável (`SettingsService.getSosCountdownSegundos`, mesmo padrão
/// do botão SOS manual) antes de qualquer disparo — o LLM nunca decide
/// isso sozinho, e o disparo técnico em si sempre passa por
/// `SosService.trigger()`, nunca por esta classe diretamente nesse caso.
///
/// Cada intenção reconhecida delega a um serviço/ferramenta já existente
/// (`SosService`, `ReminderService`, `MollyRiskPolicy`) — esta classe só
/// detecta e direciona, nunca acessa Firestore diretamente.
class OfflineIntentService {
  /// Classifica [texto] SEM executar nada — puro e testável sem
  /// Firebase/IA. Separado de [tentar] de propósito, pra que a detecção
  /// em si (o que a TAREFA 17 realmente pede) tenha teste automatizado
  /// sem precisar mockar Firestore/FirebaseAuth.
  static OfflineIntent classificar(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return OfflineIntent.nenhuma;
    final tLower = t.toLowerCase();

    if (t.toUpperCase().contains('SOCORRO')) return OfflineIntent.socorro;
    if (_pareceEmergenciaSuave(tLower)) return OfflineIntent.possivelEmergencia;
    if (_ehQueHoras(tLower)) return OfflineIntent.queHoras;
    if (_ehMeusLembretes(tLower)) return OfflineIntent.meusLembretes;
    if (_extrairLigarPara(tLower) != null) return OfflineIntent.ligarPara;
    if (_ehConfirmarRemedio(tLower)) return OfflineIntent.confirmarRemedio;
    return OfflineIntent.nenhuma;
  }

  /// Tenta reconhecer e executar [texto] como um comando crítico local.
  /// Devolve `null` se [classificar] não reconheceu nada — quem chama
  /// deve então tentar a IA.
  static Future<MollyToolResult?> tentar(String texto) async {
    switch (classificar(texto)) {
      case OfflineIntent.socorro:
        return _acionarSocorro();
      case OfflineIntent.possivelEmergencia:
        return MollyToolResult.possivelEmergencia(texto.trim());
      case OfflineIntent.queHoras:
        return _falarHoras();
      case OfflineIntent.meusLembretes:
        return MollyRiskPolicy.executar('getTodayReminders', const {});
      case OfflineIntent.ligarPara:
        final nome = _extrairLigarPara(texto.trim().toLowerCase())!;
        return MollyRiskPolicy.executar('callFamilyMember', {'nomeFamiliar': nome});
      case OfflineIntent.confirmarRemedio:
        return _confirmarRemedio();
      case OfflineIntent.nenhuma:
        return null;
    }
  }

  static Future<MollyToolResult> _acionarSocorro() async {
    await SosService.trigger(motivo: 'voz');
    return MollyToolResult.sucesso('Acionando o SOS.', acao: 'socorro');
  }

  /// As cinco frases de exemplo da TAREFA 18 (menos "socorro", que já
  /// tem checagem própria acima) — sinais mais suaves de que o usuário
  /// pode precisar de ajuda, mas não o gatilho explícito e inequívoco.
  static const List<String> _fasesEmergenciaSuave = [
    'me ajuda',
    'chama minha filha',
    'chama alguém',
    'chama alguem',
    'estou passando mal',
    'preciso de ajuda',
  ];

  static bool _pareceEmergenciaSuave(String t) => _fasesEmergenciaSuave.any(t.contains);

  static bool _ehQueHoras(String t) =>
      t.contains('que horas') || t.contains('que hora é') || t.contains('horas são');

  static MollyToolResult _falarHoras() {
    return MollyToolResult.sucesso('Agora são ${horaFalada(DateTime.now())}.', acao: 'que_horas');
  }

  static bool _ehMeusLembretes(String t) =>
      t.contains('meus lembretes') || t.contains('lembretes de hoje');

  /// Extrai o nome depois de "ligar para"/"liga pra" — só quando a frase
  /// começa exatamente assim (depois de tirar um "Molly," inicial), pra
  /// não atropelar um pedido de lembrete disfarçado de ligação (ex.:
  /// "não deixa eu esquecer de ligar pro médico às 8" é lembrete, não
  /// uma chamada agora — por isso a checagem de dígito/hora/"lembr"
  /// abaixo).
  static String? _extrairLigarPara(String tLower) {
    final semEndereco = tLower.replaceFirst(RegExp(r'^molly,?\s*'), '').trim();
    final match = RegExp(r'^liga(?:r)?\s+(?:pra|para)\s+(.+?)\.?$').firstMatch(semEndereco);
    if (match == null) return null;
    final nome = match.group(1)!.trim();
    if (nome.isEmpty) return null;
    if (RegExp(r'\d|hora|amanh|lembr').hasMatch(nome)) return null;
    return nome;
  }

  static bool _ehConfirmarRemedio(String t) =>
      (t.contains('confirmar') || t.contains('confirma')) &&
      (t.contains('remédio') || t.contains('remedio') || t.contains('medicamento'));

  /// Confirma o remédio de hoje mais relevante. Se houver mais de um
  /// candidato (mais de um remédio ainda não confirmado hoje), é
  /// ambíguo qual confirmar — pede confirmação em vez de adivinhar
  /// (TAREFA 4: `ambiguo: true` faz uma ferramenta MEDIUM confirmar).
  static Future<MollyToolResult> _confirmarRemedio() async {
    List<Reminder> candidatos;
    try {
      final todos = await ReminderService.getAll();
      final agora = DateTime.now();
      candidatos = todos
          .where((r) =>
              (r.type == 'Remedio' || r.type == 'Tomar') &&
              !r.confirmed &&
              r.dateTime.year == agora.year &&
              r.dateTime.month == agora.month &&
              r.dateTime.day == agora.day)
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    } catch (_) {
      candidatos = const [];
    }

    if (candidatos.isEmpty) {
      return MollyToolResult.falha(
        'Não encontrei nenhum remédio pra confirmar hoje.',
        acao: 'confirmReminder',
      );
    }
    return MollyRiskPolicy.executar(
      'confirmReminder',
      {'id': candidatos.first.id},
      ambiguo: candidatos.length > 1,
    );
  }
}
