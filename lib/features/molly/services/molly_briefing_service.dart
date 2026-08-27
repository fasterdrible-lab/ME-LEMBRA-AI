import '../../../models/reminder.dart';
import '../../../services/reminder_service.dart';
import '../tools/molly_fala_utils.dart';

/// Briefing matinal inteligente da MOLLY (TAREFA 13 do prompt mestre).
///
/// Evolui o resumo matinal que já existia
/// (`NotificationService.scheduleMorningBriefing()`), que hoje é só uma
/// notificação Android genérica e fixa ("Confira seus lembretes de
/// hoje") — sem os lembretes de verdade. Esta classe monta o texto real,
/// com os lembretes do dia, no formato do exemplo literal do prompt
/// mestre: saudação, contagem, até dois destaques nomeados por tipo
/// ("Seu remédio"/"Sua consulta"), e uma pergunta de fechamento
/// oferecendo mais detalhe — sem nunca recitar a lista inteira quando há
/// muitos lembretes (mesma disciplina de respostas curtas da TAREFA 12).
///
/// Contexto opcional citado no prompt mestre para o futuro — previsão do
/// tempo, aniversários, mensagens familiares — **não está incluído
/// ainda**; esta versão usa só os lembretes do dia, a única fonte de
/// dado real e já confiável disponível hoje.
class MollyBriefingService {
  static const Map<String, String> _sujeitoPorTipo = {
    'Remedio': 'Seu remédio',
    'Consulta': 'Sua consulta',
    'Aniversario': 'Seu aniversário',
    'Reuniao': 'Sua reunião',
  };

  /// Monta o briefing de hoje, buscando os lembretes reais do usuário.
  static Future<String> gerar() async {
    return gerarDeLista(await _lembretesDeHoje());
  }

  /// Monta o texto do briefing a partir de uma lista já filtrada —
  /// separado de [gerar] para ser testável sem depender do
  /// Firestore/FirebaseAuth (só recebe dados já prontos).
  static String gerarDeLista(List<Reminder> lembretesDeHoje) {
    if (lembretesDeHoje.isEmpty) {
      return 'Bom dia. Você não tem lembretes hoje.';
    }
    final qtd = lembretesDeHoje.length;
    final contagem = qtd == 1 ? 'Você tem 1 lembrete hoje.' : 'Você tem $qtd lembretes hoje.';
    final destaques = lembretesDeHoje.take(2).map(_fraseItem).join(' ');
    return 'Bom dia. $contagem $destaques Quer que eu leia tudo?';
  }

  static String _fraseItem(Reminder r) {
    final sujeito = _sujeitoPorTipo[r.type] ?? (r.title.isNotEmpty ? r.title : r.type);
    return '$sujeito é às ${horaFalada(r.dateTime)}.';
  }

  static Future<List<Reminder>> _lembretesDeHoje() async {
    try {
      final agora = DateTime.now();
      final todos = await ReminderService.getAll();
      return todos
          .where((r) =>
              r.dateTime.year == agora.year &&
              r.dateTime.month == agora.month &&
              r.dateTime.day == agora.day)
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    } catch (_) {
      return const [];
    }
  }
}
