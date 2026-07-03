# ARCHITECTURE.md — Me Lembra Aí

> Última atualização: 2026-06-01 (sessão 12)

---

## Visão geral do sistema

```
┌─────────────────────────────────────────────────────────────┐
│                  App Flutter (Android)                      │
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ ElderlyScr  │  │  FamilyScr   │  │    MapScreen     │   │
│  │ AdultScr    │  │  ChatScreen  │  │  ConfigScreen    │   │
│  │ ChildScr    │  │  MonitorScr  │  │  HistoryScreen   │   │
│  └──────┬──────┘  └──────┬───────┘  └────────┬─────────┘   │
│         │                │                   │              │
│  ┌──────▼────────────────▼───────────────────▼──────────┐  │
│  │                   Serviços Flutter                    │  │
│  │  SosService · NotificationService · FcmService       │  │
│  │  SosListenerService · SosProtectionService           │  │
│  │  VolumeSosService · LocationService · VoiceService   │  │
│  │  ChatService · ReminderService · FamilyService       │  │
│  │  FallDetectorService · SettingsService               │  │
│  └──────┬────────────────────────────────────────────┬──┘  │
│         │  MethodChannel / EventChannel              │      │
│  ┌──────▼────────────────┐           ┌───────────────▼──┐  │
│  │    MainActivity.kt    │           │  Firebase SDK    │  │
│  │  ─ /widget            │           │  (Auth/Firestore/ │  │
│  │  ─ /call              │           │   Storage/FCM)   │  │
│  │  ─ /protection        │           └──────────────────┘  │
│  │  ─ /volume_sos_control│                                  │
│  │  ─ /volume_sos_events │                                  │
│  └──────┬────────────────┘                                  │
│         │                                                    │
│  ┌──────▼────────────────────────────────────────────────┐  │
│  │  SosProtectionService.kt  │  RemindersWidget.kt       │  │
│  │  (Foreground Service)     │  (AppWidget)              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                            │
         ▼                            ▼
┌─────────────────┐       ┌───────────────────────┐
│  Firebase Cloud │       │   VPS Hetzner          │
│  (Auth/Firestore│       │   204.168.180.25       │
│   Storage/FCM)  │       │   sos_notifier.py      │
└─────────────────┘       │   (firebase-admin)     │
                          └───────────────────────┘
```

---

## MethodChannels e EventChannels (Flutter ↔ Android)

| Canal | Tipo | Método / Evento | Ação nativa |
|---|---|---|---|
| `com.melembra.ai/widget` | MethodChannel | `updateWidget` | `RemindersWidget.updateAll()` |
| `com.melembra.ai/call` | MethodChannel | `callNumber(String)` | `Intent.ACTION_CALL tel:NUMERO` |
| `com.melembra.ai/protection` | MethodChannel | `start` / `stop` | `SosProtectionService.start/stop()` |
| `com.melembra.ai/volume_sos_control` | MethodChannel | `enable` / `disable` | Liga/desliga captura de volume em `onKeyDown` |
| `com.melembra.ai/volume_sos_events` | EventChannel | `"sos"` (stream) | Emitido quando 5 × volume em ≤ 3 s |

---

## Canais de notificação Android

| Canal ID | Nome | Prioridade | fullScreen | Vibração | Uso |
|---|---|---|---|---|---|
| `me_lembra_ai_channel` | Lembretes | HIGH | Não | Sim | Lembretes gerais do usuário |
| `me_lembra_ai_idoso` | Lembretes (Idoso) | MAX | **Sim** | Intensa | Lembretes do perfil idoso |
| `me_lembra_ai_crianca` | Lembretes (Criança) | HIGH | Não | Não | Lembretes do perfil criança |
| `me_lembra_ai_matinal` | Resumo Matinal | HIGH | Não | Sim | Briefing diário às 8h |
| `sos_alert` | **Alerta SOS** | **MAX** | **Sim** | Padrão intenso | Alerta SOS no familiar |
| `sos_protection` | Modo Proteção | LOW | Não | Não | Notificação persistente do Foreground Service |

