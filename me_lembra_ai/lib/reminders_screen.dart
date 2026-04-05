import 'package:flutter/material.dart';
import 'create_reminder_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final List<String> _reminders = [];

  Future<void> _openCreateReminder() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const CreateReminderScreen()),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _reminders.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Lembretes'),
        backgroundColor: const Color(0xFF4A90D9),
        foregroundColor: Colors.white,
      ),
      body: _reminders.isEmpty
          ? const Center(
              child: Text(
                'Nenhum lembrete ainda.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.alarm, color: Color(0xFF4A90D9)),
                    title: Text(_reminders[index]),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4A90D9),
        onPressed: _openCreateReminder,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}