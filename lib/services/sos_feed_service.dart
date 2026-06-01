import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sos_alert.dart';

/// Consulta os alertas SOS de um conjunto de usuários monitorados.
class SosFeedService {
  static final _db = FirebaseFirestore.instance;

  /// Stream dos últimos alertas SOS dos [uids] informados.
  static Stream<List<SosAlert>> streamForUsers(List<String> uids) {
    if (uids.isEmpty) return Stream.value(const []);
    final limited = uids.length > 30 ? uids.sublist(0, 30) : uids;
    return _db
        .collection('sos_alerts')
        .where('userId', whereIn: limited)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((qs) => qs.docs.map(SosAlert.fromDoc).toList());
  }

  /// Stream dos alertas SOS do próprio usuário (tela do idoso).
  static Stream<List<SosAlert>> streamOwnAlerts(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    return _db
        .collection('sos_alerts')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((qs) => qs.docs.map(SosAlert.fromDoc).toList());
  }

  /// Registra [viewerUid] como visualizador do alerta [alertId].
  static Future<void> markViewed(String alertId, String viewerUid) async {
    if (alertId.isEmpty || viewerUid.isEmpty) return;
    await _db.collection('sos_alerts').doc(alertId).update({
      'viewedBy': FieldValue.arrayUnion([viewerUid]),
    });
  }
}
