import '../../../models/reminder.dart';
import 'molly_cache_service.dart';
import '../models/molly_tool_result.dart';
import '../tools/molly_fala_utils.dart';

/// Camada específica de medicamentos (TAREFA 21 do prompt mestre).
///
/// O que a MOLLY PODE fazer com remédio: lembrar horários (lembretes
/// normais), confirmar uso ("confirmar remédio", `OfflineIntentService`),
/// e — o que esta classe acrescenta — mostrar o histórico do dia ("Já
/// tomei meu remédio hoje?"). O que ela NUNCA faz (indicar, dosar,
/// alterar, diagnosticar) mora em `MollySafetyService`.
///
/// Só olha os registros do próprio app (lembretes tipo Remedio/Tomar e se
/// foram confirmados) — nunca afirma que a pessoa tomou ou não tomou de
/// fato, só o que foi marcado.
class MollyMedicationService {
  /// "já tomei meu remédio (hoje)?", "tomei o remédio?", "quais remédios
  /// eu já tomei", "falta tomar algum remédio?", "histórico do remédio".
  static bool ehPerguntaRemediosDeHoje(String texto) {
    final t = texto.toLowerCase();
    final falaDeRemedio = t.contains('remédio') ||
        t.contains('remedio') ||
        t.contains('medicamento') ||
        t.contains('medicação') ||
        t.contains('medicacao');
    if (!falaDeRemedio) return false;
    final ehPergunta = t.contains('já tomei') ||
        t.contains('ja tomei') ||
        // "?" só aparece em texto digitado — o STT não pontua. "Eu tomei
        // meu remédio" sem "já"/"?" é afirmação (vai pra IA/confirmar).
        RegExp(r'\btomei\b.*\?').hasMatch(t) ||
        t.contains('falta tomar') ||
        t.contains('faltam tomar') ||
        t.contains('histórico') ||
        t.contains('historico');
    return ehPergunta;
  }

  static Future<MollyToolResult> responderRemediosDeHoje() async {
    List<Reminder> todos;
    try {
      todos = await MollyCache.lembretes();
    } catch (_) {
      return MollyToolResult.falha(
        'Não consegui ver seus remédios agora.',
        acao: 'historicoRemedio',
      );
    }
    return MollyToolResult.sucesso(
      falaRemediosDeHoje(todos, DateTime.now()),
      acao: 'historicoRemedio',
    );
  }

  /// Pura e testável. Resume os remédios de hoje: quantos foram marcados
  /// como tomados e qual é o próximo/pendente (respostas curtas, TAREFA 12).
  static String falaRemediosDeHoje(List<Reminder> todos, DateTime agora) {
    // Sessão 26: ocorreEm/confirmadoEm — inclui remédio diário criado em
    // outro dia, e "tomado" é só o que foi confirmado HOJE.
    final hoje = todos.where((r) => _ehRemedio(r.type) && r.ocorreEm(agora)).toList()
      ..sort((a, b) => a.horarioEm(agora).compareTo(b.horarioEm(agora)));

    if (hoje.isEmpty) {
      return 'Não encontrei nenhum remédio marcado para hoje.';
    }
    final tomados = hoje.where((r) => r.confirmadoEm(agora)).toList();
    final pendentes = hoje.where((r) => !r.confirmadoEm(agora)).toList();

    if (pendentes.isEmpty) {
      return hoje.length == 1
          ? 'Sim. Seu remédio das ${horaFalada(hoje.first.horarioEm(agora))} já foi marcado como tomado.'
          : 'Sim. Os ${hoje.length} remédios de hoje já foram marcados como tomados.';
    }

    final proximo = pendentes.first;
    final horario = proximo.horarioEm(agora);
    final atrasado = horario.isBefore(agora);
    final pendenteFrase = atrasado
        ? 'O das ${horaFalada(horario)} ainda não foi marcado como tomado.'
        : 'O próximo é às ${horaFalada(horario)}.';

    if (tomados.isEmpty) {
      final qtd = hoje.length == 1 ? 'Você tem 1 remédio hoje' : 'Você tem ${hoje.length} remédios hoje';
      return '$qtd, e nenhum foi marcado como tomado ainda. $pendenteFrase';
    }
    final tomadosFrase = tomados.length == 1
        ? 'Você já marcou 1 remédio como tomado hoje.'
        : 'Você já marcou ${tomados.length} remédios como tomados hoje.';
    return '$tomadosFrase $pendenteFrase';
  }

  static bool _ehRemedio(String tipo) =>
      tipo == 'Remedio' || tipo == 'Remédio' || tipo == 'Tomar';
}
