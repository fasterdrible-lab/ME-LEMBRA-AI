import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_service.dart';
import 'family_service.dart';
import 'location_service.dart';
import 'profile_service.dart';

/// Serviço de emergência: registra um alerta SOS no Firestore com
/// localização atual e informações do usuário.
class SosService {
  static final _db = FirebaseFirestore.instance;

  /// Dispara o SOS. Retorna `true` se o registro foi criado com sucesso.
  static Future<bool> trigger({String? motivo}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    double? lat;
    double? lng;
    String? erroLocalizacao;
    try {
      final pos = await LocationService.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (e) {
      erroLocalizacao = e.toString();
    }

    final perfil = await ProfileService.getProfile();
    final nome = await ProfileService.getNameForSelectedProfile();

    await _db.collection('sos_alerts').add({
      'userId': user.uid,
      'perfil': perfil,
      'nome': nome,
      'motivo': motivo ?? 'manual',
      'latitude': lat,
      'longitude': lng,
      'erroLocalizacao': erroLocalizacao,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notificar todos os familiares vinculados via chat
    try {
      final members = await FamilyService.stream().first;
      if (members.isNotEmpty) {
        final locStr = (lat != null && lng != null)
            ? '📍 ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
            : '📍 localização não disponível';
        final msg =
            '🆘 *SOCORRO!* ${nome ?? 'Familiar'} acionou o botão SOS.\n'
            'Motivo: ${motivo ?? 'manual'}\n$locStr';
        for (final member in members) {
          await ChatService.send(member.uid, msg);
        }
      }
    } catch (_) {
      // Falha no chat não cancela o SOS
    }

    return true;
  }
}
