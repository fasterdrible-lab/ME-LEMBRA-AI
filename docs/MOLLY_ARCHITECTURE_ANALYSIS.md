# MOLLY_ARCHITECTURE_ANALYSIS.md — Auditoria pré-implementação

> Sessão 23 (2026-08-26). Produzido conforme a TAREFA 1 do prompt mestre da
> MOLLY. **Nenhum código de IA foi alterado nesta sessão** — este documento é
> o portão de entrada exigido antes da TAREFA 2 em diante.

---

## 0. Achado mais importante

**O app já tem ~80% do comportamento pedido para a "MOLLY" — só que
implementado como métodos privados dentro de `ElderlyScreen`
(`lib/features/elderly/elderly_screen.dart`, 1327 linhas), não como um
módulo isolado.** Desde a sessão 21/22 (TASK-30 a TASK-34), o botão "Falar
Comando" já é:

- conversacional multi-turno (até 6 turnos, encerramento por frase ou silêncio);
- híbrido offline-first (regras locais rápidas → IA remota → fallback local);
- com memória de curto prazo de fato (histórico de até 3 trocas + "slots"
  de coleta de dia/hora, ver `_mesclarSlots`/`_finalizarOuPerguntarProximoCampo`);
- com grounding real contra alucinação (`_lembretesParaContextoIA` manda só
  um resumo, nunca o Firestore inteiro);
- com "SOCORRO" sempre tratado 100% localmente, nunca pela IA, mesmo em
  qualquer turno da conversa.

Isso muda o enquadramento da tarefa: **não é greenfield, é extração e
generalização de lógica já testada em campo (aparelho físico, múltiplas
sessões).** O maior risco do projeto MOLLY não é "a IA não funciona" — é
**regredir um fluxo frágil e já ajustado por tentativa e erro em produção**
(ex.: TASK-33, a corrida entre STT `onStatus`/`onResult` que fazia o app
falar "não entendi" por cima do "SOCORRO"). Qualquer refatoração deve ser
incremental, com o mesmo comportamento validado passo a passo no aparelho
`R9QL200MJ0N`, nunca um rewrite de uma vez.

---

## 1. Inventário de serviços existentes e reaproveitamento para a MOLLY

| Serviço atual | API pública relevante | Reaproveitável por | Observação |
|---|---|---|---|
| `ReminderService` | `add`, `stream`, `getAll`, `delete`, `update`, `confirm` (todos estáticos, escopados ao `uid` logado) | `reminder_tool.dart` | Já dispara notificação ao familiar em `confirm()`. Não expõe "próximos N dias" nem "amanhã" prontos — precisa filtrar `getAll()`/`stream()` na tool. |
| `FamilyService` | `stream()`, `streamMonitored()`, `getOrCreateInviteCode()`, `linkWithCode()`, `unlink()` | `family_tool.dart` (getFamilyMembers) | **Não existe telefone por familiar** — só `uid`/`nome`/`perfil`/`papel`. Ver gap crítico na seção 3. |
| `ChatService` | `send()`, `sendAudio()`, `stream()`, `deleteMessage()`, `pairId()` | `family_tool.dart` (sendFamilyMessage) | Pronto para uso direto — `send(otherUid, texto)` já é exatamente a ferramenta pedida. |
| `SosService` | `trigger({motivo})`, `callNumber()`, `openDialer()` | `sos_tool.dart` | **Já verifica** o toggle "Botão SOS" (`SettingsService.getSos()`), já tem cooldown de 10s e trava contra chamada concorrente. A tool deve ser um wrapper fino — nunca reimplementar. |
| `LocationService` | `getCurrentPosition()`, `positionStream()` | `location_tool.dart` | Pronto. |
| `SettingsService` | toggles locais (SOS, chat, notificações, modo escuro/proteção, números SOS) | `molly_settings_screen.dart` (leitura/gravação de flags) | Adicionar aqui as novas flags da MOLLY (seção 6), no mesmo padrão estático. |
| `SosFeedService` | `streamOwnAlerts(uid)`, `streamForUsers(uids)`, `markViewed()` | resumo de alertas já usado em `_falarResumoAlertas` | Reaproveitar tal como está. |
| `ProfileService` | `getProfile()`, `getNameForSelectedProfile()`, `getNameForProfile()` | `profile_tool.dart` (getUserProfile) | Pronto. |
| `VoiceService` (TTS) | `speak()`, `enqueue()`, `speakAlert()`, `stop()`, `pause()`, `isSpeaking` | `molly_voice_service.dart` | Já tem fila e handlers de estado — a nova camada de voz deve **compor**, não substituir. |
| STT (`speech_to_text`) | usado **diretamente** em `_iniciarEscuta()`/`_finalizarComando()` dentro de `ElderlyScreen` | `molly_voice_service.dart` | **Não existe um `SttService` hoje** — é a única peça de voz sem wrapper próprio. Extrair essa lógica é passo obrigatório da Fase 2, e é onde mora o timing sensível de TASK-33 (`pauseFor: 6s`, `listenFor: 25s`, espera de 400ms antes de "não entendi"). |
| `AiCommandService` + `server/ai_command_server/app.py` | `interpretar(texto, historico, lembretesContexto)` → `ComandoAction` | base do `molly_agent_service.dart` | Ver seção 2 — hoje é enum fechado, não tool-calling de verdade. |
| `NotificationService` | canais Android, `scheduleReminder`, `showSosAlert`, `cancel` | briefing/proatividade | Reaproveitar canais existentes (`me_lembra_ai_idoso`, `sos_alert`) em vez de criar novos. |
| `WidgetService` | atualiza AppWidget a partir da lista de lembretes | não é ferramenta da MOLLY, mas dispara sozinho via `ReminderService.stream()` | Nenhuma ação necessária. |

