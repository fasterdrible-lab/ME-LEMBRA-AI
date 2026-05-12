import 'package:flutter/material.dart';
import 'services/reminder_service.dart';
import 'models/reminder.dart';
import 'create_reminder_screen.dart';
import 'edit_reminder_screen.dart';

class RemindersScreen extends StatelessWidget {
  /// Quando [filtroTipo] é informado, exibe apenas lembretes desse tipo.
  final String? filtroTipo;
  const RemindersScreen({super.key, this.filtroTipo});

  String _getEmoji(String tipo) {
    const mapa = {
      'Remedio': '💊',
      'Consulta': '🩺',
      'Aniversario': '🎂',
      'Mercado': '🛒',
      'Reuniao': '🤝',
      'Tomar': '💧',
    };
    return mapa[tipo] ?? '🔔';
  }

  void _confirmarDelecao(BuildContext context, Reminder reminder) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir lembrete?'),
        content: const Text('Essa acao nao pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ReminderService.delete(reminder.id);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Erro ao excluir: $e')),
                );
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _confirmarLembrete(String id) {
    ReminderService.confirm(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(filtroTipo != null ? '$filtroTipo' : 'Todos os Lembretes'),
        backgroundColor: const Color(0xFF7B5EA7),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<Reminder>>(
        stream: ReminderService.stream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Erro ao carregar lembretes.',
                style: TextStyle(fontSize: 16, color: Colors.black54)),
            );
          }
          final todos = snapshot.data ?? [];
          final lembretes = filtroTipo == null
              ? todos
              : todos.where((r) => r.type == filtroTipo).toList();
          if (lembretes.isEmpty) {
            return const Center(
              child: Text('Nenhum lembrete ainda.',
                style: TextStyle(fontSize: 16, color: Colors.black54)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lembretes.length,
            itemBuilder: (context, index) {
              final reminder = lembretes[index];
              final emoji = _getEmoji(reminder.type);
              final hora = '${reminder.dateTime.hour.toString().padLeft(2, '0')}:${reminder.dateTime.minute.toString().padLeft(2, '0')}';
              final subtitulo = reminder.description.isNotEmpty
                  ? '${reminder.type} - ${reminder.description}'
                  : reminder.type;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: reminder.confirmed ? Colors.green.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [const BoxShadow(blurRadius: 6, color: Colors.black12)],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reminder.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          if (subtitulo.isNotEmpty)
                            Text(subtitulo, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(hora,
                          style: const TextStyle(color: Color(0xFF7B5EA7), fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditReminderScreen(reminder: reminder),
                                ),
                              ),
                              child: const Icon(Icons.edit_outlined, color: Color(0xFF7B5EA7), size: 20),
                            ),
                            const SizedBox(width: 6),
                            if (!reminder.confirmed)
                              GestureDetector(
                                onTap: () => _confirmarLembrete(reminder.id),
                                child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                              ),
                            if (!reminder.confirmed) const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _confirmarDelecao(context, reminder),
                              child: const Icon(Icons.delete_outline, color: Colors.black26, size: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7B5EA7),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateReminderScreen()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
