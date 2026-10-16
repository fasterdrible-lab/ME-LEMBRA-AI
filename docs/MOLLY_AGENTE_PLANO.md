# Plano — Molly como agente inteligente (sessão 27)

> 2026-10-16. Pedido do usuário depois dos testes da 1.7.1: "quando ela não
> entende, ela fica repetindo mensagens […] precisa estruturar realmente
> para ser um agente inteligente, que você converse com ela, que ela
> responda, que ela busque informação […] mandar mensagem, fazer ligação,
> coisas automáticas, que tirar da responsabilidade do usuário ter que
> digitar, ter que ir lá buscar o aplicativo."
>
> Sem código ainda. Base para as pendências MOLLY-45 a MOLLY-48 em
> `docs/TASKS.md`.

## 1. Diagnóstico — por que ela repete e "não entende"

### 1.1 A IA é um classificador de 6 ações, não um agente

O backend (`server/ai_command_server/app.py`, `ACOES_VALIDAS` e
`SYSTEM_PROMPT`) pede à IA, para cada fala, **um** JSON com uma de seis
ações: `criar_lembrete`, `ouvir_lembretes`, `adicionar_item_lista`,
`consultar_alertas`, `perguntar`, `responder`. Consequências:

- Ela não consegue **fazer** nada fora dessas seis — nem as ferramentas que
  já existem no catálogo (`MollyToolRegistry`): `updateReminder`,
  `deleteReminder`, `getTomorrowReminders`, `getReminderHistory`,
  `sendFamilyMessage`, `callFamilyMember`, `getEmergencyContacts`,
  `getCurrentLocation`…
- Não encadeia passos ("vê o tempo e manda pra minha filha").
- Tudo que não é uma das cinco primeiras vira `responder` (texto livre) —
  ela "conversa", mas não age.

### 1.2 Toda pergunta da IA vira coleta de lembrete

`MollyAgentService._executar`, caso `perguntar`
(`lib/features/molly/services/molly_agent_service.dart`), chama
`memoria.iniciarColetaDeLembrete` — a próxima fala é lida como dia/hora de
lembrete. Só a pergunta de tempo ("de qual cidade?") é desviada
(`AiCommandService.pareceTempo`). Qualquer outra pergunta de
esclarecimento ("sobre qual assunto?", "para quem?") cai no "Para qual
dia?". A 1.7.1 limitou o estrago (desiste na 2ª resposta sem o dado), mas a
causa continua: **é a origem estrutural das repetições**.

### 1.3 Ligar e mandar mensagem só funcionam por frase fixa

`sendFamilyMessage` e `callFamilyMember` existem, mas só são alcançados
pelos padrões locais (`MollyFamilyIntent`, `OfflineIntentService` —
"liga para a Ana", "manda mensagem pro meu filho"). Dito de outro jeito
("avisa a Ana que eu cheguei"), a IA não tem como chamá-los.

### 1.4 O que já está bom e deve ficar

- SOCORRO, crise (CVV 188), dose/diagnóstico: locais, **nunca** passam pela
  IA (TAREFAs 17/18/21/22).
- `MollyRiskPolicy`: confirmação antes de ação MEDIUM/CRITICAL.
- Lembrete sem IA (`MollyReminderParser`), cache offline, telemetria sem
  conteúdo, conversa contínua, interromper por toque e por voz.

## 2. Plano em etapas

### Etapa 1 — o "cérebro": chamada de ferramentas (MOLLY-45) — **primeira**

Trocar o classificador de 6 ações por **tool calling** (formato OpenAI
`tools`/`tool_calls`, suportado pela Groq `openai/gpt-oss-20b`/`120b` e pela
DeepSeek de reserva — sem custo novo):

- O backend recebe o catálogo de ferramentas do app (gerado a partir de
  `MollyToolRegistry` — nome, descrição, parâmetros, nível de risco) e
  devolve à IA os resultados, num laço curto (no máx. 3 passos por fala).
- Execução **continua no app**: o servidor devolve "chame X com Y"; o app
  passa por `MollyRiskPolicy` (confirma antes de ligar/mandar/apagar),
  executa, e manda o resultado de volta para a IA formular a fala.