---

## 2. O "tool calling" de hoje vs. o pedido no prompt mestre

O backend (`server/ai_command_server/app.py`) **não faz function/tool
calling de verdade** (não usa a API de `tools`/`tool_calls` da Groq). Ele
faz algo mais simples e, até aqui, suficiente: um **JSON de ação com enum
fechado** (`ACOES_VALIDAS = {criar_lembrete, ouvir_lembretes,
adicionar_item_lista, consultar_alertas, perguntar, responder}`),
validado no servidor (`ComandoAction.from_raw`) e despachado no cliente por
`_executarAcaoIA` (`elderly_screen.dart:578`).

Isso já cumpre, na prática, a regra "IA nunca acessa Firestore direto" —
o modelo só devolve uma intenção estruturada; quem executa é sempre código
Dart chamando os serviços acima. **Recomendação: generalizar esse padrão
em vez de trocá-lo por um mecanismo de tool-calling nativo da API.** Migrar
para `tool_calls` de verdade adicionaria complexidade (parsing de múltiplas
chamadas, encadeamento) sem necessidade clara no momento — o registro de
ferramentas pedido na TAREFA 3 pode ser implementado **no lado Dart**
(`MollyToolRegistry`), com o backend continuando a devolver uma ação por
vez dentro de um enum que cresce (novas ações: `chamar_familiar`,
`enviar_mensagem_familiar`, `consultar_perfil`, `confirmar_lembrete` etc.),
todas validadas em `ACOES_VALIDAS` como hoje.

Consequência prática: expandir o catálogo de ações exige alterar **os dois
lados** (`app.py` na VPS + `ai_command_service.dart` no app) e fazer deploy
do backend a cada nova ferramenta — mesmo processo operacional já
documentado em `docs/CURRENT_STATE.md` (systemd, nginx, certbot já
resolvidos; só o código do serviço muda).

---

## 3. Riscos identificados

1. **Acoplamento do fluxo conversacional à `ElderlyScreen`.** Extrair
   `_processarComando`, `_mesclarSlots`, `_finalizarOuPerguntarProximoCampo`,
   `_lembretesParaContextoIA`, `_executarAcaoIA`, `_criarLembreteDeAcao`,
   `_extrairData`/`_extrairHora` para `features/molly/` sem testar cada
   passo no aparelho físico pode reintroduzir bugs já corrigidos
   (TASK-32/33). Migrar por partes, mantendo `ElderlyScreen` funcionando a
   cada commit.
