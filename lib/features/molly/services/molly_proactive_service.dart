import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/reminder.dart';
import '../../../services/notification_service.dart';
import '../../../services/reminder_service.dart';
import '../tools/molly_fala_utils.dart';

/// Um remédio atrasado e a pergunta pronta pra fazer sobre ele.
class AvisoRemedio {
  final Reminder lembrete;
  final String pergunta;
  const AvisoRemedio(this.lembrete, this.pergunta);
}

/// Resposta do usuário a "Você conseguiu tomar seu remédio?" ou a "Quer
/// que eu lembre novamente?".
enum RespostaSimNao { sim, nao, outra }

/// Proatividade da MOLLY (TAREFA 23 do prompt mestre / Fase 8).
///
/// Fluxo da tarefa: remédio atrasado → depois de 15 minutos, "Você
/// conseguiu tomar seu remédio?" → se não, "Quer que eu lembre
/// novamente?". Acontece em dois lugares:
/// 1. Ao abrir a Molly (`MollyAssistantPanel._aoAbrir`), via
///    [verificarRemedioAtrasado].
/// 2. Sem abrir nada: a notificação de acompanhamento agendada 15 min
///    depois de cada lembrete de remédio (`NotificationService`, payload
///    `molly_remedio`) — tocar nela abre a Molly, que cai no item 1.
///
/// Sem notificações excessivas: no máximo [maxRelembretesPorDia] "lembra de
/// novo" por remédio por dia, e tudo desliga em "Avisos da Molly"
/// (Configurações da Molly).
class MollyProactiveService {
  static const Duration atrasoMinimo = Duration(minutes: 15);
  static const Duration intervaloRelembrar = Duration(minutes: 15);
  static const int maxRelembretesPorDia = 2;

  /// Busca a lista real e delega a [gerarAviso] (pura). Nunca lança —
  /// proatividade não pode travar a abertura da Molly.
  static Future<AvisoRemedio?> verificarRemedioAtrasado({DateTime? agora}) async {
    List<Reminder> todos;
    try {
      todos = await ReminderService.getAll();
    } catch (_) {
      return null;
    }
    return gerarAviso(todos, agora: agora);
  }

  /// Remédio de hoje (Remedio/Tomar), não confirmado, atrasado há pelo
  /// menos [atrasoMinimo]. Pura, testável.
  static AvisoRemedio? gerarAviso(List<Reminder> todos, {DateTime? agora}) {
    final ref = agora ?? DateTime.now();
    final atrasados = todos.where((r) {
      if (r.type != 'Remedio' && r.type != 'Remédio' && r.type != 'Tomar') return false;
      if (r.confirmed) return false;
      if (r.dateTime.year != ref.year || r.dateTime.month != ref.month || r.dateTime.day != ref.day) {
        return false;
      }
      return ref.difference(r.dateTime) >= atrasoMinimo;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (atrasados.isEmpty) return null;

    final primeiro = atrasados.first;
    final nome = primeiro.title.trim().isNotEmpty ? primeiro.title.trim() : 'seu remédio';
    final hora = horaFalada(primeiro.dateTime);
    final pergunta = atrasados.length == 1
        ? 'Você conseguiu tomar $nome, das $hora?'
        : 'Você tem ${atrasados.length} remédios sem confirmar hoje. Conseguiu tomar $nome, das $hora?';
    return AvisoRemedio(primeiro, pergunta);
  }

  /// "sim", "tomei", "já tomei" → sim; "não", "ainda não", "esqueci" →
  /// não; qualquer outra coisa → outra (quem chama trata como um pedido
  /// normal pra Molly). Por palavra inteira e com o "não" primeiro — "não
  /// tomei" não pode virar sim, nem "assim" conter "sim".
  static RespostaSimNao classificarResposta(String texto) {
    final palavras = _normalizar(texto).split(RegExp(r'[^a-z]+')).where((p) => p.isNotEmpty).toList();
    if (palavras.isEmpty) return RespostaSimNao.outra;
    const negativas = {'nao', 'esqueci', 'nunca', 'negativo'};
    const positivas = {'sim', 'tomei', 'claro', 'pode', 'quero', 'uhum', 'isso', 'lembra', 'lembre', 'confirmo'};
    if (palavras.any(negativas.contains)) return RespostaSimNao.nao;
    if (palavras.any(positivas.contains)) return RespostaSimNao.sim;
    return RespostaSimNao.outra;
  }

  /// Agenda um "lembra de novo" daqui a [intervaloRelembrar], respeitando
  /// [maxRelembretesPorDia]. Devolve a hora agendada, ou `null` se o
  /// limite do dia já foi atingido.
  static Future<DateTime?> lembrarDeNovo(Reminder r, {DateTime? agora}) async {
    final ref = agora ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final chave = 'molly_relembrar_${r.id}_${ref.year}${ref.month}${ref.day}';
    final feitos = prefs.getInt(chave) ?? 0;
    if (feitos >= maxRelembretesPorDia) return null;

    final quando = ref.add(intervaloRelembrar);
    await NotificationService.scheduleReminder(
      id: NotificationService.idRelembrar(r.id, feitos),
      title: 'Hora do remédio',
      body: r.title.trim().isNotEmpty ? r.title.trim() : 'Seu remédio',
      scheduledDate: quando,
      acompanharRemedio: false,
    );
    await prefs.setInt(chave, feitos + 1);
    return quando;
  }

  static String _normalizar(String s) {
    const de = 'áàâãéêíóôõúç';
    const para = 'aaaaeeiooouc';
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = de.indexOf(ch);
      buf.write(i == -1 ? ch : para[i]);
    }
    return buf.toString();
  }
}
