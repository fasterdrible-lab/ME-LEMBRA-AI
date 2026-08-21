# CURRENT_STATE.md — Me Lembra Aí

> Última atualização: 2026-08-21 (sessão 22)

---

## Versão e build

| Item | Valor |
|---|---|
| Versão do app | `1.5.2+23` |
| APK atual | `me-lembra-ai-v1.4.2.apk` — 63.9 MB (v1.5.0 ainda não gerada em release, só debug) |
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
- [x] **Botão único "Falar Comando"**, agora um **assistente conversacional multi-turno** (sessão 21): roteador de intenção por voz que substitui os antigos botões separados de "Ouvir lembretes", "Criar lembrete por voz" e "Meus Alertas SOS" — o usuário só fala o que quer, e pode ter várias trocas seguidas sem tocar o botão de novo:
  - "quais são meus lembretes de hoje" → lê os lembretes do dia (TTS)
  - "adiciona leite na lista de compras" → adiciona item à lista de compras existente ou cria uma nova
  - "meus alertas" → fala um resumo dos alertas SOS (quantidade, mais recente, se foi visto pela família) — sem abrir tela
  - "SOCORRO" a qualquer momento da escuta → prioridade máxima, dispara o SOS na hora, **sempre local, nunca passa pela IA**
  - qualquer outra frase → primeiro tenta o **backend de IA (Groq)** (`AiCommandService`); se não tiver internet/backend fora do ar, cai no parser local de sempre (STT + data/hora em pt-BR) tratando como criar lembrete
  - pedido ambíguo (ex.: "marca uma consulta" sem dizer quando) → IA **pergunta** em vez de inventar, e o microfone reabre sozinho pra ouvir a resposta
  - a conversa continua até o usuário dizer algo como "obrigado"/"pode parar", ficar em silêncio, ou chegar a 6 turnos (aviso automático nesse caso)
  - a IA recebe um resumo real dos lembretes existentes (título/tipo/data, e itens da lista de compras) a cada chamada — grounding pra não inventar dado que não existe
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
| Volume SOS com tela bloqueada ou app fechado | Baixo | Requer Accessibility Service com consentimento explícito do usuário — captura de tecla física só funciona com a Activity em primeiro plano recebendo foco de janela; nenhum Foreground Service resolve isso (achado/confirmado na sessão 21) |
| `SosListenerService` (lado do cuidador) para de rodar com o app do cuidador fechado | Baixo | Mesma causa raiz do detector de queda (sessão 21): é uma `StreamSubscription` presa ao `FlutterEngine` da Activity, destruída junto com ela. Hoje o cuidador só é avisado via notificação nativa do FCM (independente disso) quando o app dele está fechado — funciona, mas o listener Firestore em si não sobrevive. Não corrigido nesta sessão (fora do escopo pedido, fica registrado pra decisão futura) |
| Histórico SOS por alerta (status "visualizado") | Baixo | `confirmed` é booleano global; precisaria de subcoleção `confirmations/{date}` |
| Múltiplos números SOS | Baixo | Hoje suporta apenas 1 número |
| Countdown 5 s antes de disparar SOS | Baixo | Não implementado |
| Publicação na Play Store | Baixo | APK só em side-load |
| VPS: reiniciar `sos-notifier.service` após novo `sos_notifier.py` | Operacional | Ver seção Deploy VPS |
| ~~`sos_notifier.py` não está implantado na VPS de produção~~ | ~~Alto~~ | ✅ Implantado de fato na sessão 17 — ver histórico de sessões abaixo |
| Clone Git órfão em `/root/ME-LEMBRA-AI` na VPS, com segredos em arquivos não commitados | Médio | Descoberto na sessão 16, não tocado — precisa de autorização explícita antes de limpar |
~~Ligação automática do SOS cancelada pela rede/operadora (SIP 487)~~ | ~~Médio~~ | ✅ Corrigido na sessão 13f — faltava o código do país (+55) no número discado |
| `test/reminder_service_test.dart` com 6 testes falhando | Baixo | Pré-existente desde abril/2026 (commit `8507bec`), não relacionado a nenhuma mudança recente — descoberto na sessão 19 ao rodar a suíte completa |
| ~~Envio de áudio no Chat Familiar falha (Firebase Storage 404 "server terminated the upload session")~~ | ~~Alto~~ | ✅ Resolvido na sessão 21 — ver TASK-31 no histórico. |

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

> **Atenção (achado na sessão 18):** se o Gradle falhar com `Could not find the firebase_core FlutterFire plugin, have you added it as a dependency in your pubspec?` (mesmo com o pacote correto no `pubspec.yaml`), o cache do pub em `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\` está com pacotes corrompidos (pastas vazias — sem `pubspec.yaml`/`android/`). Para detectar: `Get-ChildItem $env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev -Directory | ForEach-Object { if ((Get-ChildItem $_.FullName -Force).Count -eq 0) { $_.Name } }`. Remover as pastas vazias listadas e rodar `flutter pub get` de novo para forçar o redownload.

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
firebase deploy --only firestore:rules,firestore:indexes --project me-lembra-ai-bf0f0
```

> **Atenção:** sem isso, a query de `sos_alerts` (userId + orderBy createdAt) falha por falta de índice e o `markViewed` falha por permissão — mesmo com o código já corrigido localmente.
>
> **Atenção (sessão 19/20):** rodar sem `--project` dá `Error: No currently active project` (não há projeto ativo configurado localmente pro Firebase CLI) — sempre passar `--project me-lembra-ai-bf0f0` explicitamente, ou rodar `firebase use --add` uma vez pra fixar o projeto padrão.

