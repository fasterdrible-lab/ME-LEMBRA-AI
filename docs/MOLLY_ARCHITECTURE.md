# Arquitetura da MOLLY

> TAREFA 34 do prompt mestre. Estado em 12/10/2026 (sessão 25, app 1.6.0).
> Documentos irmãos: [MOLLY_TOOLS.md](MOLLY_TOOLS.md) ·
> [MOLLY_MEMORY.md](MOLLY_MEMORY.md) · [MOLLY_SAFETY.md](MOLLY_SAFETY.md) ·
> [MOLLY_TESTING.md](MOLLY_TESTING.md) ·
> [MOLLY_ACCESSIBILITY_CHECKLIST.md](MOLLY_ACCESSIBILITY_CHECKLIST.md).
> Histórico de decisões e a auditoria original:
> [MOLLY_ARCHITECTURE_ANALYSIS.md](MOLLY_ARCHITECTURE_ANALYSIS.md).

A MOLLY é a assistente de voz do perfil **Melhor Idade**. Ela substituiu o
antigo "Falar Comando" (`_falarComando` em `elderly_screen.dart` continua no
arquivo, sem uso, para reverter se preciso).

## Princípio central

**Tudo que é crítico roda no celular, sem IA.** A IA (Groq, via backend na
VPS) só entra quando nenhuma regra local reconhece a frase. SOCORRO,
emergência, segurança de remédio, exclusão de lembretes e família nunca
dependem da IA nem de internet.

## Onde fica cada coisa

```
lib/features/molly/
  widgets/molly_assistant_panel.dart   ← a conversa (UI + máquina de turnos)
  widgets/listening_indicator.dart     ← "Estou ouvindo..." / "Pensando..."
  screens/molly_screen.dart            ← /molly, tela cheia (casca do painel)
  screens/molly_settings_screen.dart   ← /molly-settings
  screens/molly_memory_screen.dart     ← /molly-memory ("O que a Molly lembra")
  services/
    molly_agent_service.dart           ← núcleo: texto → resultado (um turno)
    offline_intent_service.dart        ← comandos locais (sem IA)
    molly_safety_service.dart          ← regras de saúde (entrada e saída)
    molly_medication_service.dart      ← "já tomei meu remédio hoje?"
    molly_family_intent.dart           ← "avisa a Ana que...", "quem acompanha..."
    molly_risk_policy.dart             ← LOW/MEDIUM/CRITICAL → confirmar ou não
    molly_tool_registry.dart           ← catálogo de ferramentas
    molly_voice_service.dart           ← STT + TTS, estados de voz
    molly_proactive_service.dart       ← remédio atrasado (15 min)
    molly_context_service.dart         ← resumo do usuário para a IA
    molly_prompt_service.dart          ← personalidade, respostas curtas
    molly_briefing_service.dart        ← bom dia às 8h
    molly_reminder_parser.dart         ← dia/hora/título/tipo de lembrete, local
    wake_word_service.dart             ← "Molly" por voz (só estrutura, sem uso)
  tools/                               ← ferramentas (ver MOLLY_TOOLS.md)
  memory/short_term_memory.dart        ← conversa atual
  memory/long_term_memory.dart         ← preferências (Firestore)
  models/                              ← MollyToolResult, MollyRiskLevel, ...

lib/services/ai_command_service.dart   ← cliente HTTP do backend de IA
server/ai_command_server/app.py        ← backend Flask (Groq) na VPS
server/ai_command_server/internet.py   ← previsão do tempo e notícias
```

## Como a Molly é aberta

| Entrada | O que acontece |
|---|---|
| Botão "Assistente Molly" (tela Melhor Idade) | `MollyAssistantPanel.abrirComoAtalho` — bottom sheet, já começa a ouvir |
| Configurações → Abrir Molly | rota `/molly`, tela cheia com a lista "Hoje" |
| Toque na notificação "Você conseguiu tomar seu remédio?" | `NotificationService.pedidosAbrirMolly` → a tela Melhor Idade abre o atalho |

Ao abrir, **antes de ouvir**, o painel checa remédio atrasado
(`MollyProactiveService`) — se houver, a conversa começa por essa pergunta.

## Um turno de conversa

