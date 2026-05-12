import 'package:flutter/material.dart';

import '../../create_reminder_screen.dart';
import '../../models/reminder.dart';
import '../../services/profile_service.dart';
import '../../services/reminder_service.dart';
import '../../services/smart_suggestions_service.dart';
import '../../history_screen.dart';

/// Tela do perfil Adulto: dashboard com agenda do dia e estatísticas.
class AdultScreen extends StatefulWidget {
  const AdultScreen({super.key});

  @override
  State<AdultScreen> createState() => _AdultScreenState();
}

class _AdultScreenState extends State<AdultScreen> {
  static const Color _primary = Color(0xFF4A90D9);

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

  void _criarLembrete() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateReminderScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        onPressed: _criarLembrete,
        icon: const Icon(Icons.add),
        label: const Text('Novo lembrete'),
      ),
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
            final futuros = all.where((r) => r.dateTime.isAfter(agora)).toList();
            final concluidos = all.where((r) => r.confirmed).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(),
                const SizedBox(height: 16),
                _suggestionsCard(),
                Row(
                  children: [
                    Expanded(child: _stat('Hoje', hoje.length, Icons.today, Colors.blue)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Próximos', futuros.length, Icons.schedule, Colors.deepPurple)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Feitos', concluidos, Icons.check_circle, Colors.green)),
                  ],
                ),
                const SizedBox(height: 22),
                const Text('Agenda de hoje',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (hoje.isEmpty)
                  _emptyCard('Nenhum compromisso para hoje. Aproveite o dia!')
                else
                  ...hoje.map(_reminderTile),
                const SizedBox(height: 22),
                const Text('Próximos lembretes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (futuros.isEmpty)
                  _emptyCard('Sem agendamentos futuros.')
                else
                  ...futuros.take(5).map(_reminderTile),
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90D9), Color(0xFF6CB1F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _nome.isNotEmpty ? 'Olá, $_nome' : 'Olá!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                tooltip: 'Histórico',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.family_restroom, color: Colors.white),
                tooltip: 'Família',
                onPressed: () =>
                    Navigator.pushNamed(context, '/family'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Sua agenda inteligente está em dia.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text('$value',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _emptyCard(String texto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(texto, style: const TextStyle(color: Colors.black54)),
    );
  }

  Widget _suggestionsCard() {
    return FutureBuilder<List<ReminderSuggestion>>(
      future: SmartSuggestionsService.generate(),
      builder: (context, snap) {
        final list = snap.data ?? const <ReminderSuggestion>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF5FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: _primary),
                  SizedBox(width: 8),
                  Text('Sugestões inteligentes',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ...list.take(3).map((s) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lightbulb_outline,
                        color: Color(0xFF7B5EA7)),
                    title: Text(
                      '${s.title} às ${s.hour.toString().padLeft(2, '0')}:'
                      '${s.minute.toString().padLeft(2, '0')} (${s.repeat})',
                    ),
                    subtitle: Text(s.reason,
                        style: const TextStyle(fontSize: 12)),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _reminderTile(Reminder r) {
    final hora = '${r.dateTime.hour.toString().padLeft(2, '0')}:'
        '${r.dateTime.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _primary.withValues(alpha: 0.15),
          child: const Icon(Icons.notifications_active, color: _primary),
        ),
        title: Text(r.title.isNotEmpty ? r.title : r.type,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${r.type} • $hora'),
        trailing: r.confirmed
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
