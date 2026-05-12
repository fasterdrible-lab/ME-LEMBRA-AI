import 'package:flutter/material.dart';
import 'services/reminder_service.dart';
import 'models/reminder.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Histórico de Aderência'),
        backgroundColor: const Color(0xFF7B5EA7),
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
          // Últimos 30 dias
          final hoje = DateTime.now();
          final days = List.generate(30, (i) {
            final d = hoje.subtract(Duration(days: i));
            return DateTime(d.year, d.month, d.day);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final dayNext = day.add(const Duration(days: 1));

              // Lembretes agendados para este dia
              final agendados = all.where((r) {
                final rd = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
                if (r.repeat == 'unico') return rd == day;
                if (r.repeat == 'diario') return !rd.isAfter(day);
                if (r.repeat == 'semanal') {
                  return !rd.isAfter(day) && r.dateTime.weekday == day.weekday;
                }
                return false;
              }).toList();

              final confirmados = agendados.where((r) => r.confirmed).length;
              final total = agendados.length;

              if (total == 0 && index > 0) return const SizedBox.shrink();

              final pct = total == 0 ? 0.0 : confirmados / total;
              final isHoje = day == DateTime(hoje.year, hoje.month, hoje.day);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isHoje ? 'Hoje' : _formatDate(day),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isHoje ? const Color(0xFF7B5EA7) : Colors.black87,
                            ),
                          ),
                          Text(
                            total == 0
                                ? 'Sem lembretes'
                                : '$confirmados/$total confirmados',
                            style: TextStyle(
                              fontSize: 13,
                              color: _pctColor(pct),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(_pctColor(pct)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: agendados.map((r) {
                            return Chip(
                              avatar: Icon(
                                r.confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
                                size: 16,
                                color: r.confirmed ? Colors.green : Colors.grey,
                              ),
                              label: Text(r.title, style: const TextStyle(fontSize: 12)),
                              backgroundColor: r.confirmed
                                  ? Colors.green.shade50
                                  : Colors.grey.shade100,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
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
    const dias = ['', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    return '${dias[d.weekday]}, ${d.day} ${meses[d.month]}';
  }
}
