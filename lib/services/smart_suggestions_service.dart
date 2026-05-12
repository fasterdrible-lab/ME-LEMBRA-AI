import '../models/reminder.dart';
import 'reminder_service.dart';

/// Sugestão de lembrete inferida do histórico do usuário.
class ReminderSuggestion {
  final String title;
  final String type;
  final int hour;
  final int minute;
  final String repeat; // 'diario' | 'semanal' | 'unico'
  final String reason;

  const ReminderSuggestion({
    required this.title,
    required this.type,
    required this.hour,
    required this.minute,
    required this.repeat,
    required this.reason,
  });
}

/// Heurísticas simples para sugerir novos lembretes a partir do histórico.
///
/// Estratégia (sem ML, totalmente local):
/// - Agrupa lembretes por (titulo+tipo) e analisa frequência.
/// - Se 3+ ocorrências no mesmo horário (±15 min), sugere recorrência diária.
/// - Se ocorrem semanalmente no mesmo dia da semana e horário, sugere semanal.
/// - Filtra sugestões que já existem como lembrete recorrente ativo.
class SmartSuggestionsService {
  static Future<List<ReminderSuggestion>> generate() async {
    final all = await ReminderService.getAll();
    if (all.length < 3) return const [];

    final now = DateTime.now();
    final last60 = all.where(
      (r) => r.dateTime.isAfter(now.subtract(const Duration(days: 60))),
    );

    final groups = <String, List<Reminder>>{};
    for (final r in last60) {
      final key = '${r.type}|${r.title.trim().toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(r);
    }

    final existingRecurring = all
        .where((r) => r.repeat == 'diario' || r.repeat == 'semanal')
        .map((r) => '${r.type}|${r.title.trim().toLowerCase()}')
        .toSet();

    final suggestions = <ReminderSuggestion>[];
    for (final entry in groups.entries) {
      if (existingRecurring.contains(entry.key)) continue;
      final list = entry.value;
      if (list.length < 3) continue;

      // Tipicamente o mesmo horário?
      final sortedByMinuteOfDay = [...list]
        ..sort((a, b) => _minuteOfDay(a.dateTime).compareTo(_minuteOfDay(b.dateTime)));
      final mid = sortedByMinuteOfDay[sortedByMinuteOfDay.length ~/ 2];
      final medianMinute = _minuteOfDay(mid.dateTime);
      final allSameTime = list.every(
        (r) => (_minuteOfDay(r.dateTime) - medianMinute).abs() <= 15,
      );
      if (!allSameTime) continue;

      // Mesmo dia da semana?
      final weekdays = list.map((r) => r.dateTime.weekday).toSet();
      final repeat = weekdays.length == 1 ? 'semanal' : 'diario';

      final sample = list.first;
      suggestions.add(ReminderSuggestion(
        title: sample.title,
        type: sample.type,
        hour: mid.dateTime.hour,
        minute: mid.dateTime.minute,
        repeat: repeat,
        reason: repeat == 'diario'
            ? 'Você costuma agendar "${sample.title}" todos os dias por volta dessa hora.'
            : 'Você costuma agendar "${sample.title}" semanalmente.',
      ));
    }
    return suggestions;
  }

  static int _minuteOfDay(DateTime d) => d.hour * 60 + d.minute;
}
