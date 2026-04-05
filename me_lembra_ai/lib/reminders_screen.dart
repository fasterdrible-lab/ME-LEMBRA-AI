import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'create_reminder_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<String> _lembretes = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _lembretes = prefs.getStringList('lembretes') ?? []);
  }

  Future<void> _deletar(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList('lembretes') ?? [];
    lista.removeAt(index);
    await prefs.setStringList('lembretes', lista);
    _carregar();
  }

  Future<void> _abrirCriar() async {
    final resultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CreateReminderScreen()),
    );
    if (resultado != null && resultado.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final lista = prefs.getStringList('lembretes') ?? [];
      lista.add(resultado);
      await prefs.setStringList('lembretes', lista);
      _carregar();
    }
  }

  String _getTitulo(String raw) {
    final parts = raw.split('|');
    return parts.length > 1 ? parts[1] : raw;
  }

  String _getSubtitulo(String raw) {
    final parts = raw.split('|');
    final tipo = parts[0];
    final desc = parts.length > 2 ? parts[2] : '';
    if (desc.isNotEmpty) return tipo + ' - ' + desc;
    return tipo;
  }

  String _getHora(String raw) {
    final parts = raw.split('|');
    return parts.length > 4 ? parts[4] : '';
  }

  String _getEmoji(String raw) {
    final Map<String, String> mapa = {
      'Remedio': '💊',
      'Consulta': '🩺',
      'Aniversario': '🎂',
      'Mercado': '🛒',
      'Reuniao': '🤝',
      'Tomar': '💧',
    };
    return mapa[raw.split('|').first] ?? '🔔';
  }

  void _confirmarDelecao(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir lembrete?'),
        content: const Text('Essa acao nao pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deletar(index);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Todos os Lembretes'),
        backgroundColor: const Color(0xFF7B5EA7),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _lembretes.isEmpty
          ? const Center(
              child: Text('Nenhum lembrete ainda.',
                style: TextStyle(fontSize: 16, color: Colors.black54)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _lembretes.length,
              itemBuilder: (context, index) {
                final raw = _lembretes[index];
                final titulo = _getTitulo(raw);
                final subtitulo = _getSubtitulo(raw);
                final hora = _getHora(raw);
                final emoji = _getEmoji(raw);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
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
                            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            if (subtitulo.isNotEmpty)
                              Text(subtitulo, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(hora.isNotEmpty ? hora : 'Hoje',
                            style: const TextStyle(color: Color(0xFF7B5EA7), fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _confirmarDelecao(index),
                            child: const Icon(Icons.delete_outline, color: Colors.black26, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7B5EA7),
        onPressed: _abrirCriar,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
