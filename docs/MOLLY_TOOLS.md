# Ferramentas da MOLLY

> TAREFA 34 do prompt mestre. Estado em 12/10/2026. Ver também
> [MOLLY_ARCHITECTURE.md](MOLLY_ARCHITECTURE.md) e [MOLLY_SAFETY.md](MOLLY_SAFETY.md).

Uma ferramenta é uma `MollyToolDefinition` (`models/molly_tool_definition.dart`):
nome, descrição, parâmetros (validados), **nível de risco** e a função que
executa. Todas são wrappers finos sobre serviços que já existiam no app
(`ReminderService`, `FamilyService`, `ChatService`, ...) — nenhuma acessa
o Firestore direto. O catálogo é `services/molly_tool_registry.dart`.

## Como uma ferramenta é executada

```
MollyRiskPolicy.executar(nome, parametros, ambiguo: false, emergenciaAutorizada: false)
  ├─ LOW       → executa
  ├─ MEDIUM    → executa; se ambiguo: true, pede confirmação antes
  └─ CRITICAL  → sempre pede confirmação (sim/não falado), exceto
                 emergenciaAutorizada: true (reservado, hoje sem uso)
```

A confirmação devolve `MollyToolResult.precisaConfirmacao`; o painel ouve
"sim" e chama `MollyRiskPolicy.confirmarEExecutar` com os mesmos parâmetros
(sem voltar à IA). O **disparo de SOS não é ferramenta** — é sempre detecção
local (`SosService.trigger`), nunca uma decisão da IA.

## Catálogo

| Ferramenta | Arquivo | Risco | O que faz | Como é alcançada hoje |
|---|---|---|---|---|
| `createReminder` | reminder_tool | MEDIUM | cria lembrete + agenda notificação | IA `criar_lembrete`; coleta local de dia/hora |
| `getTodayReminders` | reminder_tool | LOW | resumo curto dos lembretes de hoje | IA `ouvir_lembretes`; offline "meus lembretes" |
| `getTomorrowReminders` | reminder_tool | LOW | idem, amanhã | — (registrada, sem caminho de voz) |
| `updateReminder` | reminder_tool | MEDIUM | edita lembrete | — (sem caminho de voz) |
| `deleteReminder` | reminder_tool | CRITICAL | exclui lembrete | — **de propósito**: excluir por voz é bloqueado (ver MOLLY_SAFETY.md) |
| `confirmReminder` | reminder_tool | MEDIUM | marca como feito e avisa a família | offline "confirmar remédio"; "sim" a "conseguiu tomar?" |
| `getReminderHistory` | reminder_tool | LOW | quantos confirmados nos últimos dias | — (sem caminho de voz) |
| `getFamilyMembers` | family_tool | LOW | lista familiares vinculados | "quem é minha família?" |
| `getCaregivers` | family_tool | LOW | quem acompanha os lembretes (papel cuidador) | "quem está acompanhando meus lembretes?" |
| `sendFamilyMessage` | family_tool | MEDIUM | manda texto no chat familiar e repete o que mandou | "avisa a Ana que…", "manda mensagem pro…" |
| `callFamilyMember` | family_tool | CRITICAL | **não disca**: pede pelo chat que o familiar ligue | "ligar para (nome)" |
| `getCurrentLocation` | location_tool | MEDIUM | posição atual | — (sem caminho de voz) |
| `getUserProfile` | profile_tool | LOW | nome e perfil | — (sem caminho de voz) |
| `getEmergencyContacts` | profile_tool | LOW | números de SOS (falados em grupos de dígitos) | "quem é meu contato de emergência?" |

Ações resolvidas dentro do `MollyAgentService` (sem ferramenta formal):
`adicionar_item_lista` (lista de compras) e `consultar_alertas` (alertas SOS).

## Familiares pelo nome

`FamilyTool.resolverFamiliar` (puro, testado): os familiares só têm **nome**
(o app não guarda parentesco).

- Nome exato, ou parcial por palavra ("Ana" → "Ana Paula").
- "minha filha", "meu filho"… só resolve sozinho com **um** familiar
  vinculado; com vários, pede o nome. "minha filha Ana" usa o nome.
- Alvo vago ("qualquer pessoa", "alguém", "todo mundo") nunca vira um
  familiar: pergunta "Para quem?" e lembra do "socorro".
- `ligarPara` e mensagens sem conteúdo resolvem o familiar **antes** de
  confirmar/perguntar, para a pergunta sair com o nome real.

## Comandos locais (OfflineIntentService)

Funcionam sem IA e sem internet (exceto os que leem o Firestore, que usa o
cache offline do próprio Firebase). Ordem de prioridade:

1. `socorro` — dispara o SOS
2. `possivelEmergencia` — "me ajuda", "estou passando mal"… → contagem com Cancelar
3. `excluirLembretes` — resposta fixa, nunca exclui
4. `familia` — avisar / mensagem / quem acompanha / quem é minha família
5. `queHoras`
6. `meusLembretes` → `getTodayReminders`
7. `ligarPara` → `callFamilyMember`
8. `confirmarRemedio` → `confirmReminder` (ambíguo se houver mais de um)
9. `contatoEmergencia` → `getEmergencyContacts`

Depois deles, ainda antes da IA: `MollySafetyService` (saúde) e
`MollyMedicationService` ("já tomei meu remédio hoje?").

## Como adicionar uma ferramenta nova

1. Criar a `MollyToolDefinition` no arquivo de `tools/` do domínio, com
   risco honesto (pense: "o que acontece se a IA entender errado?").
2. Registrar em `MollyToolRegistry._ferramentas`.
3. Se pode pedir confirmação, uma pergunta específica em
   `MollyRiskPolicy._perguntaDeConfirmacao`.
4. Dar um caminho: regra local em `OfflineIntentService` (preferível para
   coisas críticas) ou nova `acao` no backend (`ACOES_VALIDAS` +
   `SYSTEM_PROMPT` em `app.py` + `_executar` em `molly_agent_service.dart`).
5. Testes puros da parte de decisão (ver MOLLY_TESTING.md).
