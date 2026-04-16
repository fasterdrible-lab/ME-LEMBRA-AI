import 'package:flutter/material.dart';
import 'services/reminder_service.dart';
import 'models/reminder.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reminder>>(
      stream: ReminderService.stream(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];

        final remedios = all.where((r) => r.type == 'Remedio').length;
        final consultas = all.where((r) => r.type == 'Consulta').length;
        final mercado = all.where((r) => r.type == 'Mercado').length;
        final aniversarios = all.where((r) => r.type == 'Aniversario').length;
        final eventos = all.where((r) => r.type == 'Reuniao').length;
        final recorrentes = all.where((r) => r.repeat != 'unico').length;

        String _label(int count, String singular) {
          if (count == 0) return 'Nenhum';
          return '$count ativo(s)';
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Categorias',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Escolha o tipo de lembrete',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.3,
                  children: [
                    _catCard('Remedios', _label(remedios, 'ativo'), Icons.medication, const Color(0xFFFFEBEE), const Color(0xFFE57373)),
                    _catCard('Consultas', _label(consultas, 'agendada'), Icons.local_hospital, const Color(0xFFE3F2FD), const Color(0xFF64B5F6)),
                    _catCard('Mercado', _label(mercado, 'item'), Icons.shopping_cart, const Color(0xFFFFFDE7), const Color(0xFFFFD54F)),
                    _catCard('Aniversarios', _label(aniversarios, 'este mês'), Icons.cake, const Color(0xFFFFF3E0), const Color(0xFFFFB74D)),
                  ],
                ),
                const SizedBox(height: 14),
                _catCardLarge(
                  'Eventos/Reuniões',
                  eventos == 0 ? 'Nenhum' : '$eventos agendado(s)',
                  Icons.event,
                  const Color(0xFFEDE7F6),
                  const Color(0xFF9575CD),
                  true,
                ),
                const SizedBox(height: 14),
                _catCardLarge(
                  'Lembretes Recorrentes',
                  recorrentes == 0 ? 'Nenhum' : '$recorrentes ativo(s)',
                  Icons.repeat,
                  const Color(0xFFE3F2FD),
                  const Color(0xFF42A5F5),
                  true,
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _catCard(String titulo, String sub, IconData icon, Color bg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(sub, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _catCardLarge(String titulo, String sub, IconData icon, Color bg, Color iconColor, bool arrow) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(sub, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          if (arrow) const Icon(Icons.chevron_right, color: Colors.black45),
        ],
      ),
    );
  }
}
