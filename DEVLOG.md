# DEVLOG — ME LEMBRA AI
> Registro de desenvolvimento do aplicativo Flutter com Firebase

---

## 📋 Visão Geral do Projeto

**Nome:** Me Lembra AI  
**Plataforma:** Flutter (Android + iOS)  
**Backend:** Firebase (Auth + Firestore + Messaging)  
**Package Android:** `com.melembra.ai`  
**Repositório:** https://github.com/fasterdrible-lab/ME-LEMBRA-AI  
**Última atualização:** 2026-04-05  

---

## 🏗️ Estrutura do Projeto

```
me_lembra_ai/
├── android/
│   └── app/
│       ├── build.gradle.kts          # applicationId: com.melembra.ai
│       ├── google-services.json      # NÃO commitado (.gitignore)
│       └── src/main/kotlin/com/melembra/ai/MainActivity.kt
├── ios/
│   └── Runner/
│       └── GoogleService-Info.plist  # NÃO commitado (.gitignore)
├── assets/
│   ├── images/                       # Imagens de perfil (adulto, idoso, criança)
│   └── icon/
│       └── app_icon.png              # Ícone do app (fundo amarelo #FFB800)
├── lib/
│   ├── main.dart                     # Entrada do app + Firebase init + roteamento auth
│   ├── firebase_options.dart         # Gerado pelo flutterfire configure (NÃO editar)
│   ├── login_screen.dart             # Tela de login (e-mail/senha)
│   ├── register_screen.dart          # Tela de cadastro
│   ├── onboarding_screen.dart        # Tela de onboarding inicial
│   ├── profile_selection_screen.dart # Seleção de perfil (Adulto/Vovô/Criança)
│   ├── home_screen.dart              # Tela principal com lembretes
│   ├── create_reminder_screen.dart   # Criar/editar lembrete
│   ├── reminders_screen.dart         # Lista de todos os lembretes
│   ├── categories_screen.dart        # Categorias de lembretes
│   ├── config_screen.dart            # Configurações + logout
│   ├── elderly_screen.dart           # Placeholder tela idoso (vazio)
│   ├── models/                       # Modelos de dados
│   ├── features/                     # Features futuras (estrutura criada)
│   └── services/
│       └── profile_service.dart      # Serviço de perfil (SharedPrefs + Firestore)
└── pubspec.yaml
```

---

## 📦 Dependências (pubspec.yaml)

```yaml
dependencies:
  flutter: sdk: flutter
  shared_preferences: ^2.2.2    # Armazenamento local
  firebase_core: ^3.6.0         # Firebase base
  firebase_auth: ^5.3.0         # Autenticação
  cloud_firestore: ^5.4.0       # Banco de dados na nuvem
  firebase_messaging: ^15.1.0   # Push notifications (configurado, não implementado)

dev_dependencies:
  flutter_lints: ^3.0.0
  flutter_launcher_icons: ^0.14.1
```

---

## 🔥 Firebase — Configuração

**Projeto Firebase:** `me-lembra-ai-bf0f0`  
**Console:** https://console.firebase.google.com/project/me-lembra-ai-bf0f0  

| Serviço | Status |
|---|---|
| Authentication (E-mail/senha) | ✅ Ativo |
| Cloud Firestore | ✅ Ativo |
| Firebase Messaging | ⚙️ Configurado, não implementado |
| App Check | ⚠️ Não configurado |

### Regras do Firestore
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Estrutura de Dados no Firestore
```
users/
  {uid}/
    perfil: "Adulto" | "Vovô / Vovó" | "Criança"
    nome:   "André"
```

### Apps Registrados no Firebase
| Plataforma | App ID |
|---|---|
| Android | `1:1029231065071:android:e3e10d91aeda4951b8a81a` |
| iOS | `1:1029231065071:ios:a243c827828118ceb8a81a` |

---

## 🗺️ Fluxo de Navegação

