# CURRENT_STATE.md — Me Lembra Aí

> Última atualização: 2026-07-02 (sessão 13)

---

## Versão e build

| Item | Valor |
|---|---|
| Versão do app | `1.3.2+8` |
| APK atual | `me-lembra-ai-v1.3.2.apk` — 63.9 MB |
| Distribuição | Side-load (não publicado na Play Store) |
| Dispositivo de referência | Samsung Galaxy A07 — ID `R9QL200MJ0N` |
| Build release | `C:\MeLembraAI` (fora do OneDrive — obrigatório) |
| Pasta de APKs | `C:\Users\phpos\OneDrive\Área de Trabalho\VERSÕES\` |

---

## O que o app faz

Aplicativo de lembretes acessível para famílias. Possui quatro perfis independentes:

| Perfil | Público | Destaques |
|---|---|---|
| **Vovô / Vovó** | Idosos | Botões grandes, TTS/STT, botão SOS, detector de queda, mapa |
| **Adulto** | Adultos | Dashboard, sugestões inteligentes, agenda |
| **Filhos** | Crianças | Tarefas gamificadas, barra de progresso |
| **Família** | Cuidadores | Feed SOS, chat familiar, monitoramento |

---

## Stack tecnológica

| Camada | Tecnologia | Versão no pubspec |
|---|---|---|
| UI | Flutter / Dart | SDK ≥ 3.0 |
| Auth | Firebase Auth | ^5.3.0 |
| Banco de dados | Cloud Firestore | ^5.4.0 |
| Push notifications | Firebase Cloud Messaging | ^15.1.0 |
| Notificações locais | flutter_local_notifications | ^17.2.2 |
| Armazenamento de áudio | Firebase Storage | ^12.3.0 |
| Localização | geolocator | ^12.0.0 |
| Mapa | google_maps_flutter | ^2.9.0 |
| TTS (texto para voz) | flutter_tts | ^4.0.2 |
| STT (voz para texto) | speech_to_text | ^7.3.0 |
| Detector de queda | sensors_plus | ^4.0.2 |
| Gravação de áudio | record | ^6.0.0 |
| Reprodução de áudio | audioplayers | ^6.1.0 |
| Permissões | permission_handler | ^11.3.1 |
| Links / chamadas | url_launcher | ^6.3.0 |
| Preferências locais | shared_preferences | ^2.2.2 |
| Fuso horário | timezone | ^0.9.4 |
| Notificações VPS | firebase-admin (Python) | ≥ 6.5.0 |

---

## Funcionalidades implementadas (todas verificadas)

### Autenticação
- [x] Login com e-mail e senha (Firebase Auth)
- [x] Cadastro de nova conta
- [x] Recuperação de senha via e-mail
- [x] Onboarding de 3 slides no primeiro acesso (flag `onboarding_visto`)
- [x] Seleção de perfil ao entrar (Idoso, Adulto, Filhos, Família)
- [x] Troca de perfil sem sair do app (BottomSheet na ConfigScreen)

### Perfil Idoso
- [x] Interface com botões grandes (altura 70–90 px, fonte 24–32 px)
- [x] Leitura por voz dos lembretes do dia (TTS)
- [x] Criação de lembretes por voz (STT + parser de data/hora em pt-BR)
- [x] Briefing matinal automático às 8h
- [x] Detector de queda via acelerômetro (sensors_plus)
- [x] Botão SOS com confirmação por voz ("SOCORRO" aciona SOS)
- [x] Botão "Minha Localização" → MapScreen
- [x] Meus Lembretes (cards por categoria)

### Perfil Adulto
- [x] Dashboard com resumo do dia
- [x] Sugestões inteligentes de lembretes (heurística de padrões)

### Perfil Filhos
- [x] Tarefas gamificadas com barra de progresso

### Perfil Família
- [x] Código de convite de 6 caracteres
- [x] Vínculo bilateral monitorado ↔ cuidador
- [x] Feed de alertas SOS dos monitorados
- [x] Adesão a lembretes dos monitorados
- [x] Chat familiar com texto
- [x] Chat familiar com áudio (segurar para gravar / soltar para enviar)

### Lembretes
- [x] Criar / Editar / Excluir (Firestore)
- [x] Categorias: Remédio, Consulta, Aniversário, Mercado, Reunião, Tomar, Compras
- [x] Repetição: único, diário, semanal
- [x] Notificações locais agendadas (únicas e recorrentes)
- [x] Notificações por perfil (canal idoso com fullScreen, canal criança leve)
- [x] Confirmação de lembrete realizado
- [x] Histórico de confirmações (últimos 30 dias)

### SOS — pipeline completo
- [x] Botão SOS aciona `SosService.trigger()`
- [x] GPS obtido automaticamente e incluído no alerta
- [x] Registro do alerta em `sos_alerts/{id}` no Firestore
- [x] Mensagem de chat enviada a todos os cuidadores vinculados
- [x] **Ligação automática** para número SOS cadastrado (CALL_PHONE + ACTION_CALL)
  - Fallback: abre discador se permissão negada
- [x] **Notificação crítica** no dispositivo do familiar (canal `sos_alert`, Importance.MAX, fullScreenIntent, vibração intensa)
- [x] **Push FCM via VPS** quando app do familiar está encerrado (`sos_notifier.py`)
- [x] `SosListenerService`: listener Firestore em foreground/background
- [x] **Foreground Service** "Modo proteção ativo" — mantém o processo vivo mesmo com app fechado
- [x] **SOS por teclas** — 5 × tecla de volume em ≤ 3 s (funciona com app em foreground)
- [x] Detector de queda com acionamento automático
- [x] **Countdown 5 s cancelável** antes de disparar SOS (botão CANCELAR visível)
- [x] **Múltiplos contatos SOS** — até 3 números; 1º chamado automaticamente; dialog para os demais

### Veículos
- [x] Cadastro de veículos (apelido, placa, troca de óleo, IPVA parcelado, CNH, Seguro parcelado)
- [x] Status por item: ok / atenção (≤30 dias) / vencido
- [x] Pagar parcelas de IPVA e seguro diretamente no app
- [x] Registrar troca de óleo (km + intervalo)
- [x] Acesso pelo perfil Adulto (card no dashboard com contagem de alertas)
- [x] Acesso pelo perfil Idoso (botão "Meus Veículos")

### Maps
- [x] Tela `MapScreen` com GoogleMap, marcador na posição atual
- [x] FAB "Enviar SOS com localização" na tela de mapa
- [x] Tratamento de erros de permissão e GPS desativado com mensagem amigável

### Configurações
- [x] Toggle: Localização
- [x] Toggle: Botão SOS
- [x] Campo: Número de emergência (salvo em SharedPreferences)
- [x] Toggle: Chat Familiar
- [x] Toggle: Modo Proteção (Foreground Service)
- [x] Toggle: SOS por Teclas (volume)
- [x] Botão: Minha Localização → MapScreen
- [x] Toggle: Notificações
- [x] Toggle: Modo Escuro
- [x] Editar nome do perfil
- [x] Trocar perfil
- [x] Sair da conta

### Widget Android
- [x] AppWidget 4×2 mostrando lembretes de hoje (atualiza a cada 30 min)

### Infraestrutura
- [x] ProGuard rules Gson/TypeToken para builds release
- [x] Pipeline de build documentado
- [x] 15 widget tests automatizados (`login_screen_test`, `create_reminder_screen_test`)
- [x] Tela "Sobre o App" com manual do usuário e rodapé HEXAGON TECNOLOGIA
- [x] Copyright © 2026 HEXAGON TECNOLOGIA em `lib/about_screen.dart`

---

## Lacunas e limitações conhecidas

| Item | Impacto | Observação |
|---|---|---|
| ~~`YOUR_GOOGLE_MAPS_API_KEY` no AndroidManifest~~ | ~~Bloqueante para o mapa~~ | ✅ Chave configurada (sessão 12) |
| Histórico SOS por alerta (status "visualizado") | Baixo | Campo `confirmed` é booleano global — ver TASK-24 |
| Volume SOS com tela bloqueada | Baixo | Requer Accessibility Service com consentimento explícito do usuário |
| Histórico SOS por alerta (status "visualizado") | Baixo | `confirmed` é booleano global; precisaria de subcoleção `confirmations/{date}` |
| Múltiplos números SOS | Baixo | Hoje suporta apenas 1 número |
| Countdown 5 s antes de disparar SOS | Baixo | Não implementado |
| Publicação na Play Store | Baixo | APK só em side-load |
| VPS: reiniciar `sos-notifier.service` após novo `sos_notifier.py` | Operacional | Ver seção Deploy VPS |

---

## Como buildar

```powershell
# 1. Copiar arquivos alterados para fora do OneDrive (OneDrive bloqueia Gradle)
Copy-Item -Recurse -Force "C:\Users\phpos\OneDrive\MeLembraAI\*" "C:\MeLembraAI\"

