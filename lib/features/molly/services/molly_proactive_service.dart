import '../../../models/reminder.dart';
import '../../../services/reminder_service.dart';
import '../tools/molly_fala_utils.dart';

/// Proatividade da MOLLY (Fase 8 do prompt mestre, `docs/MOLLY_ARCHITECTURE_ANALYSIS.md`).
///
/// Reaproveita `ReminderService.getAll()` já existente — nenhuma consulta
/// nova ao Firestore, nenhum serviço nativo/segundo plano novo (isso já é
/// resolvido, com bem mais esforço, pelo Foreground Service do detector de
/// queda — ver `SosProtectionService.kt`, sessão 22). Aqui a proatividade
/// acontece só quando o usuário já abriu a MOLLY (tela cheia ou atalho
/// rápido) — não é um alarme em segundo prazo, é "antes de você perguntar
/// qualquer coisa, eu já reparei nisso".
class MollyProactiveService {
  /// Só considera "atrasado" depois desse tempo sem confirmação — um
  /// remédio 5 minutos atrasado não precisa de alarde, só ansiedade à toa.
  static const Duration atrasoMinimo = Duration(minutes: 30);

  /// Verifica remédios de hoje (tipo `Remedio`/`Tomar`) não confirmados e
  /// com o horário já passado há mais de [atrasoMinimo] — devolve uma fala
  /// pronta pra avisar sem que o usuário precise perguntar, ou `null` se
  /// não há nada atrasado (ou a consulta falhar — proatividade nunca deve
  /// travar a abertura da tela). Busca a lista real (`ReminderService`,
  /// que toca `FirebaseAuth`) e delega a decisão para [gerarAviso], que é
  /// pura — mesmo padrão de `MollyBriefingService.gerar()`/`gerarDeLista()`
  /// pra deixar a lógica de verdade testável sem mock de Firebase.
  static Future<String?> verificarRemedioAtrasado({DateTime? agora}) async {
    List<Reminder> todos;
    try {
      todos = await ReminderService.getAll();
    } catch (_) {
      return null;
    }
    return gerarAviso(todos, agora: agora);
  }

  /// Versão pura de [verificarRemedioAtrasado] — recebe a lista já pronta,
  /// nunca toca Firebase/Firestore. 100% testável.
  static String? gerarAviso(List<Reminder> todos, {DateTime? agora}) {
    final ref = agora ?? DateTime.now();
    final atrasados = todos.where((r) {
      if (r.type != 'Remedio' && r.type != 'Tomar') return false;
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
    if (atrasados.length == 1) {
      return 'Notei que você ainda não confirmou $nome, das ${horaFalada(primeiro.dateTime)}. Já tomou?';
    }
    return 'Notei que você tem ${atrasados.length} remédios sem confirmar hoje. '
        'O mais antigo é $nome, das ${horaFalada(primeiro.dateTime)}. Já tomou?';
  }
}
