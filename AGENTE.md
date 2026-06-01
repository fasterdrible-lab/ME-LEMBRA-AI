# AGENTE.md — Me Lembra Aí

> Guia operacional para o agente de IA. Leia isto antes de qualquer sessão de trabalho.

---

## 1. O que o projeto faz e domínio de produção

**Me Lembra Aí** é um app Flutter de gestão de lembretes e saúde familiar com quatro perfis distintos:

- **Idoso (Vovô/Vovó):** interface simplificada, TTS, STT, briefing matinal por voz, botão SOS, detector de queda por acelerômetro.
- **Adulto:** dashboard com sugestões inteligentes de lembretes por heurística.
- **Criança/Filhos:** tarefas gamificadas com barra de progresso.
- **Família:** código de convite, monitoramento (feed SOS + adesão a lembretes), chat com áudio.

**Domínio de produção:** app Android (APK side-load, ainda não publicado na Play Store).
**Backend:** Firebase (Firestore + Auth + FCM + Storage) — plano Spark (gratuito).
**VPS Hetzner:** 204.168.180.25 — Ubuntu 4 GB RAM (Helsinki hel1) — usado para pipeline de build.

> ATENÇÃO: `google-services.json` NÃO está no git. Baixar em:
> https://console.firebase.google.com/project/me-lembra-ai-bf0f0/settings/general/android

---

## 2. Stack completa com versões

| Camada | Tecnologia | Versão |
|---|---|---|
| Framework | Flutter | SDK >=3.0.0 <4.0.0 |
| Linguagem | Dart | >=3.0.0 |
| App version | me_lembra_ai | 1.2.0+5 |
| Auth | firebase_auth | ^5.3.0 |
| Banco | cloud_firestore | ^5.4.0 |
| Push | firebase_messaging | ^15.1.0 |
| Core Firebase | firebase_core | ^3.6.0 |
| Storage | firebase_storage | ^12.3.0 |
| Notif. locais | flutter_local_notifications | ^17.2.2 |
| TTS | flutter_tts | ^4.0.2 |
| STT | speech_to_text | ^7.3.0 |
| GPS | geolocator | ^12.0.0 |
| Acelerômetro | sensors_plus | ^4.0.2 |
| Áudio record | record | ^6.0.0 |
| Áudio player | audioplayers | ^6.1.0 |
| Timezone | timezone | ^0.9.4 |
| Permissões | permission_handler | ^11.3.1 |
| Prefs locais | shared_preferences | ^2.2.2 |
| i18n | intl | ^0.19.0 |
| Ícones | flutter_launcher_icons | ^0.14.1 |
| minSdk Android | — | 23 |

---

## 3. Estrutura do projeto (Flutter monorepo)

```
me_lembra_ai/
├── lib/
│   ├── main.dart                         # Entrypoint; decide onboarding vs login
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── onboarding_screen.dart
│   ├── profile_selection_screen.dart
│   ├── home_screen.dart                  # Hub pós-login (idoso default)
│   ├── reminders_screen.dart
│   ├── create_reminder_screen.dart
│   ├── edit_reminder_screen.dart
│   ├── categories_screen.dart
│   ├── history_screen.dart
│   ├── config_screen.dart
│   ├── elderly_screen.dart               # Tela principal perfil Idoso
│   ├── models/
│   │   ├── reminder.dart
│   │   ├── family_member.dart
│   │   ├── sos_alert.dart
│   │   └── vehicle.dart
│   ├── services/
│   │   ├── reminder_service.dart
│   │   ├── notification_service.dart
│   │   ├── fcm_service.dart
│   │   ├── sos_service.dart
│   │   ├── sos_feed_service.dart
│   │   ├── sos_listener_service.dart
│   │   ├── fall_detector_service.dart
│   │   ├── location_service.dart
│   │   ├── voice_service.dart
│   │   ├── chat_service.dart
│   │   ├── smart_suggestions_service.dart
│   │   ├── family_service.dart
│   │   ├── profile_service.dart
│   │   ├── settings_service.dart
│   │   └── vehicle_service.dart
│   └── features/
│       ├── onboarding/onboarding_screen.dart
│       ├── elderly/
│       │   ├── elderly_screen.dart
│       │   └── meus_lembretes_screen.dart
│       ├── adult/adult_screen.dart
│       ├── child/
│       │   ├── child_screen.dart
│       │   └── child_monitor_screen.dart
│       ├── family/
│       │   ├── family_screen.dart
│       │   ├── monitor_screen.dart
│       │   ├── chat_screen.dart
│       │   └── family_contact_sheet.dart
│       └── vehicle/
│           ├── vehicle_screen.dart
│           └── add_edit_vehicle_screen.dart
├── android/
│   └── app/
│       ├── build.gradle.kts              # minSdk = 23
│       └── proguard-rules.pro            # Regras Gson/TypeToken para R8
├── assets/
│   ├── images/                           # LOGO.png, adultos.png, etc.
│   └── icon/app_icon.png
└── pubspec.yaml
```

