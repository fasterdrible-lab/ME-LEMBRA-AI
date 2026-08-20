import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

/// Inicializa o Firebase Cloud Messaging e salva o token FCM no Firestore.
///
/// Deve ser chamado logo apos o usuario ficar autenticado E com um perfil
/// selecionado. Hoje isso acontece em dois pontos da app (ambos precisam
/// chamar init(), pois nenhuma sessao passa pelos dois necessariamente):
///  - HomeScreen.initState() (reabertura do app ja autenticado)
///  - ProfileSelectionScreen, logo apos escolher o perfil (fluxo de
///    login/cadastro, que nunca constroi a HomeScreen na mesma sessao)
/// Por isso init() e idempotente: pode ser chamado mais de uma vez por
/// sessao sem duplicar listeners nem quebrar caso o Firebase ainda nao
/// esteja pronto (chamado fire-and-forget, sem await, pelos callers).
class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  /// Garante que os listeners (onTokenRefresh/onMessage) sejam registrados
  /// uma unica vez por processo, mesmo que init() seja chamado mais de uma
  /// vez na mesma sessao (ex.: ProfileSelectionScreen e depois HomeScreen).
  static bool _listenersRegistered = false;

  /// Hook usado apenas em testes para verificar que init() foi chamado,
  /// sem depender de um Firebase App real inicializado. Nao tem efeito em
  /// producao (permanece null).
  @visibleForTesting
  static void Function()? debugOnInitCalled;

  static Future<void> init() async {
    debugOnInitCalled?.call();
    try {
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

      if (_listenersRegistered) return;
      _listenersRegistered = true;

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
    } catch (_) {
      // init() e chamado fire-and-forget em pontos de navegacao (ex.:
      // ProfileSelectionScreen); uma falha aqui nao pode derrubar o fluxo.
    }
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