```
Fala da pessoa (STT, MollyVoiceService)
  │
  ├─ durante a escuta: "SOCORRO" em qualquer parcial → SOS na hora (painel)
  │
  ▼ texto final (MollyAssistantPanel._processarFala)
  ├─ frase de encerramento ("obrigado", "pode parar") → "Até logo!"
  ├─ coletando dia/hora de um lembrete? → MollyReminderParser (local) → cria
  │
  ▼ MollyAgentService.processar(texto)
  1. OfflineIntentService.tentar   — socorro, emergência suave, excluir
  │                                  lembretes, família, que horas, meus
  │                                  lembretes, ligar para, confirmar
  │                                  remédio, contato de emergência
  2. MollySafetyService            — dose/indicação/diagnóstico, remédio a mais
  3. MollyMedicationService        — "já tomei meu remédio hoje?"
  4. AiCommandService.interpretar  — backend /interpretar-comando (Groq)
  │     └─ sem resposta → "Estou com dificuldade para responder agora..."
  5. ação da IA → MollyRiskPolicy → MollyToolRegistry (ver MOLLY_TOOLS.md)
  6. fala livre da IA → MollySafetyService.filtrarFalaDaIA
  7. proposta de memória (se autorizada) → painel pergunta antes de salvar
  │
  ▼ MollyToolResult → painel fala (TTS) e mostra; pode abrir uma etapa extra:
     confirmação de risco (sim/não) · contagem de emergência (Cancelar) ·
     confirmação de memória · coleta de mensagem para familiar
```

A ordem importa: o que vem antes tem prioridade. Ex.: "avisa minha filha que
estou passando mal" cai em emergência (1) antes de família.

## Backend de IA (VPS)

`POST https://api.melbrai.com.br/interpretar-comando`, autenticado com o ID
token do Firebase. Corpo:

```json
{"texto": "...",
 "contexto": {"agora": "ISO", "lembretes": [{"titulo","tipo","data_hora","itens"}],
              "modo_companhia": false, "localizacao": {"lat": -23.55, "lon": -46.63}},
 "historico": [{"usuario": "...", "assistente": "..."}]}
```

- `localizacao` só vai em perguntas de tempo (`AiCommandService.pareceTempo`),
  arredondada (~1 km), e só se a permissão já existir (nunca pede).
- Resposta: JSON com `acao` (`criar_lembrete`, `ouvir_lembretes`,
  `adicionar_item_lista`, `consultar_alertas`, `perguntar`, `responder`),
  `fala` e campos opcionais. O backend valida (`ComandoAction.from_raw`).
- `internet.py` busca previsão (Open-Meteo) ou manchetes (Agência Brasil)
  **só quando a frase pede**, com cache, e entrega à IA como "Informações
  da internet".
- Modelos: `GROQ_MODEL` (`openai/gpt-oss-20b`) e reservas
  `GROQ_MODELOS_RESERVA` (`openai/gpt-oss-120b`, `qwen/qwen3.8-27b`),
  tentados em ordem em qualquer falha. Cada modelo tem 8.000 tokens/min na
  conta gratuita; o prompt tem ~1.135 tokens.
- Tempos: app desiste em 8 s; internet até 2,5 s; cada modelo até 3 s;
  sem nova tentativa depois de 4 s.

Deploy: copiar `app.py`/`internet.py` para `/root/ai_command_server/` e
`systemctl restart melembra-ai-backend` (ver `CURRENT_STATE.md`, seção do
backend, e o checklist de "Molly não responde").

## Configurações que mudam o comportamento

Todas em `SettingsService` (SharedPreferences), editadas em
Configurações da Molly:

| Chave | Padrão | Efeito |
|---|---|---|
| `cfg_molly_ativa` | sim | esconde o botão "Assistente Molly" |
| `cfg_molly_resposta_voz` | sim | sem TTS; resposta só escrita |
| `cfg_voz_lenta` | não | taxa de fala 0,36 em vez de 0,48 (app todo) |
| `cfg_molly_memoria_autorizada` | não | permite propor/salvar preferências |
| `cfg_molly_modo_companhia` | não | vai ao backend; histórias e conversa longa |
| `cfg_molly_avisos_proativos` | sim | remédio atrasado (ao abrir + notificação) |
| `cfg_briefing_diario` | sim | notificação de bom dia às 8h |
| `cfg_sos_countdown_segundos` | 5 | contagem da emergência suave (sem tela) |
| `cfg_wake_word_enabled` | não | sem efeito (wake word não implementada) |

## O que ainda não existe

- Ativação por "Molly" (wake word) — só a abstração (`wake_word_service.dart`).
- Voz em tempo real / interromper a Molly falando (LiveKit, TAREFA 33).
- Segundo provedor de IA fora da Groq (TAREFA 32 — os reservas são todos Groq).
- Cache local de perfil/familiares/lembretes (TAREFA 26) e telemetria (TAREFA 27).
