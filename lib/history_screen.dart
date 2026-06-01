import 'package:flutter/material.dart';
import 'services/reminder_service.dart';
import 'models/reminder.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const Color _primary = Color(0xFF7B5EA7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historico de Aderencia'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<Reminder>>(
        stream: ReminderService.stream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          final todayReminders = all.where((r) => _occursOn(r, today)).toList();
          final confirmed = todayReminders.where((r) => r.confirmed).length;
          final total = todayReminders.length;

          final pastDays = List.generate(29, (i) {
            final d = now.subtract(Duration(days: i + 1));
            return DateTime(d.year, d.month, d.day);
          });

          final pastCards = pastDays
              .map((day) => _dayCard(context, day, all))
              .where((w) => w != null)
              .cast<Widget>()
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _todayBanner(confirmed, total),
              const SizedBox(height: 16),
              if (todayReminders.isNotEmpty) ...[
                _sectionLabel('LEMBRETES DE HOJE'),
                const SizedBox(height: 6),
                ...todayReminders.map((r) => _reminderTile(context, r)),
                const SizedBox(height: 12),
              ],
              if (pastCards.isNotEmpty) ...[
                _sectionLabel('ULTIMOS 29 DIAS'),
                const SizedBox(height: 6),
                ...pastCards,
              ],
            ],
          );
        },
      ),
    );
  }

  // Verifica se um lembrete ocorre num determinado dia
  bool _occursOn(Reminder r, DateTime day) {
    final rd = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
    if (r.repeat == 'unico') return rd == day;
    if (r.repeat == 'diario') return !rd.isAfter(day);
    if (r.repeat == 'semanal') {
      return !rd.isAfter(day) && r.dateTime.weekday == day.weekday;
    }
    return false;
  }

  // Banner de destaque com resumo de hoje
  Widget _todayBanner(int confirmed, int total) {
    final pct = total == 0 ? 0.0 : confirmed / total;

    String message;
    if (total == 0) {
      message = 'Nenhum lembrete agendado';
    } else if (confirmed == total) {
      message = 'Parabens! Todos confirmados!';
    } else {
      final faltam = total - confirmed;
      message = 'Falt${faltam == 1 ? 'a' : 'am'} $faltam confirmacao${faltam == 1 ? '' : 'es'}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B5EA7), Color(0xFF5B4FCF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 7,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    total == 0 ? Colors.white38 : Colors.white,
                  ),
                ),
                Text(
                  total == 0 ? '--' : '${(pct * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hoje',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  total == 0 ? 'Sem lembretes' : '$confirmed de $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  total == 0 ? '' : 'lembretes confirmados',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: _primary,
      letterSpacing: 1.2,
    ),
  );

  // Card de lembrete individual (para hoje)
  Widget _reminderTile(BuildContext context, Reminder r) {
    final hora =
        '${r.dateTime.hour.toString().padLeft(2, '0')}:${r.dateTime.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: r.confirmed ? Colors.green.shade50 : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: r.confirmed ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            r.confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: r.confirmed ? Colors.green : Colors.grey.shade400,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: r.confirmed ? Colors.green.shade800 : Colors.black87,
                  ),
                ),
                if (r.description.isNotEmpty)
                  Text(
                    r.description,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
          Text(
            hora,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (r.repeat != 'unico')
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.repeat, size: 14, color: Colors.grey.shade400),
            ),
        ],
      ),
    );
  }

  // Card de dia passado — confirmed confiavel somente para lembretes unicos
  Widget? _dayCard(BuildContext context, DateTime day, List<Reminder> all) {
    final scheduled = all.where((r) => _occursOn(r, day)).toList();
    if (scheduled.isEmpty) return null;

    final unicos = scheduled.where((r) => r.repeat == 'unico').toList();
    final recorrentes = scheduled.where((r) => r.repeat != 'unico').toList();
    final unicosConfirmados = unicos.where((r) => r.confirmed).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(blurRadius: 4, color: Colors.black.withOpacity(0.04)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(day),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (unicos.isNotEmpty)
                Text(
                  '$unicosConfirmados/${unicos.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _pctColor(unicosConfirmados / unicos.length),
                  ),
                ),
            ],
          ),
          if (scheduled.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...unicos.map((r) => _chip(
                  label: r.title,
                  confirmed: r.confirmed,
                  icon: r.confirmed ? Icons.check_circle : Icons.cancel,
                  iconColor: r.confirmed ? Colors.green : Colors.red.shade300,
                  bg: r.confirmed ? Colors.green.shade50 : Colors.red.shade50,
                )),
                ...recorrentes.map((r) => _chip(
                  label: r.title,
                  icon: Icons.repeat,
                  iconColor: Colors.grey,
                  bg: Colors.grey.shade100,
                )),
              ],
            ),
          ],
          if (recorrentes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${recorrentes.length} lembrete(s) recorrente(s) — sem dado de confirmacao',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    bool confirmed = false,
    required IconData icon,
    required Color iconColor,
    required Color bg,
  }) {
    return Chip(
      avatar: Icon(icon, size: 14, color: iconColor),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: bg,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _pctColor(double pct) {
    if (pct >= 0.8) return const Color(0xFF50C878);
    if (pct >= 0.5) return const Color(0xFFFF8C00);
    return const Color(0xFFE53935);
  }

  String _formatDate(DateTime d) {
    const meses = [
      '', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez'
    ];
    const dias = ['', 'seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];
    return '${dias[d.weekday]}, ${d.day} ${meses[d.month]}';
  }
}
