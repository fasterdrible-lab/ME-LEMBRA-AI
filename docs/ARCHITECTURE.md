# ARCHITECTURE.md — Me Lembra Aí

> Última atualização: 2026-08-26 (sessão 23)

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

### `users/{uid}/molly_memory/{memId}`
```json
{
  "type": "string (ex.: nome_preferido, horario_almoco, rotinas...)",
  "value": "string",
  "source": "string (ex.: conversa, configuracoes)",
  "confidence": "number (0.0–1.0)",
  "userApproved": "bool",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```
Memória de longo prazo da MOLLY (TAREFA 8). **Privada ao dono** —
diferente de `reminders`, a regra do Firestore não dá acesso de leitura à
família (ver `firestore.rules`). `LongTermMemoryService.salvar()` recusa
gravar sem `userApproved: true` explícito **e** sem
`SettingsService.getMollyMemoriaAutorizada()` (interruptor geral, padrão
`false`) — nunca escreve por padrão.

> **SharedPreferences (local):** `cfg_molly_memoria_autorizada` (bool,
> padrão `false`) — "A MOLLY pode lembrar minhas preferências?" (TAREFA 9).

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
  "senderUid": "string",
  "text": "string | null",
  "audioUrl": "string | null",
  "durationMs": "number | null",
  "type": "text | audio",
  "sentAt": "timestamp"
}
```
`chatId` = as duas UIDs ordenadas e unidas por `_`
(`ChatService.pairId()`: `sorted([a,b]).join('_')`). Exclusão:
`firestore.rules` permite `delete` só quando `senderUid` da mensagem é o
próprio usuário (long-press na bolha em `chat_screen.dart`).
> **Correção (sessão 22):** este schema estava desatualizado (documentava
> `senderId`/`createdAt`, mas o código sempre usou `senderUid`/`sentAt`)
> — corrigido pra bater com `lib/services/chat_service.dart`.

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

### Foreground Service (Modo Proteção) + detector de queda em segundo plano

```
Usuário ativa "Modo Proteção" na ConfigScreen:
  SosProtectionService.start()
    └─ MethodChannel "protection" → SosProtectionService.kt.start(context)
         └─ startForeground(9001, notification(PRIORITY_LOW, ONGOING))
              └─ onStartCommand → startHeadlessFlutterIfNeeded()
                   └─ FlutterEngine(applicationContext) [engine NOVO, headless]
                        ├─ executeDartEntrypoint("fallDetectorEntrypoint")
                        │    └─ lib/main.dart: Firebase.initializeApp() +
                        │         FallDetectorService.start()
                        └─ CallChannel.register(engine, context)
                             (mesmo canal "com.melembra.ai/call" do MainActivity,
                              extraído pra CallChannel.kt — reaproveitado aqui)

main() ao reiniciar:
  SosProtectionService.restoreIfEnabled()
    └─ SharedPreferences: cfg_modo_protecao == true → start()
```

> **Sessão 22 — por que precisou de um engine separado**: o Foreground
> Service nativo, sozinho, mantém o *processo* Android vivo, mas
> `MainActivity` usa o ciclo de vida padrão do `FlutterActivity`
> (`shouldDestroyEngineWithHost` implícito `true`) — o `FlutterEngine`
> ligado à Activity, e todo o Dart rodando nele (`FallDetectorService`,
> `SosListenerService`), é destruído junto com a Activity quando o app é
> fechado. O Foreground Service, sozinho, **não mantinha nenhum código
> Dart vivo**, apesar do comentário antigo no código dizer o contrário.
> Por isso `SosProtectionService.kt` agora cria seu próprio
> `FlutterEngine` headless (via `DartExecutor.executeDartEntrypoint`,
> API moderna que dispensa `Application` customizada ou plugin de
> terceiros como `workmanager`) — é esse engine separado que mantém o
> detector de queda rodando de verdade com o app fechado.
>
> Uma queda detectada nesse caminho dispara `SosService.trigger()`
> **direto, sem a tela de confirmação/cancelamento de 5s** do fluxo em
> primeiro plano (`_acionarSOS()` em `elderly_screen.dart`) — não há
> `BuildContext`/`Navigator` num engine headless pra mostrar diálogo.
>
> **SOS por 5 toques de volume não se beneficia disso**: captura de tecla
> física (`onKeyDown`) exige uma Activity em primeiro plano com foco de
> janela, o que nenhum engine em segundo plano resolve — só Accessibility
> Service resolveria, e essa decisão continua sendo não implementar.
>
> **Fora de escopo, lacuna conhecida**: `SosListenerService` (o listener
> Firestore que avisa o cuidador de um SOS de um familiar monitorado)
> tem exatamente o mesmo problema de hoje (`StreamSubscription` presa ao
> engine da Activity) e não foi corrigido nesta sessão.

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

Usuário toca o botão de microfone (1º toque):
  GestureDetector.onTap → _startRecording()
    ├─ recorder.hasPermission()
    ├─ recorder.start(RecordConfig(aacLc), path: tmp/audio_TIMESTAMP.m4a)
    └─ Timer periódico: atualiza _recordingDuration a cada 1 s

Usuário toca o botão de novo (2º toque):
  GestureDetector.onTap → _stopAndSend()
    ├─ recorder.stop() → path do arquivo
    ├─ ChatService.sendAudio(member.uid, file, durationMs)
    │    └─ Firebase Storage → audioUrl
    │    └─ Firestore: messages.add({ type: 'audio', audioUrl, durationMs })
    └─ Deleta arquivo temporário
```

