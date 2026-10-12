import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

import '../features/molly/services/molly_briefing_service.dart';
import 'profile_service.dart';
import 'settings_service.dart';
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

      await agendarAcompanhamentoRemedio(
        idLembrete: id,
        title: title,
        body: body,
        horarioLembrete: scheduledDate,
        repeat: repeat,
      );

      // Canal conforme o perfil (Melhor Idade: reforçado; Filhos: leve).
      final androidDetails = await _androidDetailsForProfile();

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final detalhes = NotificationDetails(android: androidDetails, iOS: iosDetails);

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
          detalhes,
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
          detalhes,
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

  // ---------------------------------------------------------------------
  // TAREFA 23 (proatividade da Molly): 15 min depois de cada lembrete de
  // remédio, uma notificação "Você conseguiu tomar seu remédio?". Tocar
  // nela pede pra tela Melhor Idade abrir a Molly, que faz a pergunta e
  // ouve a resposta. Cancelada quando o remédio é confirmado
  // (`ReminderService.confirm`) ou o lembrete apagado/editado ([cancel]).
  // ---------------------------------------------------------------------

  static const String payloadAcompanhamentoRemedio = 'molly_remedio';
  static const Duration atrasoAcompanhamento = Duration(minutes: 15);

  /// Incrementa quando o usuário toca numa notificação de acompanhamento —
  /// `elderly_screen.dart` escuta e abre a Molly.
  static final ValueNotifier<int> pedidosAbrirMolly = ValueNotifier(0);
  static bool _abrirMollyPendente = false;

  /// Consome o pedido pendente (inclusive o de quando o app foi aberto
  /// pela notificação, antes da tela existir). `true` = abrir a Molly.
  static bool consumirPedidoAbrirMolly() {
    final p = _abrirMollyPendente;
    _abrirMollyPendente = false;
    return p;
  }

  static int idAcompanhamento(int idLembrete) => (idLembrete ^ 0x15A5A5A5) & 0x7FFFFFFF;

  /// ID de um "lembra de novo" da Molly — estável por lembrete (ID do
  /// Firestore) + tentativa, 31 bits, sem colidir com o 8000 do bom dia.
  static int idRelembrar(String reminderId, int tentativa) =>
      ((reminderId.hashCode ^ 0x2E1A0000) + tentativa) & 0x7FFFFFFF;

  /// ID da notificação principal de um lembrete — a mesma fórmula usada
  /// em todas as telas que agendam (título + data/hora original).
  static int idDoLembrete(String title, DateTime dateTime) =>
      (title.hashCode ^ dateTime.millisecondsSinceEpoch).remainder(2147483647).abs();

  /// Remédio confirmado: some com os "lembra de novo" pendentes dele.
  static Future<void> cancelarRelembretes(String reminderId, {int maxTentativas = 2}) async {
    for (var i = 0; i < maxTentativas; i++) {
      await _plugin.cancel(idRelembrar(reminderId, i));
    }
  }

  /// Sem "tomar" de propósito: na tela de criar lembrete o tipo "Tomar" é
  /// "Hora de tomar água!" — água não ganha "conseguiu tomar seu remédio?".
  static bool pareceRemedio(String title, String body) {
    final t = '$title $body'.toLowerCase();
    return t.contains('remed') || t.contains('remédio') || t.contains('medica') ||
        t.contains('comprimido') || t.contains('\u{1F48A}');
  }

  /// Agenda o acompanhamento de um lembrete de remédio — só no perfil
  /// Melhor Idade e com "Avisos da Molly" ligado. [repeat]: 'unico',
  /// 'diario' ou 'semanal'. Nunca lança (não pode atrapalhar o lembrete).
  static Future<void> agendarAcompanhamentoRemedio({
    required int idLembrete,
    required String title,
    required String body,
    required DateTime horarioLembrete,
    String repeat = 'unico',
  }) async {
    try {
      if (!pareceRemedio(title, body)) return;
      if (await ProfileService.getProfile() != 'Melhor Idade') return;
      if (!await SettingsService.getMollyAvisosProativos()) return;

      var quando = horarioLembrete.add(atrasoAcompanhamento);
      final agora = DateTime.now();
      if (repeat == 'diario') {
        while (!quando.isAfter(agora)) {
          quando = quando.add(const Duration(days: 1));
        }
      } else if (repeat == 'semanal') {
        while (!quando.isAfter(agora)) {
          quando = quando.add(const Duration(days: 7));
        }
      } else if (!quando.isAfter(agora)) {
        return;
      }

      // Só chega aqui no perfil Melhor Idade → canal reforçado.
      final androidDetails = await _androidDetailsForProfile();
      await _plugin.zonedSchedule(
        idAcompanhamento(idLembrete),
        'Você conseguiu tomar seu remédio?',
        '${body.trim()} — toque para responder à Molly.',
        tz.TZDateTime.from(quando, tz.local),
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: repeat == 'diario'
            ? DateTimeComponents.time
            : repeat == 'semanal'
                ? DateTimeComponents.dayOfWeekAndTime
                : null,
        payload: payloadAcompanhamentoRemedio,
      );
    } catch (_) {}
  }

  /// Remédio confirmado: cancela o acompanhamento de hoje; se for
  /// recorrente, reagenda a partir da próxima ocorrência.
  static Future<void> remedioConfirmado({
    required int idLembrete,
    required String title,
    required DateTime horarioLembrete,
    required String repeat,
    String tipo = '',
  }) async {
    try {
      await _plugin.cancel(idAcompanhamento(idLembrete));
      if (repeat == 'diario' || repeat == 'semanal') {
        final passo = Duration(days: repeat == 'diario' ? 1 : 7);
        var proximo = horarioLembrete;
        while (!proximo.isAfter(DateTime.now())) {
          proximo = proximo.add(passo);
        }
        // Tipo no título ("Remedio"/"Tomar"): o nome sozinho ("Losartana")
        // não diria que é remédio.
        await agendarAcompanhamentoRemedio(
          idLembrete: idLembrete,
          title: tipo,
          body: title,
          horarioLembrete: proximo,
          repeat: repeat,
        );
      }
    } catch (_) {}
  }

  /// "Avisos da Molly" desligado: cancela todos os acompanhamentos pendentes.
  static Future<void> cancelarAcompanhamentosDeRemedio() async {
    try {
      await init();
      final pendentes = await _plugin.pendingNotificationRequests();
      for (final p in pendentes) {
        if (p.payload == payloadAcompanhamentoRemedio) await _plugin.cancel(p.id);
      }
    } catch (_) {}
  }

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
      case 'Melhor Idade':
        // Sessão 25: este canal existia mas nunca era usado (todo lembrete
        // saía no canal comum). Agora é. Canal novo no aparelho, então a
        // vibração definida aqui vale (Android não deixa mudar canal já
        // criado). fullScreenIntent só tem efeito com a permissão
        // USE_FULL_SCREEN_INTENT no manifest, que hoje NÃO está declarada
        // (restrita pela Play Store a apps de alarme/chamada).
        return AndroidNotificationDetails(
          'me_lembra_ai_idoso',
          'Lembretes (Idoso)',
          channelDescription: 'Notificações reforçadas para o perfil idoso',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
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

    // App aberto do zero por um toque no acompanhamento de remédio: o
    // callback acima não roda nesse caso — guarda o pedido pra tela
    // Melhor Idade abrir a Molly quando montar.
    try {
      final lancamento = await _plugin.getNotificationAppLaunchDetails();
      if ((lancamento?.didNotificationLaunchApp ?? false) &&
          lancamento?.notificationResponse?.payload == payloadAcompanhamentoRemedio) {
        _abrirMollyPendente = true;
      }
    } catch (_) {}

    _initialized = true;
  }

  /// Quando o usuário toca na notificação, anuncia por voz se o perfil for Idoso.
  static Future<void> _onNotificationTap(NotificationResponse response) async {
    final perfil = await ProfileService.getProfile();
    if (perfil != 'Melhor Idade') return;

    final payload = response.payload ?? '';

    // TAREFA 23: acompanhamento de remédio → a tela Melhor Idade abre a
    // Molly, que pergunta "Você conseguiu tomar?" e ouve a resposta.
    if (payload == payloadAcompanhamentoRemedio) {
      _abrirMollyPendente = true;
      pedidosAbrirMolly.value++;
      return;
    }

    // TAREFA 13 do prompt mestre (briefing matinal): antes disso, tocar
    // na notificação das 8h fazia o app falar o payload cru capitalizado
    // — literalmente "Matinal!", já que o payload da notificação matinal
    // é a string fixa 'matinal', não um texto pensado pra ser falado.
    // Agora fala o briefing de verdade, com os lembretes reais do dia.
    if (payload == 'matinal') {
      final briefing = await MollyBriefingService.gerar();
      await VoiceService.speakAlert(briefing);
      return;
    }

    final callout = payload.trim().isNotEmpty
        ? (payload[0].toUpperCase() + payload.substring(1))
            .replaceAll(RegExp(r'[.!?]$'), '') +
            '!'
        : 'Você tem um lembrete!';
    await VoiceService.speakAlert(callout);
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
      if (perfil == 'Melhor Idade') {
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
    // `false` no "lembra de novo" da Molly — senão o próprio relembrete
    // ganharia outro acompanhamento (notificação demais).
    bool acompanharRemedio = true,
  }) async {
    await init();

    // Não agenda no passado
    if (scheduledDate.isBefore(DateTime.now())) return;

    if (acompanharRemedio) {
      await agendarAcompanhamentoRemedio(
        idLembrete: id,
        title: title,
        body: body,
        horarioLembrete: scheduledDate,
      );
    }

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // Canal conforme o perfil (Melhor Idade: reforçado; Filhos: leve).
    final androidDetails = await _androidDetailsForProfile();

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
      NotificationDetails(android: androidDetails, iOS: iosDetails),
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
    // Lembrete apagado/editado: o acompanhamento de remédio vai junto.
    await _plugin.cancel(idAcompanhamento(id));
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
    // TAREFA 24 (Configurações da Molly): "Briefing diário: NÃO" cancela o
    // agendamento em vez de criar — chamar de novo após ligar reagenda.
    if (!await SettingsService.getBriefingDiario()) {
      await _plugin.cancel(id);
      return;
    }
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

  /// Exibe alerta SOS de alta prioridade com canal dedicado.
  ///
  /// Usa `fullScreenIntent` para aparecer mesmo com a tela bloqueada
  /// e padrão de vibração intenso para garantir a atenção do familiar.
  /// [sosNumero] é armazenado no payload para que o familiar possa
  /// ligar de volta ao tocar na notificação.
  static Future<void> showSosAlert({
    required int id,
    required String nome,
    required String motivo,
    String? lat,
    String? lng,
    String? sosNumero,
  }) async {
    await init();

    final loc = (lat != null && lng != null) ? '$lat, $lng' : 'sem localização';
    final bodyText = '${motivo.trim().isEmpty ? 'Acionamento manual' : motivo} · $loc';

    final androidDetails = AndroidNotificationDetails(
      'sos_alert',
      'Alerta SOS',
      channelDescription: 'Alertas de emergência SOS dos familiares monitorados',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      fullScreenIntent: true,
      icon: '@mipmap/ic_launcher',
      autoCancel: false,
      ongoing: false,
      ticker: 'SOS de $nome',
    );

    await _plugin.show(
      id,
      'SOS de $nome',
      bodyText,
      NotificationDetails(android: androidDetails),
      payload: 'sos:${sosNumero ?? ''}',
    );
  }
}