---

## Estrutura do Firestore

### `users/{uid}`
```json
{
  "perfil": "Vovô / Vovó | Adulto | Filhos | Família",
  "nome": "string",
  "inviteCode": "string (6 chars)",
  "fcmToken": "string",
  "fcmUpdatedAt": "timestamp"
}
```

### `users/{uid}/vehicles/{vehicleId}`
```json
{
  "userId": "string",
  "apelido": "string",
  "placa": "string",
  "kmAtual": "number | null",
  "kmProximaTroca": "number | null",
  "dataUltimaTroca": "timestamp | null",
  "anoIpva": "number | null",
  "valorIpva": "number | null",
  "vencimentoIpva": "timestamp | null",
  "parcelasIpva": "[{parcela, valor, vencimento, pago}]",
  "vencimentoCnh": "timestamp | null",
  "vencimentoSeguro": "timestamp | null",
  "valorSeguro": "number | null",
  "parcelasSeguro": "[{parcela, valor, vencimento, pago}]",
  "updatedAt": "timestamp"
}
```

> **SharedPreferences (local):** contatos SOS armazenados como `cfg_sos_numeros` (`List<String>`, até 3 números). Campo legado `cfg_sos_numero` é migrado automaticamente na primeira leitura.

### `users/{uid}/family/{otherUid}`
```json
{
  "nome": "string",
  "perfil": "string",
  "papel": "monitorado | cuidador",
  "vinculadoEm": "timestamp"
}
```
- **monitorado**: dono do código de convite (idoso / criança)
- **cuidador**: quem usou o código (familiar adulto)
- Vínculo **bilateral**: ambos os lados têm documento

### `users/{uid}/reminders/{reminderId}`
```json
{
  "userId": "string",
  "title": "string",
  "type": "Remédio | Consulta | Aniversário | Mercado | Reunião | Tomar | Compras | Lembrete",
  "description": "string",
  "dateTime": "timestamp",
  "repeat": "unico | diario | semanal",
  "notification": "string",
  "perfil": "string",
  "confirmed": "bool"
}
```

### `invites/{code}`
```json
{
  "uid": "string",
  "nome": "string",
  "perfil": "string",
  "createdAt": "timestamp"
}
```
Permite leitura do convite sem acesso direto a `users/{uid}`.

### `sos_alerts/{alertId}`
```json
{
  "userId": "string",
  "perfil": "string",
  "nome": "string",
  "motivo": "manual | queda | voz | volume",
  "latitude": "number | null",
  "longitude": "number | null",
  "erroLocalizacao": "string | null",
  "createdAt": "timestamp"
}
```

### `chats/{chatId}/messages/{msgId}`
```json
{
  "senderId": "string",
  "text": "string | null",
  "audioUrl": "string | null",
  "durationMs": "number | null",
  "type": "text | audio",
  "createdAt": "timestamp"
}
```
`chatId` = concatenação ordenada dos dois UIDs (garantido por `ChatService`).

---

## Fluxos principais

### Inicialização do app

```
main()
  ├─ Firebase.initializeApp()
  ├─ NotificationService.init()
  ├─ SharedPreferences: onboarding_visto?
  ├─ SettingsService.getModoEscuro() → aplica ThemeMode
  ├─ SosProtectionService.restoreIfEnabled()  ← restaura Foreground Service
  ├─ VolumeSosService.restoreIfEnabled()       ← restaura captura de volume
  └─ runApp(MeLembraApp)
       └─ StreamBuilder<User?> (Firebase Auth)
            ├─ logado → SosListenerService.start() → HomeScreen
            └─ deslogado → OnboardingScreen | LoginScreen
```

### Autenticação

