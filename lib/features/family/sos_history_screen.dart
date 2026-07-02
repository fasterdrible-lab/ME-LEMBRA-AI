import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/sos_alert.dart';
import '../../services/sos_feed_service.dart';

/// Tela do idoso: histórico dos próprios alertas SOS com status de visualização.
class SosHistoryScreen extends StatelessWidget {
  const SosHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Alertas SOS',
            style: TextStyle(fontSize: 22)),
        backgroundColor: const Color(0xFF7B5EA7),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<SosAlert>>(
        stream: SosFeedService.streamOwnAlerts(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar os alertas.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF7B5EA7)));
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Color(0xFF43A047)),
                  SizedBox(height: 16),
                  Text('Nenhum alerta SOS registrado.',
                      style: TextStyle(fontSize: 20)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) => _tile(list[i]),
          );
        },
      ),
    );
  }

  Widget _tile(SosAlert a) {
    final dt = a.createdAt;
    final dtStr = dt == null
        ? 'agora'
        : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final qtd = a.viewedBy.length;
    final visto = qtd > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFEBEE),
          radius: 26,
          child: const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFE53935), size: 30),
        ),
        title: Text(
          'SOS — ${a.motivo ?? 'manual'}',
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(dtStr,
              style: const TextStyle(fontSize: 15)),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              visto ? Icons.visibility : Icons.visibility_off,
              color: visto ? Colors.green : Colors.orange,
              size: 28,
            ),
            const SizedBox(height: 2),
            Text(
              visto ? '$qtd familiar(es)' : 'Não visto',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: visto
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