- Ferramentas novas no catálogo: `addShoppingItem`, `getAlerts`,
  `getWeather`, `getNews`, `searchWeb` (etapa 3) — as que hoje são casos
  especiais dentro do agente.
- **Pergunta de esclarecimento genérica**: a IA pergunta o que falta *da
  ferramenta que escolheu*; a coleta local de dia/hora só entra quando a
  ferramenta for `createReminder`. Some o "Para qual dia?" fora de hora.
- **Anti-repetição** no painel: nunca a mesma fala duas vezes seguidas; na
  2ª vez sem entender, para e diz o que dá para pedir ("Você pode me pedir
  lembretes, ligar ou mandar mensagem para a família, o tempo…").
- Mantém: locais primeiro (SOCORRO, crise, offline, lembrete simples sem
  IA); filtro de saída `MollySafetyService.filtrarFalaDaIA`; histórico de 8
  trocas.
- Compatibilidade: app antigo continua falando com o formato de 6 ações
  (rota nova no servidor, ex. `/v2/agente`), até todos atualizarem.

**Aceite:** no A07, frases variadas para a mesma ação funcionam ("avisa a
Ana que cheguei", "fala pra minha filha que estou bem", "muda o remédio das
8 para as 9", "apaga o lembrete do dentista"); perguntar notícias/tempo não
cai em "Para qual dia?"; sem fala repetida em sequência; SOCORRO intacto.

### Etapa 2 — ações no celular (MOLLY-46)

| Ação | Como | Limite |
|---|---|---|
| Ligar para **qualquer contato** da agenda | permissão `READ_CONTACTS` + `CALL_PHONE` (já usada no SOS) | confirma antes; contato com nome parecido → pergunta qual |
| **WhatsApp** | abre a conversa com o texto pronto (`wa.me`/intent) | o Android **não deixa** enviar sozinho — a pessoa toca em enviar. Envio 100% automático só por Serviço de Acessibilidade, que a Play Store costuma recusar |
| **Chat familiar** do app | já existe (`sendFamilyMessage`) | 100% automático |
| SMS | `SEND_SMS` | permissão restrita na Play Store (exige ser app padrão de SMS ou exceção) — avaliar |
| Abrir apps ("abre o YouTube") | intent por nome de pacote | só apps instalados |
| Alarme / cronômetro | `AlarmClock.ACTION_SET_ALARM`/`ACTION_SET_TIMER` | abre o relógio do aparelho |

**Decisão pendente do usuário:** qual canal de mensagem importa mais
(WhatsApp, chat do app, SMS).

### Etapa 3 — buscar informação (MOLLY-47)

Ferramenta `searchWeb` no servidor (busca + resumo curto falado, com a
fonte), além de tempo/notícias/curiosidades que já existem
(`server/ai_command_server/internet.py`). Avaliar provedor de busca
grátis/barato. Filtro de saída continua valendo (nada de saúde/dose).

### Etapa 4 — iniciativa (MOLLY-48)

Rotinas ("todo dia às 9 pergunta como estou"), puxar conversa com quem
mora só, avisar a família quando algo foge do normal (sem confirmação de
remédio, sem abrir o app há dias) — sempre opt-in, como o aviso de remédio
da MOLLY-38.

## 3. Riscos e cuidados

- **Segurança acima de tudo**: ação que liga, manda ou apaga passa pela
  `MollyRiskPolicy` com confirmação falada; SOS nunca depende da IA.
- **Alucinação de ferramenta**: o app valida nome e parâmetros contra o
  catálogo antes de executar (`MollyToolRegistry` já valida).
- **Latência**: laço com 2–3 chamadas à IA pode passar de 3 s — limitar
  passos, e falar "Só um instante" quando passar de ~2 s.
- **Custo**: Groq grátis no limite atual; DeepSeek de reserva (preferência
  do usuário pelo mais barato).
- **Privacidade**: telemetria continua sem conteúdo; o servidor não guarda
  falas.
