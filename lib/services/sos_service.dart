import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_service.dart';
import 'family_service.dart';
import 'location_service.dart';
import 'profile_service.dart';
import 'settings_service.dart';

/// Serviço de emergência: registra alerta SOS, notifica familiares e
/// liga automaticamente para o número de emergência cadastrado.
class SosService {
  static final _db = FirebaseFirestore.instance;
  static const _callChannel = MethodChannel('com.melembra.ai/call');

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

    // Ligar para o número SOS cadastrado
    await _triggerCall();

    return true;
  }

  /// Liga para o primeiro número SOS configurado automaticamente.
  static Future<void> _triggerCall() async {
    final numero = await SettingsService.getSosNumero();
    if (numero.trim().isEmpty) return;
    await callNumber(numero);
  }

  /// Liga para um número específico.
  /// Tenta ligação direta (ACTION_CALL) se CALL_PHONE concedida;
  /// caso contrário abre o discador (ACTION_DIAL).
  static Future<void> callNumber(String numero) async {
    final clean = numero.replaceAll(RegExp(r'[^\d+]'), '');
    // Número sem DDD/DDI (menos de 8 dígitos) é inválido para discagem —
    // evita que o Android recuse a chamada com "número incorreto".
    final digits = clean.replaceAll('+', '');
    if (digits.length < 8) return;

    final status = await Permission.phone.request();
    if (status.isGranted) {
      try {
        await _callChannel.invokeMethod('callNumber', clean);
        return;
      } catch (_) {}
    }

    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
