import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sos_alert.dart';

/// Consulta os alertas SOS de um conjunto de usuários monitorados.
class SosFeedService {
  static final _db = FirebaseFirestore.instance;

  /// Stream dos últimos alertas SOS dos [uids] informados.
  /// Limita a 30 uids (limite do operador `whereIn` do Firestore).
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
}
