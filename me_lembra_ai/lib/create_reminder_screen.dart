import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/reminder_service.dart';
import 'services/profile_service.dart';
import 'services/notification_service.dart';
import 'models/reminder.dart';

class CreateReminderScreen extends StatefulWidget {
  const CreateReminderScreen({super.key});

  @override
  State<CreateReminderScreen> createState() =>
      _CreateReminderScreenState();
}

class _CreateReminderScreenState extends State<CreateReminderScreen> {
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String tipo = 'Remedio';
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  bool _salvando = false;

  final List<Map<String, String>> tipos = [
    {'label': 'Remedio',     'emoji': '💊'},
    {'label': 'Consulta',    'emoji': '🩺'},
    {'label': 'Aniversario', 'emoji': '🎂'},
    {'label': 'Mercado',     'emoji': '🛒'},
    {'label': 'Reuniao',     'emoji': '🤝'},
    {'label': 'Tomar',       'emoji': '💧'},
  ];

  Future<void> _salvar() async {
    final titulo = _tituloController.text.trim();
    final desc = _descController.text.trim();
    if (titulo.isEmpty) return;

    setState(() => _salvando = true);
    try {
      // Login anônimo automático se não autenticado
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final userId = FirebaseAuth.instance.currentUser!.uid;
      final perfil = await ProfileService.getProfile() ?? '';
      final dateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      final reminder = Reminder(
        id: '',
        userId: userId,
        title: titulo,
        type: tipo,
        description: desc,
        dateTime: dateTime,
        repeat: 'unico',
        notification: '',
        perfil: perfil,
      );

      await ReminderService.add(reminder);
      await NotificationService.scheduleReminder(
        id: reminder.title.hashCode ^ reminder.dateTime.millisecondsSinceEpoch,
        title: _getNotificationTitle(tipo),
        body: titulo,
        scheduledDate: dateTime,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String _getNotificationTitle(String tipo) {
    switch (tipo) {
      case 'Remedio': return '💊 Hora do remédio!';
      case 'Consulta': return '🩺 Você tem uma consulta!';
      case 'Aniversario': return '🎂 Aniversário hoje!';
      case 'Mercado': return '🛒 Lista de compras';
      case 'Reuniao': return '🤝 Você tem uma reunião!';
      case 'Tomar': return '💧 Hora de tomar água!';
      default: return '🔔 Lembrete!';
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (time != null) setState(() => selectedTime = time);
  }

  Widget _chip(Map<String, String> item) {
    final selecionado = item['label'] == tipo;
    return GestureDetector(
      onTap: () => setState(() => tipo = item['label']!),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        decoration: BoxDecoration(
          color: selecionado ? const Color(0xFF7B5EA7) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selecionado ? const Color(0xFF7B5EA7) : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item['emoji']!, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(item['label']!,
              style: TextStyle(
                color: selecionado ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Novo Lembrete'),
        backgroundColor: const Color(0xFF7B5EA7),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(children: tipos.map((e) => _chip(e)).toList()),
            const SizedBox(height: 16),
            const Text('Titulo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _tituloController,
              decoration: InputDecoration(
                hintText: 'Ex: Losartana 50mg',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Descricao (opcional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                hintText: 'Ex: Todos os dias',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Data e Hora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text('${selectedDate.day.toString().padLeft(2,'0')}/${selectedDate.month.toString().padLeft(2,'0')}/${selectedDate.year}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(selectedTime.format(context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B5EA7),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _salvando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('SALVAR LEMBRETE',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}