---

## Plano Blaze e custo estimado (Firebase Storage)

O upload de áudio do Chat Familiar falha (ver "Lacunas" acima) porque o
Firebase Storage nunca foi provisionado pro projeto — desde que o Google
mudou a política (out/2024), habilitar Storage (mesmo dentro da cota
gratuita) exige o plano **Blaze** (pay-as-you-go, com cartão cadastrado),
não é mais possível só no Spark (grátis).

**Como ativar**: Firebase Console → ícone de engrenagem → "Fazer upgrade"
→ escolher Blaze → associar um cartão. Depois disso, `storage.rules`
provavelmente precisa ser criado/deployado também (hoje não existe no
repo) — verificar no Console se o bucket
`me-lembra-ai-bf0f0.firebasestorage.app` passou a existir e testar o envio
de áudio de novo.

**Análise de custo (sessão 19, baseada em
[firebase.google.com/pricing](https://firebase.google.com/pricing)):**

| Serviço | Cota grátis/mês (já no Blaze) | Preço acima da cota |
|---|---|---|
| Storage — armazenamento | 5 GB-mês | US$ 0,026/GB |
| Storage — download (egress) | 100 GB | ~US$ 0,12/GB |
| Storage — uploads | 5.000 operações | pequeno, por lote de 10k |
| Firestore — leituras | 50.000/dia | já disponível hoje, mesmo sem Blaze |
| Firestore — escritas | 20.000/dia | já disponível hoje, mesmo sem Blaze |
| FCM (push, usado no SOS) | **ilimitado, sempre grátis** | — |

**Não tem mensalidade fixa no Blaze** — só cobra o que passar da cota.
Pro volume real do Me Lembra Aí (app de uso familiar, não milhões de
usuários; único uso novo de Storage é áudio de chat, ~50–200 KB por
mensagem), estourar os 5 GB grátis exigiria dezenas de milhares de áudios
por mês — a expectativa é **custo $0/mês** na prática. Contas novas no
Blaze também costumam vir com US$ 300 de crédito grátis, cobrindo qualquer
estouro pequeno várias vezes.

---

## Backend de comando de voz por IA (Groq) — `server/ai_command_server/`

Serviço novo, separado do `sos_notifier.py`, que recebe a frase transcrita
pelo botão "Falar Comando" (quando não bate em nenhuma regra local rápida) e
usa a API da Groq (modelo em `GROQ_MODEL`, hoje `openai/gpt-oss-20b` — grátis
até 30k tokens/min e 14.400 req/dia) para devolver uma ação estruturada em
JSON. O SOS nunca passa por aqui — continua 100% local no app.

> **Atenção (sessão 21):** a Groq descontinua modelos de tempos em tempos —
> `llama-3.3-70b-versatile` (usado desde a sessão 15) parou de existir em
> algum momento por volta de 19/08/2026 e todas as chamadas passaram a
> retornar 404 `model_not_found`, silenciosamente engolido por
> `AiCommandService.interpretar()` e caindo no parser local sem nenhum aviso
> visível pro usuário. Se o "Falar Comando" voltar a "não entender nada" um
> dia, o primeiro lugar a checar é `journalctl -u melembra-ai-backend -f` na
> VPS durante um teste, e a lista de modelos atuais em
> `https://console.groq.com/docs/models` (ou `curl .../v1/models` com a
> chave real) — o catálogo pode ter mudado de novo.

**Domínio**: `api.melbrai.com.br` (já configurado em
`AiCommandService._baseUrl`).

### Status do deploy (sessão de 2026-07-03)

| Etapa | Status |
|---|---|
| Código do backend copiado pra VPS (`/root/ai_command_server/`) | ✅ Feito |
| `serviceAccountKey.json` do Firebase (Admin SDK, gerado em Contas de Serviço) | ✅ Feito |
| `.env` com `GROQ_API_KEY` (chave nova, gerada após a exposição na conversa) | ✅ Feito |
| venv Python + dependências (`requirements.txt`) | ✅ Feito |
| Serviço systemd `melembra-ai-backend` ativo, porta **8091** | ✅ Feito — `curl http://127.0.0.1:8091/healthz` responde `{"status":"ok"}` |
| nginx (proxy reverso `api.melbrai.com.br` → 8091) | ✅ Configurado (`nginx -t` a confirmar) |
| DNS: registro A `api` → `204.168.180.25` | ✅ Resolve (confirmado na sessão 19) |
| Certificado HTTPS (`certbot --nginx`) | ✅ **Emitido e implantado na sessão 19** (usuário rodou `certbot --nginx -d api.melbrai.com.br --non-interactive --agree-tos -m fasterdrible@gmail.com --redirect` via SSH) — expira em 2026-11-17, renovação automática configurada pelo certbot |
| Teste de fora (`curl https://api.melbrai.com.br/healthz`) | ✅ Responde `{"status":"ok"}` sem erro de TLS (confirmado após o certbot) |
| Rebuild do APK com o domínio real (já feito, v1.4.2) | ✅ Feito — backend agora acessível por HTTPS |

**Achado da sessão 19 (2026-08-19)**: investigando por que o "Falar Comando"
não entende bem os comandos, uma requisição HTTPS externa a
`https://api.melbrai.com.br/healthz` falha com
`Hostname/IP does not match certificate's altnames: Host: api.melbrai.com.br
is not in the cert's altnames: DNS:api.xn--egidelicitaes-sgb4s.com.br` — o
nginx da VPS compartilhada está servindo o certificado TLS de **outro**
projeto do usuário para esse domínio (provavelmente porque nunca rodou
`certbot --nginx -d api.melbrai.com.br` com sucesso, então cai no
`server{}` padrão/catch-all do nginx). Resultado: **toda chamada HTTPS do
app pro backend de IA falha na validação do certificado**, é engolida
silenciosamente por `AiCommandService.interpretar()` (`catch (_) { return
null; }`, sem log até a sessão 19) e o app cai sempre no parser local
básico — que só entende os atalhos fixos ("ouvir lembretes", "meus
alertas", "adicionar X na lista"); qualquer outra frase vira "criar
lembrete" de forma literal. **Isso explica a percepção de "não entende bem
os comandos": a IA (Groq) nunca chega a ser chamada de verdade.**
Corrigido na sessão 19: `AiCommandService.interpretar()` agora loga
(`debugPrint`) o status HTTP ou a exceção antes de cair no fallback, pra
facilitar diagnóstico via `adb logcat` no futuro. **Resolvido também na
sessão 19**: usuário autorizou acesso SSH e rodou `certbot --nginx -d
api.melbrai.com.br --non-interactive --agree-tos -m fasterdrible@gmail.com
--redirect` na VPS — certificado emitido e implantado com sucesso,
`curl https://api.melbrai.com.br/healthz` de fora responde `{"status":"ok"}`
sem erro de TLS. TASK-29 fechada.

### Percalços encontrados durante o deploy (registrados pra não repetir)

- **VPS compartilhada**: `204.168.180.25` não é dedicada ao Me Lembra Aí — tem
  vários outros projetos do usuário (containers Docker, nginx próprio,
  uvicorn, mysql, postgres, redis, apps Node/Next). Portas já ocupadas:
  8001, 8000, 8080, 6001, 6002, 3001, 3002, 4000, 4100, 3100 — **sempre
  checar com `ss -tlnp` antes de escolher uma porta nova**. O backend de IA
  ficou na **8091** (a 8001, usada no plano original, já estava ocupada por
  um container Docker de outro projeto).
- **`sos_notifier.py` nunca foi implantado nessa VPS de verdade** —
  `/root/sos_notifier/` não existe, `systemctl status sos-notifier` não
  encontra a unit. Ou seja, o push de SOS quando o app do familiar está
  fechado **provavelmente não funciona em produção hoje**, apesar de constar
  como concluído no histórico (sessão 5). Lacuna pré-existente, descoberta
  nesta sessão, sem relação com o backend de IA — precisa de investigação e
  deploy separados (ver "Lacunas e limitações conhecidas").
- **Ubuntu 24.04 bloqueia `pip install` fora de venv** (PEP 668) — o serviço
  usa `python3 -m venv venv` + `venv/bin/pip`, e o `.service` aponta pro
  gunicorn dentro do venv (`/root/ai_command_server/venv/bin/gunicorn`).
- **Dois vazamentos de segredo na conversa durante o deploy**: (1) uma chave
  da API da Groq colada em texto plano (revogada e substituída); (2) um
  `GITHUB_TOKEN` que apareceu no conteúdo de um `/root/.env` criado sem
  querer (por um `cp` que falhou seguido de `nano .env`, que criou um
  arquivo novo vazio) — esse arquivo foi apagado (`rm -f /root/.env`), mas o
  token em si precisa ser revogado no GitHub (Settings → Developer settings
  → Personal access tokens) se ainda não foi.
- **`google-services.json` ≠ `serviceAccountKey.json`**: são dois arquivos
  diferentes do Firebase Console. O primeiro (aba "Geral" → "Seus apps") é a
  config do app Android, pública por natureza. O segundo (aba "Contas de
  serviço" → "Gerar nova chave privada") é a credencial de admin do
  `firebase-admin` usada pelo backend — foi confundido duas vezes antes de
  achar o certo.
- **Clone Git órfão em `/root/ME-LEMBRA-AI`**: pasta antiga (abril/2026),
  estrutura bem diferente do repositório atual, com **segredos em arquivos
  não commitados** (`me_lembra_ai/.env`, `google-services.json`). Não foi
  tocada nesta sessão — fica como item de limpeza separado, precisa de
  autorização explícita do usuário antes de mexer (pode ter algo em uso).

### Comandos de deploy (referência, já executados na VPS)

```bash
# na VPS, depois de copiar server/ai_command_server/ e o serviceAccountKey.json
cd /root/ai_command_server
cp .env.example .env && nano .env   # GROQ_API_KEY=chave_nova

python3 -m venv venv
venv/bin/pip install -r requirements.txt

cp melembra-ai-backend.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now melembra-ai-backend
curl http://127.0.0.1:8091/healthz   # {"status":"ok"}

cp nginx-api.conf /etc/nginx/sites-available/api.melbrai.com.br
ln -s /etc/nginx/sites-available/api.melbrai.com.br /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# só depois do DNS propagar:
certbot --nginx -d api.melbrai.com.br
curl https://api.melbrai.com.br/healthz   # teste final de fora
```

---

## Deploy do sos_notifier.py no VPS

```bash
ssh root@204.168.180.25
cp /local/server/sos_notifier.py /root/sos_notifier/sos_notifier.py
systemctl restart sos-notifier
systemctl status sos-notifier
```

Para instalação inicial (Ubuntu 24.04 bloqueia `pip install` fora de venv — PEP 668,
mesma lição do `ai_command_server`):

```bash
mkdir -p /root/sos_notifier
# Copiar server/sos_notifier.py, requirements.txt, sos-notifier.service para /root/sos_notifier/
# serviceAccountKey.json: reaproveitar /root/ai_command_server/serviceAccountKey.json
#   se for o mesmo projeto Firebase, ou baixar um novo em
#   Firebase Console → Configurações → Contas de serviço → Gerar nova chave privada
python3 -m venv /root/sos_notifier/venv
/root/sos_notifier/venv/bin/pip install -r /root/sos_notifier/requirements.txt
cp /root/sos_notifier/sos-notifier.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now sos-notifier
systemctl status sos-notifier --no-pager   # deve mostrar "Ouvindo sos_alerts criados após ..."
```

> **Atenção:** o `ExecStart` da unit aponta para `/root/sos_notifier/venv/bin/python3`,
> não `/usr/bin/python3` — sem isso o serviço falha ao importar `firebase_admin`
> (não instalado no Python do sistema).

---

## Histórico de sessões

| Sessão | Data | Principais entregas |
|---|---|---|
| 22c | 2026-08-21 | **Coleta de dia/hora do lembrete sai da IA, vira determinística.** Testes ao vivo do assistente conversacional (TASK-32) mostraram a IA (`openai/gpt-oss-20b`) "esquecendo" repetidamente o que já tinha sido dito entre turnos — perguntava tipo depois do usuário já ter dito, não reconhecia "15" como resposta a "que horas?", repetia a mesma pergunta — mesmo com reforço no prompt (tentado e não resolveu). A pedido do usuário, pesquisado o padrão validado de mercado em vez de mais tentativa e erro: Rasa (framework de chatbot mais usado) usa um extrator determinístico (Duckling) pra data/hora em vez do modelo de linguagem; a OpenAI recomenda oficialmente, pra function calling multi-turno, não depender do modelo lembrar dado que o código já sabe ("offload the burden from the model and use code where possible"). Implementado: a partir do primeiro `perguntar` da IA, a conversa entra em modo de coleta 100% local — novos extratores nullable `_extrairData`/`_extrairHora` (diferentes de `_parsearDataHora`, que sempre assume "agora" se não achar nada) extraem dia/hora turno a turno **sem nenhuma chamada de IA adicional**; título/tipo/recorrência continuam vindo do parser local de sempre. Rede de segurança pontual da sessão anterior (só pra resposta curta de horário) removida, substituída por este mecanismo mais geral. Prompt do backend simplificado de volta (regra que não funcionou, removida). **Confirmado pelo usuário no aparelho físico**: "marcar consulta ginecologista dia 28 de setembro" (sem hora) → perguntou só "Que horas?" (sem repetir pergunta de tipo/dia) → respondeu a hora → criou o lembrete certo. v1.5.2+23. Deploy do `app.py` simplificado na VPS é só limpeza agora (o app não manda mais as respostas curtas pra IA de jeito nenhum, então a regra removida do prompt já não tinha efeito prático) — pode ser feito quando conveniente, sem urgência. |
| 22 | 2026-08-21 | **"Modo Proteção" não mantinha o detector de queda funcionando com o app fechado.** Usuário testou (5 toques de volume + detector de queda, ambos com "Modo Proteção" ativado e o app fechado) e nenhum dos dois disparou. Investigação achou a causa raiz: `SosProtectionService.kt` é um Foreground Service **puramente nativo**, sem nenhuma ligação com o `FlutterEngine` — e `MainActivity.kt` usa o ciclo de vida padrão do `FlutterActivity`, onde o engine (e todo o código Dart, incluindo `FallDetectorService`) é destruído junto com a Activity quando o app é fechado. O comentário no código ("mantém o SosListenerService e o FCM ativos") estava incorreto na prática — o Foreground Service só mantinha o processo Android vivo e a notificação visível, sem nenhum Dart rodando por trás. **5 toques no volume**: confirmado que não dá pra corrigir sem Accessibility Service (decisão consciente de não implementar, por exigir consentimento extra) — fica documentado como limitação permanente. **Detector de queda**: corrigido de verdade — `SosProtectionService.kt` agora cria um `FlutterEngine` headless (sem UI) quando "Modo Proteção" é ativado, rodando um novo entrypoint Dart dedicado (`fallDetectorEntrypoint` em `lib/main.dart`, via `DartExecutor.executeDartEntrypoint` com entrypoint nomeado — sem precisar de plugin de terceiros como `workmanager`/`android_alarm_manager_plus`, nenhum dos dois estava no projeto). O canal `com.melembra.ai/call` (ligação automática do SOS) foi extraído de `MainActivity.kt` pra um novo `CallChannel.kt` compartilhado, já que precisa ser registrado tanto no engine em primeiro plano quanto no headless. Testado no aparelho físico: confirmado via log que o engine headless nasce, inicializa o Firebase e chama `FallDetectorService.start()`, e que o processo continua vivo (sem crash) depois do app fechado. **Limitação de teste**: o aparelho de referência (R9QL200MJ0N) não tem acelerômetro, então o disparo real de uma queda não pôde ser validado nesta sessão — só a infraestrutura (engine nascendo, não travando). Trade-off assumido (decisão do usuário): queda detectada com o app fechado dispara o SOS **direto**, sem a tela de confirmação/cancelamento de 5s que existe no fluxo em primeiro plano (não tem como mostrar diálogo sem tela). Achado relacionado, fora de escopo: `SosListenerService` (lado do cuidador) tem exatamente o mesmo problema — registrado como lacuna conhecida, não corrigido. v1.5.1+22 (versionCode ajustado depois, no fim da sessão). **Explorado e descartado na mesma sessão**: usuário perguntou se a tecla lateral (liga/desliga) do celular poderia acionar o app — confirmado que não (Android bloqueia até Accessibility Service de interceptar essa tecla). Chegou a ser planejado e implementado um gatilho alternativo via SMS (aproveitando que o SOS de Emergência nativo do Samsung manda SMS pra contatos configuráveis, capturado por um backend novo), mas o usuário decidiu descartar a ideia depois — código revertido, nada ficou no repositório. |
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
| 13c | 2026-07-02 | Debug via `adb logcat` no aparelho físico (R9QL200MJ0N) confirmou que a ligação em si funcionava (Telecom `Allowed`, chegou a `DIALING`); o "número incorreto" era o próprio número salvo com erro de digitação — confirmado pelo usuário testando o mesmo número direto no discador nativo. Bug real encontrado nessa investigação: o toggle "Botão de Pânico (SOS)" nunca era checado em `SosService.trigger()` — desativá-lo não impedia a ligação. Corrigido: `trigger()` agora retorna cedo se `SettingsService.getSos()` for `false`; `elderly_screen.dart` mostra aviso e não roda mais a contagem regressiva/voz quando o SOS está desativado. v1.3.3 |
| 13d | 2026-07-02/03 | Usuário confirmou que o número (11940066219) está correto e às vezes funciona — erro intermitente, não número errado. Log mostrou `MAKE_ROOM_FOR_OUTGOING_CALLS` e disconnect REMOTE/SIP 487, condizente com duas ligações se sobrepondo. Causa: `SosService.callNumber()`/`trigger()` não tinham proteção contra chamadas concorrentes (botão, voz, 5 toques, volume e detector de queda podem todos acionar o mesmo fluxo). Corrigido: trava estática `_ligando` + cooldown de 10s em `sos_service.dart`; trava `_sosEmExecucao` em `elderly_screen.dart` (fluxo extraído para `_executarFluxoSOS()`). v1.3.4 |
| 13e | 2026-07-03 | Erro persistiu mesmo sem sobreposição. Debug profundo via `adb logcat` + `dumpsys telecom` no aparelho físico eliminou hipóteses de código: (1) trocada API de `Intent.ACTION_CALL` para `TelecomManager.placeCall()` (API recomendada pelo Google) em `MainActivity.kt` — mesmo resultado; (2) confirmado só 1 `PhoneAccount`/SIM registrado (sem ambiguidade de chip); (3) ligação disparada **sem nenhum código do app**, direto via `adb shell am start -a android.intent.action.CALL`, falhou idêntico. Conclusão: chamada chega à pilha VoLTE (`ResipVolteHandler`/`StackIF`) e é cancelada pela **rede** (`Code: REMOTE`, SIP 487 `CODE_SIP_REQUEST_CANCELLED`) — fora do controle do app. Mitigação implementada: `SosService.openDialer()` (abre discador com número preenchido, sem tentar ligar automaticamente — mesmo caminho de uma ligação digitada à mão) + tela "Confirmar chamada de emergência" com botão "LIGAR AGORA" por contato, sempre exibida após `trigger()` em `elderly_screen.dart` e `map_screen.dart` (antes só aparecia com 2+ contatos). Alerta Firestore + aviso ao chat da família continuam funcionando independente da ligação. v1.3.6 |
| 13f | 2026-07-03 | **Causa raiz encontrada e corrigida.** Print da tela do discador nativo confirmou que o número chega intacto (`11 94006-6219`, idêntico ao salvo) — descartando de vez erro de digitação/corrupção. Teste via `adb shell am start` comparando `tel:11940066219` (sem +55) vs `tel:+5511940066219` (com +55) mostrou a diferença: **sem** o código do país a operadora rejeita a chamada em 4-8s (`SET_DISCONNECTED Code: REMOTE`, SIP 487); **com** `+55`, o Android converte automaticamente para `015...` (código de acesso nacional) e a chamada toca normalmente por ~16s até `CODE_USER_TERMINATED_BY_REMOTE` (comportamento normal de chamada não atendida). Essa operadora/SIM exige formato E.164 para rotear corretamente chamadas de saída via VoLTE, mesmo para números nacionais. Corrigido: `SosService._paraE164()` normaliza todo número para `+55...` antes de discar (em `callNumber()` e `openDialer()`) quando ainda não tem `+`. **Confirmado funcionando pelo usuário em teste real.** v1.3.7 |
| 13g | 2026-07-03 | Melhoria de UX sugerida pelo usuário: campo de contato SOS em `config_screen.dart` agora mostra `+55` fixo como `prefixText` (não editável, não faz parte do texto digitado) — reforça visualmente o formato correto sem mudar o dado salvo, já que a normalização para E.164 continua acontecendo em `_paraE164()` na hora de discar. v1.3.8 |
| 14 | 2026-07-03 | Reformulação de UX do perfil Idoso: botão único "Falar Comando" absorve os antigos botões separados "Ouvir lembretes de hoje", "Criar lembrete por voz" e "Meus Alertas SOS" (removidos da tela). Novo roteador `_processarComando()` em `elderly_screen.dart` classifica a frase reconhecida por palavras-chave e decide a ação (ouvir lembretes / criar lembrete / adicionar item na lista / falar resumo de alertas), reaproveitando o parser de NLU já existente (`_parsearDataHora`, `_limparTitulo`, `_inferirTipo`, `_inferirRecorrencia`). "SOCORRO" continua com prioridade máxima a qualquer momento da escuta. Novo `_falarResumoAlertas()` lê em voz alta um resumo dos alertas SOS (via `SosFeedService`) em vez de abrir tela. Objetivo: minimizar necessidade de toque/digitação para o usuário idoso. v1.4.0 |
| 15 | 2026-07-03 | Pedido do usuário: app "interagindo com o usuário" como um agente. Avaliado o framework Hermes Agent (não aplicável — é um agente de terminal, não conversa por voz num app mobile). Decidido: backend próprio na VPS (`server/ai_command_server/`, Flask) chamando a **API da Groq** (`llama-3.3-70b-versatile`, escolha do usuário, tier grátis) para interpretar frases que não batem nas regras locais rápidas, devolvendo ação estruturada em JSON. Autenticação via `firebase_admin.auth.verify_id_token` (reaproveita o `serviceAccountKey.json` do `sos_notifier.py`). App: nova dependência `http`, novo `lib/services/ai_command_service.dart` (`AiCommandService.interpretar`, timeout 6s, retorna `null` em qualquer falha), `_processarComando` tenta a IA antes do parser local (fallback automático offline). SOS continua 100% local, inalterado. **Bloqueado até ter domínio configurado** (`AiCommandService._baseUrl` é um placeholder) — ver seção "Backend de comando de voz por IA" acima. **Nota de segurança**: usuário colou uma API key da Groq em texto plano na conversa — precisa revogar e gerar uma nova antes do deploy. v1.4.1 (Flutter pronto; backend aguardando deploy) |
| 16 | 2026-07-03 | Deploy real do backend de IA na VPS `204.168.180.25`. Domínio definido: `api.melbrai.com.br` (primeira tentativa usou domínio errado — `mylaassistente.com.br`, de outra aplicação do usuário — revertida antes de commitar). Backend rodando com sucesso na porta **8091** (trocada de 8001 por conflito com container Docker de outro projeto — VPS é compartilhada com vários outros projetos do usuário). Corrigido: venv Python (Ubuntu 24.04 bloqueia pip fora de venv, PEP 668), `serviceAccountKey.json` novo gerado no Firebase Console (não existia `/root/sos_notifier/` pra reaproveitar — descoberto que o `sos_notifier.py` nunca foi implantado nessa VPS de fato, apesar da documentação dizer o contrário — ver "Lacunas"). Confundido duas vezes `google-services.json` (config Android) com o `serviceAccountKey.json` (Admin SDK) até achar a aba certa no Firebase Console. **Dois vazamentos de segredo tratados**: chave da Groq (revogada e trocada) e um `GITHUB_TOKEN` que apareceu num `/root/.env` criado sem querer (apagado; token precisa ser revogado no GitHub se ainda não foi). Achado e não tocado: clone Git órfão em `/root/ME-LEMBRA-AI` com segredos soltos em arquivos não commitados — fica pra limpeza futura, com autorização explícita. **Pendente**: DNS do `melbrai.com.br` migrando pra Cloudflare (~45 min), registro A `api` ainda não confirmado, certificado HTTPS via certbot bloqueado até isso propagar. v1.4.2 (código sem mudança nesta sessão — só infraestrutura) |
| 17 | 2026-08-19 | **`sos_notifier.py` implantado de verdade na VPS `204.168.180.25`**, fechando a lacuna descoberta na sessão 16. Acesso via SSH com senha (chaves SSH locais do usuário eram de outros projetos, nenhuma valia pra essa VPS). Reaproveitado `serviceAccountKey.json` de `/root/ai_command_server/` (mesmo projeto Firebase `me-lembra-ai-bf0f0`) — não precisou gerar chave nova. Aplicada a mesma lição da sessão 16: venv Python (`python3 -m venv` + `venv/bin/pip install -r requirements.txt`), já que Ubuntu 24.04 bloqueia pip fora de venv (PEP 668) — `sos-notifier.service` (local e remoto) corrigido para apontar `ExecStart` pro `venv/bin/python3` em vez de `/usr/bin/python3`. Serviço ativado via `systemctl enable --now sos-notifier`, confirmado `active (running)` com log `Ouvindo sos_alerts criados após ...`. Nesta sessão também foi criado o **Hermes Dev** (`server/hermes_dev/` + `.claude/agents/hermes-*.md` + `.claude/skills/hermes-dev/`) — Fase 1 de um sistema de manutenção autônoma supervisionada pro código do app, separado do Hermes Produto (avaliado e descartado na sessão 15); ver `server/hermes_dev/README.md`. v1.4.2 (código do app sem mudança — infraestrutura + tooling de desenvolvimento) |
| 18 | 2026-08-19 | Testado o app num emulador Android e no celular físico (R9QL200MJ0N) a pedido do usuário. **Achado crítico de ambiente**: cache do `pub` com 18 pacotes corrompidos (pastas vazias, sem `pubspec.yaml`/`android/`), incluindo `firebase_core`, `cloud_firestore`, `firebase_auth`, `firebase_storage` e `jni` — bloqueava qualquer build (debug ou release) com erro enganoso do Gradle ("Could not find the firebase_core FlutterFire plugin"). Corrigido removendo as pastas vazias de `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\` e forçando `flutter pub get` de novo (nota adicionada em "Como buildar" acima). App confirmado funcionando no celular físico após a correção — abriu sem crash, dados reais carregando do Firestore. Achado menor: `PlatformException(NO_SENSOR)` não tratada em `sensors_plus` (detector de queda) nesse aparelho específico, que não tem acelerômetro — não derruba o app, mas é uma exceção não tratada. |
| 19 | 2026-08-19 | **Data/horário nos lembretes**: Remédios/Consultas/Aniversários/Eventos/Outros em `meus_lembretes_screen.dart` agora mostram "Hoje/Amanhã/dd-mm-aaaa · HH:mm" (`_formatarDataHora()`, `intl`) em vez de só a hora. **"Falar Comando" não entendia bem — investigação completa**: (1) certificado HTTPS de `api.melbrai.com.br` nunca tinha sido emitido (nginx sem bloco `listen 443` pra esse domínio, caía no certificado de outro projeto na VPS compartilhada) — **corrigido nesta sessão**: usuário rodou `certbot --nginx -d api.melbrai.com.br --non-interactive --agree-tos -m fasterdrible@gmail.com --redirect` via SSH (autorizado explicitamente pelo usuário, já que acesso SSH remoto é bloqueado por padrão pelo modo automático), confirmado `curl https://api.melbrai.com.br/healthz` de fora responde `{"status":"ok"}` — TASK-29 fechada. (2) `AiCommandService.interpretar()` e `_processarComando()` ganharam `debugPrint` (não tinha log nenhum antes). (3) Verbos formais do imperativo ("adicione", "coloque", "inclua", "bote", "acrescente", "ponha") faltavam em `_isAdicionarNaLista`/`_extrairItensDoComando` em `elderly_screen.dart` — comandos como "adicione carne..." caíam no parser genérico de lembrete. (4) `_adicionarItensNaLista` procurava lista de compras existente por texto solto (`contains('mercado')`) em vez do tipo exato — podia grudar item em lembrete errado; corrigido pra `r.type == 'Compras'` apenas. (5) `_inferirTipo()` tinha fallback perigoso pra `'Remedio'` quando não reconhecia a frase (podia sujar a lista de remédios reais); trocado pra `'Lembrete'` genérico. (6) Ampliados os padrões de destino reconhecidos ("ao mercado", "pra lista", "para o mercado"). (7) **Causa mais profunda encontrada via log real**: o STT estava cortando a frase no meio ("adicionar carne à lista **do**", "adicionar carne **ao**" sem completar) — `pauseFor` de 3s era curto demais pra alguém que fala com pausas; aumentado pra 6s (`listenFor` de 12s pra 25s) em `_falarComando()`. **Hermes Dev removido do projeto** a pedido do usuário (`.claude/agents/hermes-*.md`, `.claude/skills/hermes-dev/`, `server/hermes_dev/`) — antes de apagar, uma correção não commitada num worktree do Hermes (`bug-001-fcm-token-cuidador`) foi resgatada e trazida pra `main`: `FcmService.init()` não era chamado no fluxo de login/cadastro que vai direto de `ProfileSelectionScreen` pra tela do perfil sem nunca construir a `HomeScreen` — cuidadores recém-cadastrados podiam nunca ter o `fcmToken` salvo, quebrando o push de SOS pra eles. `init()` agora é idempotente (guarda `_listenersRegistered`) e chamado também em `_goToProfile()`; teste de regressão `test/profile_selection_screen_test.dart` + mock `test/support/firebase_core_mocks.dart` adicionados e passando. Suíte completa rodada: 16 passando (15 antigos + o novo), 6 falhando em `test/reminder_service_test.dart` — **pré-existente, de abril, não relacionado a esta sessão**. |
| 21 | 2026-08-20 | **Continuação da sessão — TASK-30 (verificação da IA) e TASK-32 (assistente conversacional).** Ao tentar validar a TASK-30 no aparelho físico, achada a causa raiz real do "Falar Comando não entende": a Groq **descontinuou o modelo `llama-3.3-70b-versatile`** (toda chamada retornava 404 `model_not_found`, silenciosamente engolida e caindo no parser local) — isso já vinha falhando desde 19/08, depois do certificado ter sido corrigido na sessão 19, então a TASK-29 resolveu o TLS mas não a causa raiz de verdade. Confirmado via `journalctl -u melembra-ai-backend` na VPS e via `curl .../v1/models` com a chave real: lista de modelos de texto em produção hoje é `openai/gpt-oss-20b` / `openai/gpt-oss-120b` (a Groq trocou o catálogo inteiro — nada de Llama 3.x, Mixtral ou Gemma sobrou). Corrigido: `GROQ_MODEL` default no código e no `.env` da VPS trocado para `openai/gpt-oss-20b`; `.env.example` documentado com aviso de que isso pode acontecer de novo. **A pedido do usuário, "Falar Comando" foi evoluído pra um assistente conversacional multi-turno (TASK-32)**, com guardrails explícitos contra alucinação (ver ARCHITECTURE.md, seção "Comando de voz"): nova ação `perguntar` pra IA pedir esclarecimento em vez de inventar dado faltante; contexto real dos lembretes (título/tipo/data, e itens da lista de compras) enviado a cada chamada; histórico limitado às últimas 3 trocas; `temperature=0.2`; limite de 6 turnos por conversa; encerramento por frase ("obrigado"/"pode parar") ou silêncio — sem precisar tocar o botão a cada fala. Testado ao vivo e extensivamente no aparelho físico pelo usuário: pergunta de esclarecimento funcionando, criação de lembrete após resposta funcionando, limite de 6 turnos confirmado ("avisou e parou"), fallback local em uma falha pontual de rede não travou a conversa. Achado e corrigido no meio do teste: o resumo de lembretes mandado pra IA não incluía a descrição (onde ficam os itens da lista de compras) — a IA corretamente não inventou o conteúdo (guardrail funcionando), mas também não conseguia responder "o que tem na minha lista" por falta de dado; corrigido incluindo os itens no contexto só para lembretes tipo Compras. Sem exclusão/edição de lembretes por voz nesta versão (fora de escopo, decisão do usuário) e sem mudança no pipeline de SOS. v1.5.0+19 (só build debug testada; release ainda não gerado). Deploy do backend feito pelo próprio usuário via SSH (autorizado explicitamente, três vezes: código novo, correção do modelo, correção do contexto de lembretes). **Bug achado em teste ao vivo (TASK-33)**: dizer "SOCORRO" às vezes fazia o app falar "não entendi" e disparar o SOS ao mesmo tempo — causa raiz: `onStatus` do STT reporta "done"/"notListening" (com `_capturaComando` ainda vazio) um instante antes de `onResult` entregar o texto reconhecido, então `_processarComando('')` rodava e falava "não entendi" antes do evento com "SOCORRO" chegar e acionar o SOS de verdade pelo caminho correto. Corrigido com uma espera de 400 ms + checagem de `_sosDisparado` antes de falar "não entendi", sem alterar a lógica/timing do SOCORRO em si (prioridade máxima, sempre local). Confirmado corrigido pelo usuário no aparelho físico. v1.5.0+19. |
| 21 (áudio) | 2026-08-20 | **TASK-31 (não planejada, achada durante verificação da TASK-30): Chat Familiar não gravava áudio.** Usuário reportou "envio de áudio não está gravando" ao testar. Diagnóstico ao vivo no celular físico (R9QL200MJ0N), com build debug instrumentado com `debugPrint` temporário em `chat_screen.dart` e `adb logcat`: o botão de microfone usava o gesto "segurar para gravar / soltar para enviar" (`onLongPressStart`/`onLongPressEnd`), mas o usuário soltava o dedo rápido demais — 2 tentativas nem venceram o threshold de long-press do Flutter (~500ms, viraram `onLongPressCancel`), e a 3ª tentativa gravou de verdade (permissão OK, arquivo criado, `record.start()` concluído sem erro) mas foi interrompida 106ms depois por um `onLongPressEnd` prematuro — áudio efetivamente vazio. Não era bug de código, e sim um gesto pouco tolerante pro público do app (idosos/família). **Corrigido**: trocado o gesto de "segurar/soltar" para "toque único" (toca pra iniciar, toca de novo no mesmo botão pra parar e enviar) em `chat_screen.dart` — mais robusto e mais fácil pro público-alvo, mesmo padrão de simplificação já usado no "Falar Comando" (sessão 14). Testado no aparelho físico com a correção: gravação de ~15s completada, upload pro Firebase Storage confirmado com sucesso (URL com token gerado), reprodução tocando normalmente — **confirmado pelo usuário ouvindo o áudio real**. Isso também fecha de fato a lacuna "upload 404" registrada na sessão 19/20 (o Storage aparentemente já está provisionado/Blaze ativo; não foi mais reproduzido). Prints de diagnóstico (`debugPrint('DEBUG_AUDIO: ...')`) removidos do código final. v1.4.3+18 (só build debug testada; release ainda não gerado). Ainda na mesma sessão, usuário reportou baixa responsividade no **botão de play** das mensagens de áudio ("tive que tocar bem no centro", "no WhatsApp é bem melhor"). Duas causas: (1) `IconButton` com `constraints: BoxConstraints(minWidth: 36, minHeight: 36)` — abaixo do alvo de toque mínimo recomendado (48×48dp); (2) `_togglePlay()` só chamava `setState()` **depois** do `await _player.play()` resolver, ou seja, o ícone só trocava de play→pausa depois que o áudio terminava de carregar da rede (1-2s de buffering do Firebase Storage), dando sensação de botão travado. Corrigido: alvo de toque para 48×48; `setState(() => _playingId = m.id)` agora roda **antes** do `await _player.play()` (feedback otimista imediato), com rollback se o play() falhar. **Confirmado pelo usuário: "ficou bom".** TASK-30 (verificação do "Falar Comando" com a IA) ainda pendente — não chegou a ser testada nesta sessão porque o trabalho no Chat Familiar tomou o tempo da sessão. |
| 20 | 2026-08-19 | **"Tomar Água" não mostrava lembretes criados com essa categoria** — a seção em `meus_lembretes_screen.dart` só renderizava o contador de copos (`_aguaWidget()`), nunca os lembretes tipo `'Tomar'` (criáveis manualmente na tela Adicionar); corrigido pra listar os dois. Também corrigido `_inferirTipo()` em `elderly_screen.dart`: "tomar água" por voz virava categoria "Remédio" por engano (palavra "tomar" misturada nas palavras-chave de remédio) — agora checa "água"/"agua" antes e categoriza como "Tomar". **Chat Familiar — duas melhorias pedidas pelo usuário**: (1) opção de excluir mensagem (long-press na própria bolha, `ChatService.deleteMessage()`, `firestore.rules` alterada de `allow update, delete: if false` pra permitir `delete` só do remetente — deploy feito com `firebase deploy --only firestore:rules,firestore:indexes --project me-lembra-ai-bf0f0`). (2) Botão de áudio investigado ao vivo no celular: a gravação em si funciona (confirmado via log nativo — captura e grava o arquivo normalmente), mas o **upload pro Firebase Storage falha com 404** ("server terminated the upload session"); não existe `storage.rules` no repo, suspeita forte de Storage nunca provisionado no Console (ver "Lacunas") — **não corrigido, requer o usuário verificar/ativar o Storage no Console do Firebase** (fora do alcance de correção só por código). |
