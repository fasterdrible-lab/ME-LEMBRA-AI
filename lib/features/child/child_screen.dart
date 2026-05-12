import 'package:flutter/material.dart';

import '../../models/reminder.dart';
import '../../services/profile_service.dart';
import '../../services/reminder_service.dart';

/// Tela do perfil Criança: visão simples, lúdica e gamificada dos lembretes.
class ChildScreen extends StatefulWidget {
  const ChildScreen({super.key});

  @override
  State<ChildScreen> createState() => _ChildScreenState();
}

class _ChildScreenState extends State<ChildScreen> {
  static const Color _primary = Color(0xFFFF8C00);

  String _nome = '';

  @override
  void initState() {
    super.initState();
    _carregarNome();
  }

  Future<void> _carregarNome() async {
    final nome = await ProfileService.getNameForSelectedProfile();
    if (mounted) setState(() => _nome = nome ?? '');
  }

  Future<void> _confirmar(Reminder r) async {
    await ReminderService.confirm(r.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Boa! Tarefa concluída! \u2B50')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(
        child: StreamBuilder<List<Reminder>>(
          stream: ReminderService.stream(),
          builder: (context, snapshot) {
            final all = snapshot.data ?? [];
            final agora = DateTime.now();
            final hoje = all
                .where((r) =>
                    r.dateTime.year == agora.year &&
                    r.dateTime.month == agora.month &&
                    r.dateTime.day == agora.day)
                .toList();
            final feitos = hoje.where((r) => r.confirmed).length;
            final total = hoje.length;
            final progresso = total == 0 ? 0.0 : feitos / total;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(feitos, total, progresso),
                const SizedBox(height: 20),
                const Text('Minhas tarefas de hoje',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (hoje.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Nenhuma tarefa hoje! Bora brincar! \u{1F389}',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                else
                  ...hoje.map(_taskTile),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(int feitos, int total, double progresso) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB347), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _nome.isNotEmpty ? 'Oi, $_nome! \u{1F44B}' : 'Oi, amigo! \u{1F44B}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Você fez $feitos de $total tarefas hoje!',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskTile(Reminder r) {
    final hora = '${r.dateTime.hour.toString().padLeft(2, '0')}:'
        '${r.dateTime.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _primary.withValues(alpha: 0.2),
          child: const Icon(Icons.star, color: _primary),
        ),
        title: Text(r.title.isNotEmpty ? r.title : r.type,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: r.confirmed ? TextDecoration.lineThrough : null,
              color: r.confirmed ? Colors.black45 : Colors.black,
            )),
        subtitle: Text('às $hora'),
        trailing: r.confirmed
            ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
            : IconButton(
                icon: const Icon(Icons.check_circle_outline,
                    color: Colors.green, size: 30),
                onPressed: () => _confirmar(r),
              ),
      ),
    );
  }
}