```
Primeiro acesso:
  OnboardingScreen → (conclusão) → LoginScreen

Login:
  LoginScreen.signIn() → ProfileSelectionScreen
    └─ salva perfil em Firestore + SharedPreferences
         └─ navega para /elderly | /adult | /child | /family
              └─ HomeScreen.initState() → FcmService.init()
                   ├─ requestPermission()
                   ├─ getToken() → users/{uid}/fcmToken
                   └─ onTokenRefresh listener
```

### Pipeline SOS completo

```
Acionamento (botão, voz "SOCORRO", detector de queda, 5× volume):
  elderly_screen._acionarSOS()
    ├─ Dialog countdown 5 s (cancelável)
    └─ Se não cancelado:
         VoiceService.speak('Emergência!')
         SosService.trigger(motivo)
           ├─ 1. LocationService.getCurrentPosition() → lat/lng
           ├─ 2. Firestore: sos_alerts.add({ userId, nome, motivo, lat, lng, ... })
           ├─ 3. ChatService.send() para cada cuidador vinculado
           └─ 4. SosService._triggerCall()  ← chama o 1º número da lista
                  ├─ SettingsService.getSosNumero() → primeiro de getSosNumeros()
                  ├─ _paraE164() → normaliza para +55... (obrigatório: sem o
                  │    código do país a operadora rejeita a chamada VoLTE)
                  ├─ Permission.phone.request()
                  ├─ CONCEDIDA → MethodChannel "call" → TelecomManager.placeCall()
                  └─ NEGADA    → url_launcher tel: (abre discador)
         Se getSosNumeros().length > 1:
           Dialog "Contatos adicionais" com botão por número extra
             └─ SosService.callNumber(n) → mesmo fluxo de chamada

No familiar com app em foreground/background recente:
  SosListenerService._onSnapshot()
    └─ NotificationService.showSosAlert()
         └─ Canal "sos_alert": Importance.MAX + fullScreenIntent + vibração

No familiar com app encerrado (via VPS):
  sos_notifier.py on_snapshot()
    ├─ Busca cuidadores: users/{userId}/family (papel == 'cuidador')
    ├─ Lê users/{cuidadorUid}/fcmToken
    └─ messaging.send(Message(
           android=AndroidConfig(priority="high",
                                 channel_id="sos_alert",
                                 notification_priority=MAX),
           data={"type": "sos", "nome": ..., "motivo": ...}
       ))
```

### Foreground Service (Modo Proteção)

```
Usuário ativa "Modo Proteção" na ConfigScreen:
  SosProtectionService.start()
    └─ MethodChannel "protection" → SosProtectionService.kt.start(context)
         └─ startForeground(9001, notification(PRIORITY_LOW, ONGOING))
              → processo Flutter permanece vivo indefinidamente

main() ao reiniciar:
  SosProtectionService.restoreIfEnabled()
    └─ SharedPreferences: cfg_modo_protecao == true → start()
```

### SOS por Teclas de Volume

```
Usuário ativa "SOS por Teclas" na ConfigScreen:
  VolumeSosService.start()
    ├─ MethodChannel "volume_sos_control".enable()
    │    → volumeSosEnabled = true na MainActivity
    └─ EventChannel "volume_sos_events".receiveBroadcastStream().listen()

Usuário pressiona volume 5× em ≤ 3 s (app em foreground):
  MainActivity.onKeyDown()
    ├─ Registra timestamp
    ├─ Remove timestamps fora da janela de 3 000 ms
    └─ count ≥ 5 → EventSink.success("sos") → VolumeSosService
         └─ SosService.trigger(motivo: 'volume')
```

### Chat de Áudio

