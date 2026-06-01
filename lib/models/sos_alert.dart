import 'package:cloud_firestore/cloud_firestore.dart';

/// Alerta SOS persistido em `sos_alerts`.
class SosAlert {
  final String id;
  final String userId;
  final String? nome;
  final String? perfil;
  final String? motivo;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final List<String> viewedBy;

  const SosAlert({
    required this.id,
    required this.userId,
    this.nome,
    this.perfil,
    this.motivo,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.viewedBy = const [],
  });

  factory SosAlert.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final ts = data['createdAt'];
    DateTime? when;
    if (ts is Timestamp) when = ts.toDate();
    return SosAlert(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      nome: data['nome'] as String?,
      perfil: data['perfil'] as String?,
      motivo: data['motivo'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt: when,
      viewedBy: List<String>.from(data['viewedBy'] as List? ?? []),
    );
  }
}