Não há backend customizado — toda lógica server-side usa Firebase diretamente.

---

## 4. Rotas do frontend mapeadas

| Rota | Arquivo | Perfil |
|---|---|---|
| `/` (boot) | `main.dart` | Todos — decide onboarding vs login |
| `/onboarding` | `features/onboarding/onboarding_screen.dart` | Primeiro acesso |
| `/login` | `login_screen.dart` | Todos |
| `/register` | `register_screen.dart` | Todos |
| `/profile-selection` | `profile_selection_screen.dart` | Todos |
| `/home` | `home_screen.dart` | Idoso (default pós-login) |
| `/elderly` | `features/elderly/elderly_screen.dart` | Idoso |
| `/meus-lembretes` | `features/elderly/meus_lembretes_screen.dart` | Idoso |
| `/adult` | `features/adult/adult_screen.dart` | Adulto |
| `/child` | `features/child/child_screen.dart` | Criança |
| `/child-monitor` | `features/child/child_monitor_screen.dart` | Família |
| `/family` | `features/family/family_screen.dart` | Família |
| `/monitor` | `features/family/monitor_screen.dart` | Família |
| `/chat` | `features/family/chat_screen.dart` | Família |
| `/reminders` | `reminders_screen.dart` | Todos |
| `/create-reminder` | `create_reminder_screen.dart` | Todos |
| `/edit-reminder` | `edit_reminder_screen.dart` | Todos |
| `/categories` | `categories_screen.dart` | Todos |
| `/history` | `history_screen.dart` | Todos |
| `/config` | `config_screen.dart` | Todos |
| `/vehicle` | `features/vehicle/vehicle_screen.dart` | Adulto/Família |

---

## 5. Roles de usuário e regras de autenticação

### Roles (perfis)
| Role | Valor armazenado | Acesso |
|---|---|---|
| Idoso | `'Vovô'` / `'Vovó'` | TTS, SOS, detecção de queda, briefing por voz |
| Adulto | `'Adulto'` | Dashboard, sugestões inteligentes, veículos |
| Criança | `'Filhos'` | Tarefas gamificadas, barra de progresso |
| Família | `'Família'` | Monitoramento, chat, feed SOS |

### Fluxo de autenticação
1. Primeiro acesso: `OnboardingScreen` → marca `onboarding_visto = true` → `LoginScreen`
2. Acessos seguintes: `LoginScreen` direto
3. Após `signInWithEmailAndPassword`: → `ProfileSelectionScreen` → rota por perfil
4. Recuperação de senha: `FirebaseAuth.sendPasswordResetEmail`
5. O perfil selecionado é salvo via `ProfileService` (Firestore + SharedPreferences)

### Regras Firestore
- Segurança por perfil implementada nas regras do Firestore
- Idoso só acessa seus próprios lembretes e alertas SOS
- Família acessa feed de SOS e adesão aos lembretes dos vínculos

