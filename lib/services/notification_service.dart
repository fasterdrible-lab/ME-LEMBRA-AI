import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

import 'profile_service.dart';
import 'voice_service.dart';

class NotificationService {
    /// Agenda uma notificação recorrente (diária ou semanal).
    /// [repeat] pode ser 'diario' ou 'semanal'.
    static Future<void> scheduleRepeatingReminder({
      required int id,
      required String title,
      required String body,
      required DateTime scheduledDate,
      required String repeat, // 'diario' ou 'semanal'
    }) async {
      await init();

      if (scheduledDate.isBefore(DateTime.now())) return;

      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'me_lembra_ai_channel',
        'Lembretes',
        channelDescription: 'Notificações de lembretes do Me Lembra AI',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      tz.TZDateTime nextInstance = tzDate;
      DateTime now = DateTime.now();
      if (repeat == 'diario') {
        // Se a data já passou hoje, agenda para amanhã
        if (scheduledDate.isBefore(now)) {
          nextInstance = tzDate.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          nextInstance,
          const NotificationDetails(android: androidDetails, iOS: iosDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: body,
        );
      } else if (repeat == 'semanal') {
        // Se a data já passou nesta semana, agenda para a próxima semana
        if (scheduledDate.isBefore(now)) {
          nextInstance = tzDate.add(const Duration(days: 7));
        }
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          nextInstance,
          const NotificationDetails(android: androidDetails, iOS: iosDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: body,
        );
      }
    }
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static final Map<int, Timer> _voiceTimers = {};

  /// Constrói frase natural para o TTS de alerta.
  /// Usa vírgula para criar pausa e soar mais humano.
  /// Ex.: title="Remédio", body="tomar dipirona" → "Atenção, tomar dipirona!"
  static String _voiceCallout(String title, String body) {
    final raw = body.trim().isNotEmpty ? body.trim() : title.trim();
    if (raw.isEmpty) return 'Atenção, você tem um lembrete!';
    final lower = raw.toLowerCase();
    // Prefixo contextual com vírgula — a pausa soa mais natural que exclamação sozinha
    String prefix = 'Atenção, ';
    if (lower.contains('remédio') || lower.contains('remedio') ||
        lower.contains('medicamento') || lower.contains('comprimido')) {
      prefix = 'Hora do remédio, ';
    } else if (lower.contains('consulta') || lower.contains('médico') ||
        lower.contains('dentista')) {
      prefix = 'Sua consulta, ';
    } else if (lower.contains('água') || lower.contains('agua')) {
      prefix = 'Hora de beber água! ';
    } else if (lower.contains('aniversário') || lower.contains('aniversario')) {
      prefix = 'Hoje tem aniversário, ';
    }
    final base = raw[0].toUpperCase() + raw.substring(1);
    final endsWithPunct =
        base.endsWith('!') || base.endsWith('.') || base.endsWith('?');
    return '$prefix${endsWithPunct ? base : '$base!'}';
  }

  /// Resolve o canal Android conforme o perfil ativo do usuário.
  /// - Idoso: som alto, vibração intensa.
  /// - Criança: som leve.
  /// - Adulto: padrão.
  static Future<AndroidNotificationDetails> _androidDetailsForProfile() async {
    final perfil = await ProfileService.getProfile();
    switch (perfil) {
      case 'Vovô / Vovó':
        return const AndroidNotificationDetails(
          'me_lembra_ai_idoso',
          'Lembretes (Idoso)',
          channelDescription: 'Notificações reforçadas para o perfil idoso',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
          icon: '@mipmap/ic_launcher',
        );
      case 'Filhos':
        return const AndroidNotificationDetails(
          'me_lembra_ai_crianca',
          'Lembretes (Criança)',
          channelDescription: 'Notificações lúdicas para o perfil criança',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: false,
          icon: '@mipmap/ic_launcher',
        );
      default:
        return const AndroidNotificationDetails(
          'me_lembra_ai_channel',
          'Lembretes',
          channelDescription: 'Notificações de lembretes do Me Lembra AI',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        );
    }
  }

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Solicitar permissão no Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Quando o usuário toca na notificação, anuncia por voz se o perfil for Idoso.
  static Future<void> _onNotificationTap(NotificationResponse response) async {
    final perfil = await ProfileService.getProfile();
    if (perfil == 'Vovô / Vovó') {
      final payload = response.payload ?? '';
      final callout = payload.trim().isNotEmpty
          ? (payload[0].toUpperCase() + payload.substring(1))
              .replaceAll(RegExp(r'[.!?]$'), '') +
              '!'
          : 'Você tem um lembrete!';
      await VoiceService.speakAlert(callout);
    }
  }

  /// Agenda um Timer no app para falar o lembrete em voz alta no horário exato.
  /// Funciona enquanto o app estiver em execução (foreground/background recente).
  static void _scheduleVoiceAnnouncement(int id, DateTime when, String callout) {
    _voiceTimers.remove(id)?.cancel();
    final delay = when.difference(DateTime.now());
    if (delay.isNegative) return;
    _voiceTimers[id] = Timer(delay, () async {
      _voiceTimers.remove(id);
      // Só fala se o perfil ativo for Idoso (acessibilidade).
      final perfil = await ProfileService.getProfile();
      if (perfil == 'Vovô / Vovó') {
        await VoiceService.speakAlert(callout);
      }
    });
  }

  /// Agenda uma notificação no horário exato do lembrete.
  /// [id] deve ser único por lembrete — use o hashCode da String do Firestore ID.
  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await init();

    // Não agenda no passado
    if (scheduledDate.isBefore(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'me_lembra_ai_channel',
      'Lembretes',
      channelDescription: 'Notificações de lembretes do Me Lembra AI',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: body,
    );

    // Anuncia em voz alta no horário (só dispara se app estiver em execução).
    _scheduleVoiceAnnouncement(id, scheduledDate, _voiceCallout(title, body));
  }

  /// Cancela uma notificação agendada pelo ID.
  static Future<void> cancel(int id) async {
    _voiceTimers.remove(id)?.cancel();
    await _plugin.cancel(id);
  }

  /// Cancela todas as notificações agendadas.
  static Future<void> cancelAll() async {
    for (final t in _voiceTimers.values) {
      t.cancel();
    }
    _voiceTimers.clear();
    await _plugin.cancelAll();
  }

  /// Agenda (ou re-agenda) a notificação diária de resumo matinal às 8h.
  /// Aparece todo dia às 8:00 com a mensagem "Bom dia! Confira seus lembretes de hoje."
  /// ID fixo: 8000 (não conflita com lembretes do usuário).
  static Future<void> scheduleMorningBriefing() async {
    await init();
    const id = 8000;
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, 8, 0);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    final tzDate = tz.TZDateTime.from(next, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'me_lembra_ai_matinal',
      'Resumo Matinal',
      channelDescription: 'Resumo diário dos lembretes às 8h',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      id,
      'Bom dia! ☀️',
      'Confira seus lembretes de hoje no Me Lembra Aí.',
      tzDate,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'matinal',
    );
  }

  /// Exibe uma notificação imediata (para testes).
  static Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'me_lembra_ai_channel',
      'Lembretes',
      channelDescription: 'Notificações de lembretes do Me Lembra AI',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: body,
    );
  }
}