> Até a sessão 20 o gesto era "segurar para gravar / soltar para enviar"
> (`onLongPressStart`/`onLongPressEnd`). Trocado para toque único na sessão
> 21 (TASK-31) — o gesto de segurar exigia precisão demais pro público do
> app (idosos/família): soltar o dedo cedo demais gerava áudios de duração
> quase zero, e o usuário percebia isso como "não grava".

### Comando de voz (Falar Comando) — assistente conversacional multi-turno

Desde a sessão 21, "Falar Comando" não é mais de uma tacada só: o mesmo
ponto de entrada (`_processarComando`) é chamado repetidamente, deixando o
microfone reabrir sozinho ao final de cada turno, até a conversa terminar
por frase de encerramento, silêncio, ou o limite de 6 turnos. Isso garante
que a checagem de SOCORRO e as regras locais continuem tendo prioridade
máxima em **todo** turno, não só no primeiro.

```
Usuário toca "Falar Comando" (ou já está no meio de uma conversa):
  _iniciarEscuta() → STT (speech_to_text) → _finalizarComando() → _processarComando(texto)
    ├─ "SOCORRO" a qualquer momento → SEMPRE local, prioridade máxima →
    │    _encerrarConversa() + _acionarSOS()
    ├─ frase de encerramento ("obrigado"/"pode parar"/...) → local, fala
    │    "Até logo!", _encerrarConversa(), para de escutar
    ├─ regras locais rápidas (ouvir lembretes / alertas / adicionar na lista)
    │    → resolve na hora, sem rede
    ├─ já em modo "coletando lembrete" (_coletandoLembrete == true)?
    │    → _mesclarSlots(texto): extrai dia/hora localmente e
    │      determinística (_extrairData/_extrairHora), NUNCA chama a IA
    │      de novo neste modo → _finalizarOuPerguntarProximoCampo()
    └─ qualquer outra frase (1ª vez desta conversa que cai aqui):
         _lembretesParaContextoIA() → resumo leve dos lembretes reais
           (título/tipo/data-hora; itens da lista quando for tipo Compras)
         AiCommandService.interpretar(texto, historico, lembretesContexto)
           ├─ POST https://<dominio>/interpretar-comando
           │    Authorization: Bearer <Firebase ID token>
           │    body: { texto, contexto: { agora, lembretes }, historico }
           │    (timeout 6s; historico = últimas 3 trocas da conversa)
           ├─ backend (server/ai_command_server/, na VPS):
           │    ├─ verifica o ID token (firebase_admin.auth)
           │    └─ chama a Groq (GROQ_MODEL, hoje openai/gpt-oss-20b;
           │         temperature=0.2) com system prompt + histórico +
           │         contexto real → JSON estruturado
           │         (ações: criar_lembrete | ouvir_lembretes |
           │          adicionar_item_lista | consultar_alertas |
           │          perguntar | responder)
           ├─ acao == 'perguntar' → NÃO fala a pergunta da IA; entra em
           │    modo de coleta local (_coletandoLembrete = true),
           │    _mesclarSlots(_primeiroTextoConversa) e
           │    _finalizarOuPerguntarProximoCampo() decide o que perguntar
           │    (só dia/hora, com fala própria, local)
           ├─ outra ação com sucesso → _executarAcaoIA(acao) despacha pro
           │    handler certo; turno acrescentado ao histórico (máx. 3)
           └─ falha/timeout/sem internet → retorna null →
                cai no parser local de sempre (_criarLembreteDoTexto)

Ao final de cada turno (se a conversa não foi encerrada):
  turnosConversa++; se >= 6 → avisa e _encerrarConversa(); senão →
  _iniciarEscuta() de novo, sem precisar tocar o botão.
```

