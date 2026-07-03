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

  // Evita duas ligações simultâneas: se o SOS for disparado por dois
  // caminhos quase ao mesmo tempo (botão, voz, volume, detector de queda,
  // toque duplo), o Telecom do Android cancela uma das chamadas
  // sobrepostas — o que aparece pro usuário como falha aleatória/
  // "número incorreto" mesmo com o número certo.
  static bool _ligando = false;
  static DateTime? _ultimaLigacao;

  /// Dispara o SOS. Retorna `true` se o registro foi criado com sucesso.
  static Future<bool> trigger({String? motivo}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Toggle "Botão de Pânico (SOS)" desligado: não registra alerta,
    // não avisa a família e não liga para o contato de emergência.
    if (!await SettingsService.getSos()) return false;

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

  /// Normaliza para E.164 (+55...). Confirmado por teste em campo: sem o
  /// código do país, a operadora rejeita a chamada de saída (SIP 487)
  /// mesmo com DDD e número corretos — com +55 ela roteia normalmente.
  static String _paraE164(String clean) {
    if (clean.startsWith('+')) return clean;
    // Já digitado com 55 na frente (sem o +): não duplicar.
    if (clean.length >= 12 && clean.startsWith('55')) return '+$clean';
    return '+55$clean';
  }

  /// Liga para um número específico.
  /// Tenta ligação direta (ACTION_CALL) se CALL_PHONE concedida;
  /// caso contrário abre o discador (ACTION_DIAL).
  static Future<void> callNumber(String numero) async {
    final clean = numero.replaceAll(RegExp(r'[^\d+]'), '');
    // Número brasileiro válido tem no mínimo DDD (2) + telefone (8) = 10
    // dígitos. Sem o DDD, tanto a ligação automática quanto uma rediscagem
    // manual do mesmo número falham — por isso a validação aqui.
    final digits = clean.replaceAll('+', '');
    if (digits.length < 10) return;
    final paraDiscar = _paraE164(clean);

    if (_ligando) return;
    final agora = DateTime.now();
    if (_ultimaLigacao != null &&
        agora.difference(_ultimaLigacao!) < const Duration(seconds: 10)) {
      return;
    }
    _ligando = true;
    _ultimaLigacao = agora;
    try {
      final status = await Permission.phone.request();
      if (status.isGranted) {
        try {
          await _callChannel.invokeMethod('callNumber', paraDiscar);
          return;
        } catch (_) {}
      }

      final uri = Uri(scheme: 'tel', path: paraDiscar);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } finally {
      _ligando = false;
    }
  }

  /// Abre o discador do sistema com o número já preenchido, sem tentar
  /// ligar automaticamente. Usado como confirmação manual de 1 toque
  /// quando a ligação automática (callNumber) pode não completar por
  /// motivos de rede/operadora fora do controle do app — é o mesmo
  /// caminho de uma ligação discada à mão.
  static Future<void> openDialer(String numero) async {
    final clean = numero.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: _paraE164(clean));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
