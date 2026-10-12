# Testes da MOLLY

> TAREFA 34 do prompt mestre (e o que a TAREFA 28 pediu). Estado em
> 12/10/2026: **155 testes passando, 6 falhando** — as 6 falhas são de
> `reminder_service_test.dart`, pré-existentes desde abril/2026 e sem
> relação com a Molly.

## Como rodar

```powershell
# Dentro do OneDrive o flutter test pode falhar com
# "Flutter failed to delete a directory at build\unit_test_assets"
# (trava do OneDrive). Rode na cópia fora dele, como o build:
robocopy "C:\Users\phpos\OneDrive\MeLembraAI" "C:\MeLembraAI" /E /XD build .dart_tool .git .gradle
Set-Location C:\MeLembraAI
flutter test                                   # tudo
flutter test test/molly_safety_service_test.dart   # um arquivo
flutter analyze lib/features/molly             # análise do módulo
```

## Por que quase tudo é "puro"

O primeiro acesso a `FirebaseAuth.instance` num processo de teste chama
platform channels que **não têm mock** neste projeto, e a falha assíncrona
vaza para outros testes (achado da TAREFA 10). Por isso a regra é:
**separar a decisão (pura) da execução (Firebase)** e testar a decisão.

Exemplos: `OfflineIntentService.classificar` (puro) × `tentar` (executa);
`MollyProactiveService.gerarAviso` × `verificarRemedioAtrasado`;
`ProfileTool.falaContatosEmergencia` × `getEmergencyContacts`;
`FamilyTool.resolverFamiliar` × `resolver`.

SharedPreferences tem mock (`SharedPreferences.setMockInitialValues`) e
Firebase Core também (`test/support/firebase_core_mocks.dart`). STT/TTS e
notificações **não** têm — testes de tela evitam tocar nesses botões.

## Arquivos de teste da Molly

| Arquivo | Testes | Cobre |
|---|---|---|
| `offline_intent_service_test.dart` | 19 | comandos locais, emergência suave e falsos positivos, contato de emergência |
| `molly_safety_service_test.dart` | 17 | cenários da TAREFA 29, conselho médico, remédio a mais, filtro de saída, excluir por voz, alvo vago, "já tomei meu remédio" |
| `molly_family_test.dart` | 16 | frases de família, prioridades, resolver familiar, quem acompanha |
| `molly_proactive_service_test.dart` | 13 | remédio atrasado (15 min), sim/não/outra, ids de notificação, remédio × água |
| `molly_reminder_parser_test.dart` | 13 | dia/hora/título/tipo/recorrência locais |
| `profile_tool_test.dart` | 9 | contatos de emergência falados |
| `molly_prompt_service_test.dart` | 8 | personalidade, respostas curtas |
| `molly_intent_test.dart` | 6 | sinais de "criar lembrete" e "companhia" |
| `molly_memory_gatilho_test.dart` | 6 | proposta de memória vinda da IA |
| `short_term_memory_test.dart` | 6 | histórico, turnos, slots |
| `molly_briefing_service_test.dart` | 5 | bom dia às 8h |
| `molly_risk_policy_test.dart` | 4 | LOW/MEDIUM/CRITICAL |
| `molly_screen_test.dart` | 4 | estrutura da tela cheia |
| `molly_memory_screen_test.dart` | 4 | "O que a Molly lembra" |
| `wake_word_service_test.dart` | 4 | stub indisponível |
| `molly_settings_screen_test.dart` | 3 | Configurações da Molly |
| `ai_command_service_test.dart` | 2 | quando a localização vai junto |

## Testes do backend (VPS)

O backend Python não tem suíte automatizada. O procedimento usado na sessão
25, que pegou problemas reais (nome inventado, resposta sem `acao`, Modo
Companhia ignorado, limite de saída do qwen):

1. Copiar `app.py` e `internet.py` para uma **pasta temporária** na VPS
   (`/tmp/mollytest`, junto com `serviceAccountKey.json`) — nada em produção.
2. Script Python com `app.app.test_client()` e `verificar_token`
   substituído por uma função que devolve um UID de teste — exercita a
   **rota real** (`/interpretar-comando`), com Groq e internet de verdade.
3. Rodar com o venv e o `.env` de produção:
   `set -a && . /root/ai_command_server/.env && set +a && /root/ai_command_server/venv/bin/python t.py`
4. Esperar ~9 s entre chamadas (limite de 8.000 tokens/min por modelo).
5. Forçar cada modelo reserva (`A.GROQ_MODELOS = ["qwen/..."]`) nas frases
   críticas.
6. Apagar a pasta temporária.

Bateria mínima sugerida (12 frases): lembrete com hora · lembrete sem hora
(→ perguntar) · "o que eu tenho hoje" · lista de compras · "meus alertas" ·
pergunta de saúde · "exclua todos os meus lembretes" · curiosidade ·
"vai chover hoje" sem localização (→ "De qual cidade...") · "me conta uma
história" com companhia desligada e ligada · "pode me chamar de ..." (→
memoria) · "estou me sentindo sozinho".

## Testes manuais no aparelho (sem automação possível hoje)

- Voz de ponta a ponta (STT/TTS): falar com a Molly no Galaxy A07
  (`R9QL200MJ0N`).
- Notificação "Você conseguiu tomar seu remédio?": criar lembrete de
  remédio para daqui a 2 min, não confirmar, esperar ~17 min.
- Modo Proteção: `adb shell dumpsys activity services com.melembra.ai` →
  `types=0x00000100`; app fechado > 6 h sem ser encerrado (ainda não feito).
- Detector de queda: o aparelho de referência não tem acelerômetro — não
  testável nele.
- Acessibilidade com idosos: roteiro em
  [MOLLY_ACCESSIBILITY_CHECKLIST.md](MOLLY_ACCESSIBILITY_CHECKLIST.md),
  seção 9 (ainda não feito).

## Lacunas (TAREFA 28)

- Sem mock de `firebase_auth`/`cloud_firestore`: `MollyContextService`,
  execução das ferramentas e `MollyAgentService.processar` de ponta a
  ponta não têm teste automatizado.
- Sem mock de `speech_to_text`/`flutter_tts`: `MollyVoiceService` e os
  fluxos falados do painel só são testados no aparelho.
- Backend sem testes automatizados (só o procedimento acima).
