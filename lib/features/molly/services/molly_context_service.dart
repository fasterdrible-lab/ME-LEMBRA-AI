import '../../../models/reminder.dart';
import '../../../services/family_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/reminder_service.dart';
import '../../../services/settings_service.dart';
import '../memory/long_term_memory.dart';
import '../memory/short_term_memory.dart';
import '../models/molly_user_context.dart';

/// Monta o contexto do usuário que a MOLLY tem permissão de conhecer
/// (TAREFA 10 do prompt mestre) — nome, perfil, próximos lembretes,
/// histórico recente, familiares, configurações relevantes, horário
/// atual, preferências e o estado da conversa atual.
///
/// Regra central da tarefa: **nunca enviar todo o Firestore ao modelo**.
/// Esta classe só junta resumos já pequenos de serviços que já existem
/// (`ReminderService`, `FamilyService`, `ProfileService`,
/// `LongTermMemoryService`) — nunca lê nem expõe um documento completo. A
/// parte efetivamente mandada ao backend de IA hoje continua sendo só
/// `MollyUserContext.lembretesParaIA` (o contrato de
/// `AiCommandService.interpretar` não muda nesta tarefa); o restante fica
/// disponível para outros consumidores dentro do app — ver docstring de
/// [MollyUserContext].
///
/// Substitui `MollyAgentService.contextoPadraoDeLembretes()` (TAREFA 2),
/// que ficava restrito só aos lembretes — a mesma lógica agora vive aqui,
/// como uma peça de um contexto maior.
class MollyContextService {
  static Future<MollyUserContext> montar({ShortTermMemory? memoria}) async {
    final perfil = await ProfileService.getProfile();
    final nome = await ProfileService.getNameForSelectedProfile();

    final agora = DateTime.now();
    final todosLembretes = await _lembretesSeguro();

    final sosAtivo = await SettingsService.getSos();
    final chatAtivo = await SettingsService.getChat();
    final notificacoesAtivas = await SettingsService.getNotificacoes();

    final memoriaAutorizada = await SettingsService.getMollyMemoriaAutorizada();
    final preferencias = memoriaAutorizada ? await _preferenciasSeguro() : const <Map<String, dynamic>>[];

    return MollyUserContext(
      nome: nome,
      perfil: perfil,
      agora: agora,
      proximosLembretes: _proximosLembretes(todosLembretes, agora),
      historicoRecente: _historicoRecente(todosLembretes, agora),
      familiares: await _familiaresSeguro(),
      preferencias: preferencias,
      sosAtivo: sosAtivo,
      chatAtivo: chatAtivo,
      notificacoesAtivas: notificacoesAtivas,
      conversaTurnos: memoria?.turnos ?? 0,
      conversaColetandoLembrete: memoria?.coletandoLembrete ?? false,
    );
  }

  static Future<List<Reminder>> _lembretesSeguro() async {
    try {
      return await ReminderService.getAll();
    } catch (_) {
      return const [];
    }
  }

  /// Lembretes de ontem em diante, resumidos — mesma janela e formato que
  /// `_lembretesParaContextoIA` já usa em `elderly_screen.dart`, pra dar
  /// grounding real contra alucinação sem mandar o documento inteiro.
  static List<Map<String, dynamic>> _proximosLembretes(List<Reminder> todos, DateTime agora) {
    final relevantes = todos
        .where((r) => r.dateTime.isAfter(agora.subtract(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return relevantes
        .take(15)
        .map((r) => {
              'titulo': r.title.isNotEmpty ? r.title : r.type,
              'tipo': r.type,
              'data_hora': r.dateTime.toIso8601String(),
              if (r.type == 'Compras' && r.description.trim().isNotEmpty)
                'itens': r.description.trim().split('\n'),
            })
        .toList();
  }

  /// Lembretes confirmados nos últimos [dias] dias — mesmo filtro de
  /// `ReminderTool.getReminderHistory`, mas devolvendo dados estruturados
  /// em vez de uma fala pronta (propósitos diferentes: aqui é contexto
  /// interno, lá é resposta ao usuário).
  static List<Map<String, dynamic>> _historicoRecente(
    List<Reminder> todos,
    DateTime agora, {
    int dias = 30,
  }) {
    final limite = agora.subtract(Duration(days: dias));
    final confirmados = todos.where((r) => r.confirmed && r.dateTime.isAfter(limite)).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return confirmados
        .take(15)
        .map((r) => {
              'titulo': r.title.isNotEmpty ? r.title : r.type,
              'tipo': r.type,
              'data_hora': r.dateTime.toIso8601String(),
            })
        .toList();
  }

  static Future<List<String>> _familiaresSeguro() async {
    try {
      final membros = await FamilyService.stream().first;
      return membros.map((m) => m.nome).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Map<String, dynamic>>> _preferenciasSeguro() async {
    try {
      final memorias = await LongTermMemoryService.getAll();
      return memorias.map((m) => {'type': m.type, 'value': m.value}).toList();
    } catch (_) {
      return const [];
    }
  }
}
