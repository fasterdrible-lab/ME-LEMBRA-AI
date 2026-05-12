import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/family_member.dart';
import '../../models/sos_alert.dart';
import '../../services/sos_feed_service.dart';

class MonitorScreen extends StatelessWidget {
  final FamilyMember member;

  const MonitorScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Monitorando ${member.nome}'),
        backgroundColor: const Color(0xFF7B5EA7),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Alertas SOS recentes'),
          StreamBuilder<List<SosAlert>>(
            stream: SosFeedService.streamForUsers([member.uid]),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data!;
              if (list.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum alerta registrado.'),
                  ),
                );
              }
              return Column(children: list.map(_sosTile).toList());
            },
          ),
          const SizedBox(height: 16),
          _section('Lembretes (últimos 30 dias)'),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(member.uid)
                .collection('reminders')
                .orderBy('dateTime', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sem lembretes cadastrados.'),
                  ),
                );
              }
              final total = docs.length;
              final confirmados =
                  docs.where((d) => d.data()['confirmed'] == true).length;
              final pct = total == 0 ? 0 : (confirmados * 100 / total).round();
              return Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Adesão: $pct% ($confirmados/$total)',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: total == 0 ? 0 : confirmados / total,
                            color: const Color(0xFF4A90D9),
                            backgroundColor: Colors.grey.shade300,
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...docs.take(20).map(_reminderTile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(t,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  Widget _sosTile(SosAlert a) {
    final loc = (a.latitude != null && a.longitude != null)
        ? '${a.latitude!.toStringAsFixed(5)}, ${a.longitude!.toStringAsFixed(5)}'
        : 'sem localização';
    final dt = a.createdAt;
    final dtStr = dt == null
        ? 'agora'
        : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return Card(
      color: const Color(0xFFFFEBEE),
      child: ListTile(
        leading: const Icon(Icons.warning, color: Color(0xFFE53935), size: 32),
        title: Text('SOS — ${a.motivo ?? 'manual'}'),
        subtitle: Text('$dtStr · $loc'),
      ),
    );
  }

  Widget _reminderTile(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final title = (data['title'] as String?) ?? 'Lembrete';
    final ts = data['dateTime'];
    final confirmed = data['confirmed'] == true;
    DateTime? when;
    if (ts is Timestamp) when = ts.toDate();
    final dtStr = when == null
        ? '-'
        : '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')} '
            '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return Card(
      child: ListTile(
        leading: Icon(
          confirmed ? Icons.check_circle : Icons.schedule,
          color: confirmed ? Colors.green : Colors.orange,
        ),
        title: Text(title),
        subtitle: Text(dtStr),
      ),
    );
  }
}