---

## 6. Estado atual do desenvolvimento e próxima tarefa

### Implementado e funcionando (v1.2.0+5)
- [x] Firebase Auth (login, cadastro, recuperação de senha)
- [x] Onboarding (3 slides, flag SharedPreferences)
- [x] Seleção de perfil (4 perfis: Idoso, Adulto, Filhos, Família)
- [x] Tela do Idoso: TTS, STT, SOS por voz, detector de queda
- [x] Tela do Adulto: dashboard, sugestões inteligentes
- [x] Tela da Criança: tarefas gamificadas + barra de progresso
- [x] Tela Família: código de convite, vínculos, monitoramento
- [x] Feed SOS + adesão a lembretes
- [x] Chat familiar com áudio
- [x] CRUD de lembretes (Firestore) — exclusão corrigida (Sessão 3)
- [x] Notificações locais (única, diária, semanal)
- [x] FCM push notifications
- [x] Briefing matinal por voz
- [x] Detector de queda (acelerômetro)
- [x] Serviço SOS com GPS
- [x] ProGuard rules para Gson/TypeToken (build release)
- [x] APK release gerado (v1.1.0 → 62 MB)

### Próximas tarefas (por prioridade)
- [ ] **[PRÓXIMA]** Tela de edição de perfil/nome dentro do app (sem sair para seleção de perfis)
- [ ] Notificação push servidor → familiar ao disparar SOS
- [ ] Tela de histórico de confirmações ("hoje você tomou X remédios")
- [ ] Widget Android de lembretes do dia (AppWidget)
- [ ] Modo escuro
- [ ] Testes de widget para telas críticas (LoginScreen, CreateReminderScreen)
- [ ] Internacionalização (i18n)
- [ ] Publicação na Play Store (track interno)

---

## 7. Regras obrigatórias

### Banco (Firestore)
- NUNCA deletar coleções em produção sem backup confirmado
- Índices compostos devem ser criados via Console Firebase, não por código
- Regras de segurança devem ser versionadas e testadas antes do deploy
- Campos de tipo de lembrete usam string SEM acento: `'Remedio'`, `'Tomar'` (não `'Remédio'`)

### Build / Android
- Build release DEVE ser executado em `C:\MeLembraAI` (fora do OneDrive — lock de arquivo)
- Antes de build: `swapon /swapfile` no VPS (swap não persiste entre reinicializações)
- ProGuard rules para Gson DEVEM estar em `android/app/proguard-rules.pro`
- `google-services.json` NUNCA vai para o git — adicionar manualmente antes de cada build

### Frontend (Flutter/Dart)
- NUNCA escrever emojis diretamente em arquivos `.dart` via PowerShell
- SEMPRE usar Python com escape unicode (`\UXXXXXXXX`) para escrever emojis
- SEMPRE rodar `python removebom.py` após escrita de arquivo via PowerShell
- Usar `withOpacity()` em vez de `withValues(alpha:)` — compatibilidade com SDKs antigos
- Usar `activeColor:` em vez de `activeThumbColor:` no Switch

### Auth
- Fluxo obrigatório: Onboarding → LoginScreen → ProfileSelectionScreen → tela do perfil
- `_concluir()` do onboarding navega para `LoginScreen`, não para `ProfileSelectionScreen`
- Após login, usar `pushAndRemoveUntil` para `ProfileSelectionScreen`

### Código
- Padrão de exclusão em dialogs: capturar `ScaffoldMessenger` ANTES de abrir o dialog; chamar `ReminderService.delete()` dentro do `onPressed` do botão de confirmação
- Não usar valor de retorno de `showDialog<bool>` com `StreamBuilder` ativo (frágil)

---

## 8. Arquivos de risco