> **Sessão 22 (parte 2) — por que a coleta de dia/hora saiu da IA**: em
> testes ao vivo, a IA (`openai/gpt-oss-20b`) repetidamente "esquecia"
> dado já informado em turnos anteriores (perguntava tipo depois do
> usuário já ter dito, não reconhecia "15" como resposta a "que horas?",
> repetia a mesma pergunta) — mesmo recebendo o histórico da conversa a
> cada chamada. Pesquisa confirmou que isso é um padrão conhecido do
> mercado: Rasa (framework de chatbot mais usado) usa um extrator
> determinístico (Duckling) pra data/hora dentro de "Forms", não o
> modelo de linguagem; a própria OpenAI recomenda, pra function calling
> multi-turno, não depender do modelo lembrar dado que o código já sabe
> ("offload the burden from the model and use code where possible").
> Por isso: a partir do primeiro `perguntar` da IA, a conversa entra em
> modo de coleta 100% local — `_extrairData`/`_extrairHora` (novos,
> nullable — diferente de `_parsearDataHora`, que sempre assume "agora"
> quando não acha nada) extraem dia/hora turno a turno sem nenhuma
> chamada de IA adicional; título/tipo/recorrência continuam vindo do
> parser local de sempre (`_limparTitulo`/`_inferirTipo`/
> `_inferirRecorrencia`, aplicados sobre `_primeiroTextoConversa`).