# 2. Entrar no diretório limpo
Set-Location "C:\MeLembraAI"

# 3. Instalar dependências (necessário após mudanças no pubspec.yaml)
flutter pub get

# 4. Build release
flutter build apk --release

# 5. Copiar APK para a Área de Trabalho
Copy-Item "C:\MeLembraAI\build\app\outputs\flutter-apk\app-release.apk" `
  "$env:USERPROFILE\Desktop\me-lembra-ai-v1.2.0.apk" -Force
```

> **Atenção:** Sempre buildar em `C:\MeLembraAI`. O OneDrive mantém locks nos arquivos `.so` nativos durante a sincronização, causando `AccessDeniedException` no Gradle.

---

## Arquivos importantes

| Arquivo | Função |
|---|---|
| `lib/main.dart` | Entrada do app, rotas, temas, inicialização de serviços |
| `lib/services/sos_service.dart` | Lógica SOS: Firestore + chat + ligação automática |
| `lib/services/fcm_service.dart` | FCM: token, notificação em foreground |
| `lib/services/notification_service.dart` | Canais Android, notificações locais agendadas, `showSosAlert()` |
| `lib/services/sos_listener_service.dart` | Listener Firestore de alertas SOS dos monitorados |
| `lib/services/sos_protection_service.dart` | Controla o Foreground Service via MethodChannel |
| `lib/services/volume_sos_service.dart` | Escuta sequência de volume e dispara SOS |
| `lib/services/location_service.dart` | Wrapper geolocator com tratamento de permissões |
| `lib/services/settings_service.dart` | Todas as preferências locais (SharedPreferences) |
| `lib/features/elderly/elderly_screen.dart` | Tela principal do idoso |
| `lib/features/maps/map_screen.dart` | Tela de mapa com localização atual |
| `lib/features/family/chat_screen.dart` | Chat com áudio (long press para gravar) |
| `lib/config_screen.dart` | Configurações completas do app |
| `android/app/src/main/AndroidManifest.xml` | Permissões, receivers, services, API key Maps |
| `android/app/src/main/kotlin/.../MainActivity.kt` | MethodChannels e EventChannels nativos |
| `android/app/src/main/kotlin/.../SosProtectionService.kt` | Foreground Service nativo |
| `android/app/proguard-rules.pro` | Regras R8 para Gson/TypeToken |
| `server/sos_notifier.py` | Serviço VPS: envia FCM push quando app está fechado |
| `pubspec.yaml` | Dependências Flutter |