```
Botão único (mic ↔ enviar): mostra mic quando o campo está vazio,
vira ícone de enviar assim que há texto digitado.

Usuário segura botão de microfone:
  GestureDetector.onLongPressStart → _startRecording()
    ├─ recorder.hasPermission()
    ├─ recorder.start(RecordConfig(aacLc), path: tmp/audio_TIMESTAMP.m4a)
    └─ Timer periódico: atualiza _recordingDuration a cada 1 s

Usuário solta o botão:
  GestureDetector.onLongPressEnd → _stopAndSend()
    ├─ recorder.stop() → path do arquivo
    ├─ ChatService.sendAudio(member.uid, file, durationMs)
    │    └─ Firebase Storage → audioUrl
    │    └─ Firestore: messages.add({ type: 'audio', audioUrl, durationMs })
    └─ Deleta arquivo temporário
```

### Comando de voz (Falar Comando)

```
Usuário toca "Falar Comando" e fala:
  _falarComando() → STT (speech_to_text) → _processarComando(texto)
    ├─ "SOCORRO" a qualquer momento → SEMPRE local, prioridade máxima → _acionarSOS()
    ├─ regras locais rápidas (ouvir lembretes / alertas / adicionar na lista)
    │    → resolve na hora, sem rede
    └─ qualquer outra frase:
         AiCommandService.interpretar(texto)
           ├─ POST https://<dominio>/interpretar-comando
           │    Authorization: Bearer <Firebase ID token>
           │    (timeout 6s)
           ├─ backend (server/ai_command_server/, na VPS):
           │    ├─ verifica o ID token (firebase_admin.auth)
           │    └─ chama a Groq (llama-3.3-70b-versatile) → JSON estruturado
           ├─ sucesso → _executarAcaoIA(acao) despacha pro handler certo
           └─ falha/timeout/sem internet → retorna null →
                cai no parser local de sempre (_criarLembreteDoTexto)
```

### Widget Android

```
ReminderService.stream() emite lista de lembretes
  └─ WidgetService.update(list)
       ├─ Filtra lembretes do dia corrente
       ├─ Serializa em JSON
       ├─ SharedPreferences.setString('widget_reminders', json)
       └─ MethodChannel "widget".invokeMethod("updateWidget")
            └─ MainActivity → RemindersWidget.updateAll(context)
                 └─ Lê 'flutter.widget_reminders' → popula RemoteViews
```

---

## Permissões Android declaradas

| Permissão | Uso |
|---|---|
| `RECEIVE_BOOT_COMPLETED` | Re-agendar notificações após reinício |
| `VIBRATE` | Vibração nas notificações |
| `USE_EXACT_ALARM` | Notificações em horário exato (Android 12+) |
| `SCHEDULE_EXACT_ALARM` | Notificações exatas (Android ≤ 12) |
| `POST_NOTIFICATIONS` | Notificações no Android 13+ |
| `ACCESS_FINE_LOCATION` | GPS de alta precisão |
| `ACCESS_COARSE_LOCATION` | GPS aproximado (fallback) |
| `ACCESS_BACKGROUND_LOCATION` | Localização em background |
| `RECORD_AUDIO` | Gravação de áudio no chat |
| `INTERNET` | Firebase, FCM, Maps |
| `CALL_PHONE` | Ligação direta (ACTION_CALL) no SOS |
| `FOREGROUND_SERVICE` | Foreground Service geral |
| `FOREGROUND_SERVICE_LOCATION` | Foreground Service com localização |
| `FOREGROUND_SERVICE_DATA_SYNC` | Foreground Service de sincronização (SosProtectionService) |

---

## Estrutura de pastas