**Guardrails contra alucinação**: ação `perguntar` (pede esclarecimento em
vez de inventar dado faltante — mas a extração de dia/hora em si agora é
local e determinística, não mais responsabilidade da IA); grounding real
via `contexto.lembretes` (a IA só pode falar sobre lembretes que de fato
existem); histórico limitado (custo/deriva); enum de ações fechado e
validado no servidor (`ACOES_VALIDAS`); regra explícita no prompt contra
inventar lembretes/alertas/SOS fora do contexto fornecido. Sem
exclusão/edição de lembretes por voz (fora de escopo).

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
      elderly_screen.dart            # tela principal do idoso (ainda com
                                      # o "Falar Comando" original — ver
                                      # features/molly/ abaixo)
      meus_lembretes_screen.dart
    molly/                           # em construção (sessão 23) — ver
                                      # docs/MOLLY_ARCHITECTURE_ANALYSIS.md
      screens/
        molly_screen.dart            # tela principal (TAREFA 6) — rota
                                      # /molly, aditiva, sem navegação
                                      # apontando pra ela ainda
        molly_memory_screen.dart     # "O que a Molly lembra" (TAREFA 9) —
                                      # rota /molly-memory, idem aditiva
      widgets/
        listening_indicator.dart     # "Estou ouvindo"/"Pensando"/"Falando"
      memory/
        short_term_memory.dart       # ShortTermMemory (TAREFA 7) — histórico
                                      # de trocas (p/ IA) + slots dia/hora
                                      # (fora do histórico da IA, de propósito)
        long_term_memory.dart        # LongTermMemoryService (TAREFA 8) —
                                      # users/{uid}/molly_memory, nunca grava
                                      # sem userApproved + opt-in geral
      models/
        molly_memory_entry.dart      # type/value/source/createdAt/updatedAt/
                                      # confidence/userApproved
        molly_user_context.dart      # retrato controlado do usuário (TAREFA 10)
        molly_intent.dart            # MollyIntentHints — sinal local de
                                      # "parece pedido de lembrete" (TAREFA 14)
                                      # e "parece buscar companhia" (TAREFA 15);
                                      # não ligado a nenhuma decisão ainda
        molly_message.dart           # mensagem de conversa (autor/texto)
        molly_tool_result.dart       # resultado de um turno, sem TTS embutido
        molly_risk_level.dart        # enum LOW/MEDIUM/CRITICAL (metadado)
        molly_tool_definition.dart   # nome/descrição/parâmetros/risco/executar
      services/
        molly_agent_service.dart     # núcleo: texto -> AiCommandService ->
                                      # despacha para MollyRiskPolicy ou
                                      # métodos internos. Sem estado, nunca
                                      # acessa Firestore direto.
        molly_tool_registry.dart     # catálogo de ferramentas (TAREFA 3)
        molly_risk_policy.dart       # LOW roda direto; MEDIUM roda direto
                                      # exceto se ambíguo; CRITICAL sempre
                                      # confirma exceto emergência
                                      # autorizada (TAREFA 4)
        molly_context_service.dart   # MollyContextService (TAREFA 10) —
                                      # agrega nome/perfil/lembretes/
                                      # familiares/config/preferências/
                                      # conversa; só lembretesParaIA vai à IA
        molly_prompt_service.dart    # Personalidade (TAREFA 11) — descrição
                                      # formal + contemLinguagemTecnica();
                                      # respostas curtas (TAREFA 12) —
                                      # resumoCurto<T>() (1-3 frases, nunca
                                      # item por item)
        molly_briefing_service.dart  # Briefing matinal (TAREFA 13) — fala
                                      # real com os lembretes do dia; usado
                                      # por notification_service.dart ao
                                      # tocar a notificação das 8h
                                      #
                                      # (TAREFA 15: modoCompanhia — regras
                                      # de tom/guardrail — mora em
                                      # molly_prompt_service.dart, acima)
        wake_word_service.dart       # WakeWordService (TAREFA 16) — só
                                      # abstração + stub indisponível;
                                      # pesquisa de Picovoice Porcupine
                                      # documentada no arquivo. Sem
                                      # dependência nativa nova
        offline_intent_service.dart  # OfflineIntentService (TAREFA 17) —
                                      # socorro/meus lembretes/ligar para X/
                                      # que horas/confirmar remédio, sem IA.
                                      # LIGADO de verdade: MollyAgentService
                                      # chama isso antes de qualquer IA.
                                      # TAREFA 18: + possivelEmergencia
                                      # (frases suaves — confirmação visual
                                      # com contagem, não disparo direto)
        molly_voice_service.dart     # STT+TTS (TAREFA 5) — única classe
                                      # instanciável da MOLLY; estados
                                      # idle/listening/thinking/speaking/
                                      # error via ValueNotifier. Detecção
                                      # de "SOCORRO" NÃO mora aqui.
      tools/
        reminder_tool.dart           # createReminder/get{Today,Tomorrow}
                                      # Reminders/updateReminder/deleteReminder/
                                      # confirmReminder/getReminderHistory
        family_tool.dart             # getFamilyMembers/sendFamilyMessage/
                                      # callFamilyMember (chat, não disca — sem
                                      # telefone por familiar, ver análise)
        location_tool.dart           # getCurrentLocation
        profile_tool.dart            # getUserProfile
        molly_fala_utils.dart        # horaFalada() compartilhado
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
      CallChannel.kt                 # canal "call", compartilhado com o engine headless
      SosProtectionService.kt        # Foreground Service + FlutterEngine headless (detector de queda)
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
    melembra-ai-backend.service      # unit systemd (gunicorn na porta 8091)
    nginx-api.conf                   # proxy reverso api.melbrai.com.br

test/
  login_screen_test.dart             # 6 widget tests
  create_reminder_screen_test.dart   # 9 widget tests
  profile_selection_screen_test.dart # regressão BUG-001 (FcmService.init() no fluxo de perfil)
  reminder_service_test.dart         # 6 testes falhando desde abril/2026, pré-existente
  molly_risk_policy_test.dart        # 4 testes da TAREFA 4 (política de risco), sem mocks de Firebase
  molly_screen_test.dart             # 4 testes de estrutura da TAREFA 6, sem tocar o microfone
  molly_prompt_service_test.dart     # 8 testes das TAREFAs 11/12, 100% puro Dart
  molly_briefing_service_test.dart   # 5 testes da TAREFA 13, 100% puro Dart
  molly_intent_test.dart             # testes das TAREFAs 14/15, 100% puro Dart
  wake_word_service_test.dart        # 4 testes da TAREFA 16, 100% puro Dart
  offline_intent_service_test.dart   # 13 testes das TAREFAs 17/18, 100% puro Dart
  short_term_memory_test.dart        # 6 testes da TAREFA 7, 100% puro Dart
  molly_memory_screen_test.dart      # 4 testes da TAREFA 9, incluindo o interruptor de ponta a ponta
  support/
    firebase_core_mocks.dart         # mocks do Firebase Core p/ testes de widget

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