2. **SOS não pode perder nenhuma garantia.** `_acionarSOS`/`_executarFluxoSOS`
   hoje têm: dialog de countdown 5s cancelável, TTS "Emergência!", trava
   `_sosEmExecucao`, e o caminho "SOCORRO" que **pula** o countdown. Um
   `sos_tool.dart` genérico não deve ser chamado pelo LLM para decidir
   *se* dispara SOS — o disparo por voz continua sendo detecção de frase
   100% local (TAREFA 18 do prompt mestre já é explícita nisso). O tool só
   deve existir para consultas relacionadas (ex.: "quem é meu contato de
   emergência"), nunca para o disparo em si.
3. **Não existe telefone por familiar.** `FamilyMember` só tem
   `uid/nome/perfil/papel`. O comando de exemplo do prompt mestre — "Molly,
   liga para minha filha" — pressupõe uma ligação telefônica direta a um
   familiar específico, mas hoje o único número telefônico do app é o(s)
   "número(s) SOS" genérico(s) em `SettingsService` (`cfg_sos_numeros`),
   sem vínculo com um `FamilyMember`. **Decisão necessária antes da
   TAREFA 20**: (a) adicionar campo de telefone opcional a `FamilyMember`
   (mudança de schema + UI de cadastro), ou (b) reinterpretar "ligar para
   Ana" como "avisar a Ana pelo chat" quando não houver telefone salvo.
   Recomendo (b) como padrão e (a) como melhoria futura opcional — evita
   inflar o escopo da Fase 3.
4. **Catálogo de modelos da Groq é instável.** Já quebrou o app
   silenciosamente duas vezes (sessões 19 e 21, ver `CURRENT_STATE.md`).
   Qualquer ferramenta nova que dependa de uma chamada de IA herda esse
   risco. Manter o log de `debugPrint` já existente e o failsafe da
   TAREFA 25 é obrigatório, não opcional.
5. **Pasta órfã `me_lembra_ai/` na raiz do repositório** (com seu próprio
   `README.md`/`DEVLOG.md`) é uma cópia antiga, não o projeto ativo (o
   projeto ativo é a raiz — confirmado por `pubspec.yaml`,
   `android/app/build.gradle.kts` e `lib/` estarem todos na raiz). Não
   criar nada da MOLLY dentro dela por engano.
6. **Sem infraestrutura de teste para voz/conversa.** Os 15 testes de
   widget existentes cobrem só login e criação de lembrete por formulário.
   TAREFA 28/29 (testes de intenção, tool calling, segurança) partem do
   zero — não há mocks de `speech_to_text`/`flutter_tts`/`AiCommandService`
   hoje.
7. **Privacidade da memória de longo prazo.** `firestore.rules` hoje libera
   leitura de `users/{uid}/reminders` para familiares vinculados
   (`isFamilyOf`). Uma nova coleção `users/{uid}/molly_memory` **não deve**
   herdar essa regra por padrão — preferências pessoais do idoso não são
   automaticamente algo que a família deveria ler. Definir isso
   explicitamente na regra nova (recomendação: privado ao dono, sem
   `isFamilyOf`).
8. **Wake word e LiveKit são mudanças de peso pesado.** Nenhuma dependência
   de wake word (`porcupine_flutter` ou similar) ou WebRTC (LiveKit) existe
   hoje no `pubspec.yaml`. Ambas adicionam superfície nativa Android nova
   (permissões, serviços em background) num app que já tem um histórico de
   bugs sutis de ciclo de vida (ver sessão 22, `SosProtectionService.kt` /
   `FlutterEngine` headless). Tratar como as fases mais arriscadas do plano
   — só depois de Fases 1–5 estáveis, exatamente como o próprio prompt
   mestre já recomenda (TAREFA 16 e 33).

---

## 4. Dependências (pubspec.yaml) por fase

| Fase | Nova dependência necessária? |
|---|---|
| 1 (textual), 2 (voz), 3 (tools), 4 (memória), 5 (offline) | Nenhuma — tudo reaproveita `http`, `cloud_firestore`, `firebase_auth`, `flutter_tts`, `speech_to_text` já presentes. |
| 6 (wake word) | `porcupine_flutter` (ou equivalente) — avaliar impacto de bateria antes, atrás de `mollyWakeWordEnabled`. |
| 7 (LiveKit) | SDK LiveKit Flutter (WebRTC) — branch experimental separada, fora do build principal até validação. |

---

## 5. Arquitetura recomendada

Manter a estrutura de pastas proposta no prompt mestre
(`lib/features/molly/{screens,widgets,models,services,tools,memory,controllers}`),
com uma correção de estratégia:

- **`tools/*_tool.dart` são wrappers finos** sobre os serviços já
  existentes (tabela da seção 1) — nunca reimplementam lógica de
  Firestore/permissão que já existe em `ReminderService`, `SosService` etc.
- **`molly_agent_service.dart` generaliza `AiCommandService`**, não o
  substitui de imediato: mesmo padrão de chamada HTTP autenticada por ID
  token, mesmo backend na VPS, catálogo de ações crescente.
- **`molly_context_service.dart` reaproveita o padrão de
  `_lembretesParaContextoIA`**: nunca montar o contexto a partir do
  Firestore bruto, sempre um resumo pré-filtrado (grounding controlado).
- **Classificação de risco (LOW/MEDIUM/CRITICAL) fica no
  `molly_controller.dart`**, como metadado de cada entrada do
  `MollyToolRegistry` — nunca decidida pelo modelo de IA.
- **`molly_screen.dart` é aditiva**: pode ser construída em paralelo sem
  tocar `ElderlyScreen`, atrás de uma flag `mollyEnabled`. Só depois de
  validada em campo é que o botão "Falar Comando" passa a navegar para
  ela — a lógica inline de `ElderlyScreen` não precisa ser removida no
  mesmo commit que a nova tela nasce.

---

## 6. Feature flags novas (adicionar a `SettingsService`)

Seguindo o padrão estático já usado (`getX`/`setX` + `SharedPreferences`):

```text
mollyEnabled
mollyMemoryEnabled
mollyWakeWordEnabled
mollyRealtimeVoiceEnabled
mollyProactiveEnabled
```

Todas `false` por padrão, exceto quando a Fase correspondente estiver
validada — mesmo espírito do `cfg_modo_protecao`/`cfg_volume_sos` de hoje.

---

## 7. Plano de migração (mapeado às Fases do prompt mestre)

| Fase | O que muda de fato | Ponto de partida no código atual |
|---|---|---|
| 1 — Textual | Extrair `_processarComando`/`_criarLembreteDeAcao`/`_lembretesParaContextoIA` para `MollyAgentService` + `ReminderTool` + `ProfileTool` | `elderly_screen.dart:478,1104,450` |
| 2 — Voz | Extrair `_iniciarEscuta`/`_finalizarComando`/`_falar` para `MollyVoiceService` com estados idle/listening/thinking/speaking/error | `elderly_screen.dart:212,274,102` |
| 3 — Tool calling | Generalizar `ACOES_VALIDAS` (backend) + `_executarAcaoIA` (cliente) em `MollyToolRegistry`; adicionar `family_tool`, `sos_tool` (só consulta), `location_tool` | `app.py:60-67`, `elderly_screen.dart:578` |
| 4 — Memória | Curto prazo = extração do par histórico/slots já existente; longo prazo = nova coleção `users/{uid}/molly_memory` + regra Firestore própria + `molly_memory_screen.dart` | `_mesclarSlots`, `ConversaTurno` em `ai_command_service.dart` |
| 5 — Offline | Extrair a checagem local-primeiro (SOCORRO, regras rápidas, parser local) já existente em `_processarComando` para `OfflineIntentService` isolado e testável | `elderly_screen.dart:478` (primeiras ramificações) |
| 6 — Wake word | Novo, atrás de `mollyWakeWordEnabled`; avaliar bateria antes de ligar por padrão | — |
| 7 — LiveKit | Branch experimental `feature/molly-livekit`, sem tocar `main` | — |
| 8 — Proatividade | Novo `MollyProactiveService`, usa `ReminderService.getAll()` + `NotificationService` existentes para detectar remédio atrasado | `reminder_service.dart` |

---

## 8. Conclusão

Não há bloqueio técnico para iniciar a TAREFA 2. A recomendação é começar
pela Fase 1 como uma **extração** (não uma reescrita) do que já funciona em
`elderly_screen.dart`, validando cada método movido no aparelho físico
antes de avançar — na mesma disciplina que já levou às correções de
TASK-30 a TASK-34. O maior ganho de engenharia aqui não é "ligar uma IA
nova", é dar nome e testes ao que já existe, e só depois estender.