```
App inicia
    │
    ▼
Firebase.initializeApp()
    │
    ▼
StreamBuilder<User?> (authStateChanges)
    ├── Logado ──────────────────► HomeScreen
    └── Não logado
            │
            ▼
        LoginScreen
            ├── [Entrar] ────────► HomeScreen (via StreamBuilder)
            └── [Criar conta]
                    │
                    ▼
                RegisterScreen
                    │
                    ▼
                ProfileSelectionScreen
                    │ (toca card de perfil)
                    ▼
                Modal "Como posso te chamar?"
                    │
                    ▼
                HomeScreen

HomeScreen
    ├── Aba 0: Home (lembretes do dia)
    ├── Aba 1: Categorias
    ├── Aba 2: [+] → CreateReminderScreen
    └── Aba 3: ConfigScreen
                └── [Sair da conta] → LoginScreen (via StreamBuilder)
```

---

## 🖥️ Telas Implementadas

### `login_screen.dart`
- Campos: e-mail + senha
- Botão "Entrar": `FirebaseAuth.signInWithEmailAndPassword`
- Botão "Criar conta": navega para `RegisterScreen`
- Erros mapeados em português via `SnackBar`
- Design: fundo `#F2F2F7`, azul `#4A90D9`

### `register_screen.dart`
- Campos: e-mail + senha + confirmar senha
- Validações: senhas iguais, mínimo 6 caracteres
- Botão "Cadastrar": `FirebaseAuth.createUserWithEmailAndPassword`
- Após sucesso: navega para `ProfileSelectionScreen`

### `profile_selection_screen.dart`
- 3 cards: Adulto 👨 / Vovô / Vovó 👴 / Criança 👧
- Ao tocar: verifica se nome já salvo → se não, abre modal
- Modal "Como posso te chamar?" → salva nome no Firestore + SharedPrefs
- Layout responsivo: `math.min(90.0, size.width * 0.22)`

### `home_screen.dart`
- Header gradiente roxo (`#7B5EA7` → `#5B4FCF`)
- Saudação: "Bom dia / Boa tarde / Boa noite, [Nome] 👋"
- Data correta em português com acentuação
- Seções: "Hoje" e "Em breve"
- Cards de lembretes com ícone colorido, título, subtítulo, horário
- Badge "HOJE" vermelho
- BottomNavigationBar: Início / Categorias / ➕ / Config

### `create_reminder_screen.dart`
- Chips de tipo: 💊 Remédio / 🩺 Consulta / 🎂 Aniversário / 📅 Evento / ✅ Tarefa / 🔄 Recorrente
- Campos: Título, Descrição (opcional)
- Seletores de Data e Hora
- Chips de repetição: Nunca / Diário / Semanal / Mensal / Anual
- Card de notificação: 🔔 15 minutos antes
- Botão "✓ Salvar Lembrete"
- Salva em `SharedPreferences` como lista de strings

### `reminders_screen.dart`
- Lista de lembretes do SharedPreferences
- Cards visuais com ícone, título, horário
- Navegação para `CreateReminderScreen`

### `categories_screen.dart`
- Grid 2x2: 💊 Remédios / 🩺 Consultas / 🛒 Mercado / 🎂 Aniversários
- Cards largura total: 📅 Eventos / ✅ Tarefas / 🔄 Recorrentes

### `config_screen.dart`
- Seção PERFIL: alterar nome (AlertDialog pré-preenchido)
- Seção NOTIFICAÇÕES: toggles (Sons, Vibração, Notificações noturnas, Modo silencioso)
- Seção ACESSIBILIDADE: toggles (Texto grande, Alto contraste, Leitura em voz alta)
- Seção CONTA: **"Sair da conta"** → `FirebaseAuth.signOut()` → redireciona via StreamBuilder

---

## ⚙️ Serviços

### `services/profile_service.dart`
Responsável por persistir perfil e nome do usuário.

**Estratégia:** Salva em `SharedPreferences` + `Firestore` (dual write). Lê do Firestore se autenticado, com fallback para SharedPreferences.

```dart
// Métodos disponíveis:
ProfileService.saveProfile(String perfil)
ProfileService.getProfile() → String?
ProfileService.saveNameForProfile(String perfil, String nome)
ProfileService.getNameForProfile(String perfil) → String?
ProfileService.getNameForSelectedProfile() → String?
```

**Chaves SharedPreferences:**
- `perfil` → perfil selecionado
- `nome_Adulto`, `nome_Vovô / Vovó`, `nome_Criança` → nome por perfil

---

## 📅 Histórico de PRs e Commits

