import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/sos_alert.dart';
import 'family_service.dart';
import 'notification_service.dart';

/// Escuta SOS dos vínculos monitorados do usuário atual e dispara
/// notificações locais quando algo novo chega.
class SosListenerService {
  static StreamSubscription? _familySub;
  static StreamSubscription? _sosSub;
  static DateTime _startedAt = DateTime.now();

  /// Inicia o listener. Idempotente.
  static void start() {
    stop();
    _startedAt = DateTime.now();
    _familySub = FamilyService.streamMonitored().listen((members) {
      _sosSub?.cancel();
      if (members.isEmpty) return;
      final uids = members.map((m) => m.uid).toList();
      _sosSub = FirebaseFirestore.instance
          .collection('sos_alerts')
          .where('userId', whereIn: uids.length > 30 ? uids.sublist(0, 30) : uids)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startedAt))
          .snapshots()
          .listen(_onSnapshot);
    });
  }

  static Future<void> stop() async {
    await _familySub?.cancel();
    await _sosSub?.cancel();
    _familySub = null;
    _sosSub = null;
  }

  static void _onSnapshot(QuerySnapshot<Map<String, dynamic>> qs) {
    for (final change in qs.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final alert = SosAlert.fromDoc(change.doc);
      if (alert.userId == FirebaseAuth.instance.currentUser?.uid) continue;
      NotificationService.showSosAlert(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        nome: alert.nome ?? 'familiar',
        motivo: alert.motivo ?? 'manual',
        lat: alert.latitude?.toStringAsFixed(4),
        lng: alert.longitude?.toStringAsFixed(4),
      );
    }
  }
}