```
lib/
  main.dart                          # Entrada, rotas, temas, init de serviços
  login_screen.dart
  register_screen.dart
  home_screen.dart
  profile_selection_screen.dart
  onboarding_screen.dart
  config_screen.dart
  history_screen.dart
  reminders_screen.dart
  create_reminder_screen.dart
  edit_reminder_screen.dart
  categories_screen.dart
  elderly_screen.dart                # (versão legada — usar features/elderly/)

  models/
    reminder.dart
    family_member.dart
    sos_alert.dart
    vehicle.dart

  services/
    chat_service.dart
    fall_detector_service.dart
    fcm_service.dart
    family_service.dart
    location_service.dart
    notification_service.dart        # canais, scheduleReminder, showSosAlert
    profile_service.dart
    reminder_service.dart
    settings_service.dart            # todas as prefs locais
    smart_suggestions_service.dart
    sos_feed_service.dart
    sos_listener_service.dart        # stream Firestore de SOS do familiar
    sos_protection_service.dart      # start/stop Foreground Service
    sos_service.dart                 # trigger: Firestore + chat + ligação
    vehicle_service.dart
    voice_service.dart
    volume_sos_service.dart          # 5× volume → SOS
    widget_service.dart

  features/
    adult/
      adult_screen.dart
    child/
      child_screen.dart
      child_monitor_screen.dart
    elderly/
      elderly_screen.dart            # tela principal do idoso
      meus_lembretes_screen.dart
    family/
      family_screen.dart
      chat_screen.dart               # chat texto + áudio long-press
      family_contact_sheet.dart
      monitor_screen.dart
    maps/
      map_screen.dart                # GoogleMap + localização atual + FAB SOS
    onboarding/
      onboarding_screen.dart
    vehicle/
      vehicle_screen.dart
      add_edit_vehicle_screen.dart

  firebase_options.dart              # gerado pelo FlutterFire CLI

android/
  app/src/main/
    AndroidManifest.xml              # permissões, receivers, services, API key Maps
    kotlin/com/melembra/ai/
      MainActivity.kt                # 5 channels: widget, call, protection, vol_control, vol_events
      SosProtectionService.kt        # Foreground Service "Modo proteção ativo"
      RemindersWidget.kt             # AppWidget de lembretes
    res/
      xml/widget_info.xml
      layout/widget_reminders.xml
      values/strings.xml
  app/proguard-rules.pro             # regras Gson/TypeToken para R8

server/
  sos_notifier.py                    # VPS: escuta Firestore → envia FCM push
  requirements.txt                   # firebase-admin
  sos-notifier.service               # unit systemd
  ai_command_server/                 # VPS: backend do comando de voz por IA
    app.py                           # Flask: POST /interpretar-comando (Groq)
    requirements.txt                 # flask, gunicorn, groq, firebase-admin
    .env.example                     # modelo do .env (GROQ_API_KEY) — não commitado
    melembra-ai-backend.service      # unit systemd (gunicorn na porta 8001)

test/
  login_screen_test.dart             # 6 widget tests
  create_reminder_screen_test.dart   # 9 widget tests

docs/
  ARCHITECTURE.md                    # este arquivo
  CURRENT_STATE.md                   # estado atual e histórico
  TASKS.md                           # backlog de tarefas
```

---

## VPS Hetzner

| Item | Valor |
|---|---|
| IP | `204.168.180.25` |
| OS | Ubuntu 22.04, 4 GB RAM |
| Região | Helsinki (hel1) |
| Usuário | `root` |
| Serviço SOS | `/root/sos_notifier/sos_notifier.py` |
| Systemd unit | `sos-notifier.service` |

### Credenciais Firebase no VPS
- Caminho: `/root/sos_notifier/serviceAccountKey.json`
- Obter em: Firebase Console → Configurações do projeto → Contas de serviço → Gerar nova chave privada
- **NUNCA commitar no git**

---

## Dependências críticas de build

| Arquivo | Motivo |
|---|---|
| `android/app/proguard-rules.pro` | Sem as regras Gson, o R8 quebra `TypeToken` no build release |
| `android/app/build.gradle.kts` | `compileSdk = 36`; assinatura via `key.properties` |
| `android/app/google-services.json` | Não está no git — baixar do Firebase Console antes de buildar |
| `android/AndroidManifest.xml` | `YOUR_GOOGLE_MAPS_API_KEY` deve ser substituído pela chave real |
