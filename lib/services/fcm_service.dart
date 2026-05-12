import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

/// Inicializa o Firebase Cloud Messaging e salva o token FCM no Firestore.
/// Deve ser chamado logo apos o login (ex: initState do HomeScreen).
class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  static Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Solicitar permissao de notificacoes
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Salvar token inicial
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token, user.uid);
    } catch (_) {}

    // Atualizar token ao renovar
    _messaging.onTokenRefresh.listen((t) async {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) await _saveToken(t, u.uid);
    });

    // Mostrar notificacao local quando app esta em primeiro plano
    FirebaseMessaging.onMessage.listen((msg) async {
      final title = msg.notification?.title ?? '';
      final body = msg.notification?.body ?? '';
      if (title.isNotEmpty || body.isNotEmpty) {
        await NotificationService.showImmediate(
          id: msg.hashCode,
          title: title,
          body: body,
        );
      }
    });
  }

  static Future<void> _saveToken(String token, String uid) async {
    await _db.collection('users').doc(uid).set(
      {
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