| Arquivo | Risco | Motivo |
|---|---|---|
| `lib/main.dart` | Alto | Controla fluxo de boot; erro aqui bloqueia login ou onboarding |
| `android/app/proguard-rules.pro` | Alto | Regras Gson ausentes causam crash TypeToken em release |
| `android/app/build.gradle.kts` | Alto | minSdk, versões do AGP; erros bloqueiam build inteiro |
| `lib/services/notification_service.dart` | Alto | Cancelamento incorreto causa crash no dispositivo físico |
| `lib/login_screen.dart` | Alto | Navega para ProfileSelectionScreen após auth; bug aqui trava o app |
| `lib/features/onboarding/onboarding_screen.dart` | Médio | Navegar para tela errada pula o fluxo de auth |
| `lib/services/sos_service.dart` | Médio | Acessa GPS e dispara alertas; permissões podem falhar silenciosamente |
| `lib/services/fall_detector_service.dart` | Médio | Loop de sensor; não encerrar corretamente drena bateria |
| `lib/features/elderly/meus_lembretes_screen.dart` | Médio | Comparação de tipo SEM acento (`'Remedio'`); qualquer refactor pode re-introduzir bug |
| `lib/firebase_options.dart` | Baixo | Contém chaves públicas do Firebase; não contém secrets mas não deve ter chaves de prod/dev misturadas |

---

## 9. Comandos úteis

```powershell
# Rodar no dispositivo físico
flutter run -d R9QL200MJ0N --uninstall-first

# Listar dispositivos disponíveis
flutter devices

# Build release (EXECUTAR EM C:\MeLembraAI, não no OneDrive)
Copy-Item -Recurse -Force "C:\Users\phpos\OneDrive\MeLembraAI" "C:\MeLembraAI"
Set-Location "C:\MeLembraAI"
flutter build apk --release

# Copiar APK para desktop
Copy-Item "C:\MeLembraAI\build\app\outputs\flutter-apk\app-release.apk" "$env:USERPROFILE\Desktop\me-lembra-ai.apk"

# Limpar dados do app no dispositivo (requer adb no PATH)
adb shell pm clear com.melembra.ai

# Verificar encoding de arquivo .dart (detectar BOM)
python -c "f=open('lib/main.dart','rb');b=f.read(3);print('BOM' if b==b'\xef\xbb\xbf' else 'OK')"

# Remover BOM de arquivo
python removebom.py

# Atualizar dependências
flutter pub upgrade

# Analisar código
flutter analyze

# Rodar testes
flutter test
```

```bash
# No VPS Hetzner (SSH root@204.168.180.25)
swapon /swapfile                          # Reativar swap após reboot
cd /root/ME-LEMBRA-AI/me_lembra_ai
flutter build apk --release

# Servir APK via HTTP
cd build/app/outputs/flutter-apk/
python3 -m http.server 8080
# Baixar em: http://204.168.180.25:8080/app-release.apk
```

---

## 10. Links de referência

| Recurso | URL |
|---|---|
| Firebase Console | https://console.firebase.google.com/project/me-lembra-ai-bf0f0 |
| Firestore | https://console.firebase.google.com/project/me-lembra-ai-bf0f0/firestore |
| Firebase Auth | https://console.firebase.google.com/project/me-lembra-ai-bf0f0/authentication |
| FCM | https://console.firebase.google.com/project/me-lembra-ai-bf0f0/messaging |
| Flutter docs | https://docs.flutter.dev |
| flutter_local_notifications | https://pub.dev/packages/flutter_local_notifications |
| flutter_tts | https://pub.dev/packages/flutter_tts |
| Firestore security rules | https://firebase.google.com/docs/firestore/security/get-started |

> Os arquivos `/docs/CURRENT_STATE.md`, `/docs/TASKS.md` e `/docs/ARCHITECTURE.md` ainda não existem.
> Devem ser criados na próxima sessão de documentação.

---

*Última atualização: 2026-05-27 — v1.2.0+5 — Sessão 3 concluída*
