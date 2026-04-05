import 'package:flutter/material.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                _catCard('Remedios', '4 ativos', Icons.medication, const Color(0xFFFFEBEE), const Color(0xFFE57373)),
                _catCard('Consultas', '1 agendada', Icons.local_hospital, const Color(0xFFE3F2FD), const Color(0xFF64B5F6)),
                _catCard('Mercado', 'Lista de compras', Icons.shopping_cart, const Color(0xFFFFFDE7), const Color(0xFFFFD54F)),
                _catCard('Aniversarios', '3 este mes', Icons.cake, const Color(0xFFFFF3E0), const Color(0xFFFFB74D)),
              ],
            ),
            const SizedBox(height: 14),
            _catCardLarge('Eventos', 'Reunioes . Viagens . Churrascos', Icons.event, const Color(0xFFEDE7F6), const Color(0xFF9575CD), true),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.3,
              children: [
                _catCard('Lista de Tarefas', '5 pendentes', Icons.check_box, const Color(0xFFE8F5E9), const Color(0xFF66BB6A)),
                _catCard('Lista', 'Generica', Icons.list_alt, const Color(0xFFF5F5F5), const Color(0xFF9E9E9E)),
              ],
            ),
            const SizedBox(height: 14),
            _catCardLarge('Lembretes Recorrentes', 'Ex: Tomar agua, vitaminas', Icons.repeat, const Color(0xFFE3F2FD), const Color(0xFF42A5F5), true),
            const SizedBox(height: 80),
          ],
        ),
      ),
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