| Data | PR | Descrição |
|---|---|---|
| 2026-04-03 | Commit inicial | `primeira versao app` — estrutura base Flutter |
| 2026-04-03 | PR #1 | Implementação completa inicial (screens, features, README) |
| 2026-04-05 | Manual | Configuração Firebase, build.gradle, google-services |
| 2026-04-05 | PR #3 | Fix FAB → CreateReminderScreen, fix package Android (`com.melembra.ai`), launcher icons |
| 2026-04-05 | PR #4 | Redesign completo: HomeScreen gradiente, CategoriesScreen, BottomNavBar, CreateReminder chips |
| 2026-04-05 | PR #6 | Modal de nome no perfil + saudação automática na Home (Bom dia/tarde/noite) |
| 2026-04-05 | PR #7 | Fix data incorreta na Home, renomeação de perfil em Config, 0 warnings de lint |
| 2026-04-05 | PR #9 | Fix botão Adicionar da BottomBar, remove FAB duplicado, layout compacto perfil, "Vovô/Vovó" |
| 2026-04-05 | PR #11 | **Autenticação Firebase**: login, cadastro, logout, perfil no Firestore |

---

## ✅ Features Implementadas

- [x] Estrutura Flutter base (Android + iOS)
- [x] Firebase inicializado com `firebase_options.dart`
- [x] Autenticação e-mail/senha (login + cadastro + logout)
- [x] Roteamento automático por estado de autenticação (StreamBuilder)
- [x] Seleção de perfil (Adulto / Vovô-Vovó / Criança)
- [x] Modal de nome no primeiro acesso
- [x] Perfil e nome salvos no Firestore + SharedPreferences
- [x] HomeScreen com saudação, data e lembretes
- [x] Criar lembrete (tipo, título, descrição, data, hora, repetição)
- [x] Lembretes salvos em SharedPreferences
- [x] Categorias de lembretes
- [x] Configurações (alterar nome, toggles, logout)
- [x] Design responsivo com gradiente roxo

## 🔜 Próximos Passos (Backlog)

- [ ] **Notificações locais** — `flutter_local_notifications` + agendamento por horário
- [ ] **Lembretes no Firestore** — sincronizar lembretes na nuvem (hoje só local)
- [ ] **Push notifications** — usar `firebase_messaging` já instalado
- [ ] **Tela do Idoso** — `elderly_screen.dart` está vazio, implementar com fontes grandes e botão SOS
- [ ] **Onboarding** — conectar `onboarding_screen.dart` ao fluxo principal
- [ ] **IA nos lembretes** — sugestão automática de horário pelo tipo do lembrete
- [ ] **Multi-usuário familiar** — pai gerencia perfil do filho
- [ ] **Detecção de queda** — `sensors_plus` para perfil Idoso
- [ ] **Chat familiar** — Firestore Realtime
- [ ] **Localização em tempo real** — `geolocator`

---

## 🔧 Setup Local (para retomar o desenvolvimento)

```powershell
# 1. Clonar o repositório
git clone https://github.com/fasterdrible-lab/ME-LEMBRA-AI.git
cd ME-LEMBRA-AI/me_lembra_ai

# 2. Gerar firebase_options.dart (não está no git)
dart pub global activate flutterfire_cli
firebase login
& "$env:LOCALAPPDATA\Pub\Cache\bin\flutterfire.bat" configure --project=me-lembra-ai-bf0f0
# Selecionar: android, ios

# 3. Instalar dependências
flutter pub get

# 4. Rodar no dispositivo
flutter run -d <DEVICE_ID>
```

> ⚠️ **IMPORTANTE:** `google-services.json` e `GoogleService-Info.plist` estão no `.gitignore` e devem ser gerados localmente via `flutterfire configure`.

---

## 🎨 Design System

| Token | Valor | Uso |
|---|---|---|
| `primary` | `#4A90D9` | Azul — botões, links |
| `purple` | `#7B5EA7` | Roxo — header Home |
| `purpleDark` | `#5B4FCF` | Gradiente header |
| `background` | `#F2F2F7` | Fundo geral |
| `cardBg` | `#FFFFFF` | Cards |
| `textPrimary` | `#1C1C1E` | Título |
| `textSecondary` | `Colors.black54` | Subtítulo |

---

*Gerado automaticamente pelo GitHub Copilot em 2026-04-05*