---

## Arquivos que NÃO devem ser alterados sem cuidado

| Arquivo | Motivo |
|---|---|
| `lib/firebase_options.dart` | Gerado pelo FlutterFire CLI — não editar manualmente |
| `android/app/google-services.json` | Chave Firebase — **não commitar em repositório público** |
| `android/app/proguard-rules.pro` | Sem as regras Gson, o build release quebra com TypeToken |
| `android/app/build.gradle.kts` | Configuração de assinatura, minSdk e R8 |
| `/root/sos_notifier/serviceAccountKey.json` | Credencial Firebase Admin no VPS — **nunca commitar** |

---

## Deploy das regras/índices do Firestore

Alterações em `firestore.rules` ou `firestore.indexes.json` só valem em produção após:

```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

> **Atenção:** sem isso, a query de `sos_alerts` (userId + orderBy createdAt) falha por falta de índice e o `markViewed` falha por permissão — mesmo com o código já corrigido localmente.

---

## Deploy do sos_notifier.py no VPS

```bash
ssh root@204.168.180.25
cp /local/server/sos_notifier.py /root/sos_notifier/sos_notifier.py
systemctl restart sos-notifier
systemctl status sos-notifier
```

Para instalação inicial:

```bash
mkdir -p /root/sos_notifier
# Copiar server/* para /root/sos_notifier/
# Baixar serviceAccountKey.json → Firebase Console → Configurações → Contas de serviço
pip3 install -r /root/sos_notifier/requirements.txt
cp /root/sos_notifier/sos-notifier.service /etc/systemd/system/
systemctl enable sos-notifier
systemctl start sos-notifier
```

---

## Histórico de sessões

| Sessão | Data | Principais entregas |
|---|---|---|
| 1–2 | 2026-05-11 | Auth, onboarding, 4 perfis, TTS/STT, SOS básico, FCM, notificações locais |
| 3 | 2026-05-12 | Correção de exclusão de lembretes, ProGuard, build release v1.1.0 |
| 4 | 2026-05-27 | Troca de perfil sem sair, correções de UI |
| 5 | 2026-05-27 | `sos_notifier.py` no VPS (SOS com app fechado) |
| 6 | 2026-05-27 | Tela de histórico de confirmações |
| 7 | 2026-05-27 | Widget Android de lembretes do dia |
| 8 | 2026-05-27 | Modo escuro completo |
| 9 | 2026-05-27 | 15 widget tests automatizados |
| 10 | 2026-05-29 | SOS auto-call, canal `sos_alert` fullScreen, áudio long-press |
| 11 | 2026-05-29 | Maps (GoogleMap), Foreground Service, SOS por volume, build v1.2.0 |
| 12 | 2026-06-01 | Google Maps key; fix TTS + categoria Remédios; TASK-25 countdown SOS; TASK-27 múltiplos contatos; TASK-24 histórico SOS; TASK-26 SOS por toques; TASK-28 Veículos; manual do usuário; v1.3.0 |
| 13 | 2026-07-02 | Fix bug: número SOS obsoleto voltava após limpar a lista (`settings_service.dart`); validação de número antes de discar; `firestore.indexes.json` (índice composto `sos_alerts`) + tratamento de erro de stream em `sos_history_screen.dart`/`monitor_screen.dart` (tela não trava mais em loop); regra do Firestore corrigida para permitir `markViewed` (campo `viewedBy`); chat: botão único mic/enviar (`chat_screen.dart`) em vez de dois botões ambíguos. v1.3.1. **Pendente:** rodar `firebase deploy --only firestore:rules,firestore:indexes` em produção |
| 13b | 2026-07-02 | Diagnóstico: número SOS "incorreto" era número salvo sem DDD (confirmado pois a rediscagem manual do mesmo número no histórico também falhava). Validação mínima subiu de 8 para 10 dígitos em `sos_service.dart`; `config_screen.dart` agora mostra aviso em vermelho no campo quando o número está incompleto. v1.3.2 |
