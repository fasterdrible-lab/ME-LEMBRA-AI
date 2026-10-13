# Segurança da MOLLY

> TAREFA 34 do prompt mestre (inclui o que as TAREFAs 4, 17–19, 21, 22 e 29
> pediram). Estado em 12/10/2026. Ver também [MOLLY_TOOLS.md](MOLLY_TOOLS.md)
> e [MOLLY_TESTING.md](MOLLY_TESTING.md).

Público: pessoas 60+, falando de remédios, saúde e família. A regra de
projeto é **defesa em camadas, com o crítico sempre local**: nenhuma
garantia de segurança depende de a IA obedecer ao prompt.

## 1. SOS e emergência

| Gatilho | Onde é detectado | O que acontece |
|---|---|---|
| "SOCORRO" em qualquer momento da escuta | `MollyAssistantPanel._checarSocorro` (texto **parcial**, antes do fim da fala) | `SosService.trigger(motivo: 'voz')` na hora |
| "SOCORRO" no texto final | `OfflineIntentService` (2ª camada) | idem |
| "me ajuda", "estou passando mal", "preciso de ajuda", "chama alguém", "chama minha filha" | `OfflineIntentService._pareceEmergenciaSuave` | **contagem regressiva com Cancelar** (`cfg_sos_countdown_segundos`, padrão 5 s) e só então o SOS |
| Emergência suave como resposta a "o que você quer dizer para…?" | `MollyAssistantPanel._coletarMensagem` | vai para a contagem, não vira só um texto no chat |

- A IA **nunca** decide disparar o SOS — não existe ferramenta de SOS.
- Falsos positivos evitados (TAREFA 19): palavra inteira ("me ajudaram"
  não conta), negação logo antes ("não preciso de ajuda") e relato do
  passado ("ontem eu precisei de ajuda").
- SOCORRO tem prioridade sobre tudo: "avisa a Ana que socorro" é SOS.

## 1b. Crise e desabafo (sessão 26)

A Molly acolhe desabafos (solidão, luto, preocupações) **sempre**, com ou
sem Modo Companhia — regra "CONVERSA E DESABAFO" do `SYSTEM_PROMPT`:
acolher e nomear o sentimento, uma pergunta gentil, lembrar o que foi dito,
não minimizar nem dar sermão; ela não é psicóloga — sugere pessoa de
confiança ou profissional sem insistir a cada fala.

**Crise** (falar em morrer, tirar a própria vida, não querer mais viver):
- Detecção **local** (`MollySafetyService` → `MollySafetyIntent.crise`),
  antes de qualquer outra regra de segurança e nunca pela IA. Passado
  também conta ("ontem pensei em me matar"); "não quero morrer", "morrer
  de rir" e "esse calor vai me matar" não.
- Resposta fixa (`falaCrise`): acolhe, "eu estou aqui com você", **CVV
  188** (gratuito, 24 h), "socorro" se houver perigo agora.
- Com familiar vinculado: "Quer que eu avise sua família?" — **só avisa
  com um sim** (escolha do usuário). A mensagem à família é fixa ("está
  passando por um momento difícil… se puder, ligue agora") e **nunca
  repete o desabafo**. "Não" também acolhe e a conversa continua.
- O prompt do backend repete a regra (terceira camada).
- Sim/não por palavra inteira (`MollyRespostas`): "não, pode deixar" é
  não — antes era lido como sim.
- Telemetria: só `molly_safety_block` com `tipo=crise`, nunca o texto.

Saída da IA: "você vai ficar bem"/"está segura" continuam proibidos, mas a
troca agora é acolhedora ("Eu estou aqui com você. Se não estiver se
sentindo bem, diga socorro ou ligue 192.") em vez de mandar procurar o
médico no meio de um desabafo.

## 2. Saúde e remédios (TAREFAs 21 e 22)

A Molly **nunca**: diagnostica, indica remédio, dose ou quantidade, manda
trocar/parar/misturar, substitui o médico, diz que a pessoa está segura,
que "não é nada grave" ou que uma emergência foi resolvida.

Três camadas:

1. **Entrada, local** — `MollySafetyService.classificar` antes da IA:
   - `conselhoMedico` ("quantos comprimidos eu tomo", "que remédio é bom pra
     dor", "posso parar de tomar", "será que estou com dengue", "é grave?")
     → "Sobre remédio, dose ou o que pode ser, quem orienta é o seu médico
     ou o farmacêutico. Eu posso te lembrar dos horários..."
   - `possivelExcessoDeRemedio` ("tomei dois comprimidos", "tomei o
     remédio errado", "tomei o do meu marido") → "Eu não sei dizer se isso
     faz mal. Ligue agora para o seu médico ou avise sua família. Se não
     estiver se sentindo bem, diga socorro ou ligue 192."
   - Cuidado com falsos positivos, todos com teste: "qual remédio eu devo
     tomar **agora**" é pergunta de horário (só vira conselho com sintoma);
     "posso trocar o horário do lembrete"; "acho que estou com fome".
2. **Saída, local** — `MollySafetyService.filtrarFalaDaIA` em toda fala
   livre da IA (`responder`/`perguntar`): troca frases que tranquilizam,
   dispensam médico, mandam mudar dose ou diagnosticam.
3. **Backend** — seção "SEGURANÇA (acima de tudo)" do `SYSTEM_PROMPT`.

O que a Molly **pode** fazer com remédio: lembrar horários, confirmar que
foi tomado, dizer o que foi marcado hoje ("já tomei meu remédio hoje?" —
fala do que foi **marcado** no app, nunca afirma que a pessoa tomou) e
perguntar 15 min depois do horário (ver MOLLY_ARCHITECTURE.md).

## 3. Ações que mudam dados ou falam com pessoas

| Ação | Proteção |
|---|---|
| Excluir lembrete | **Nunca por voz.** `OfflineIntent.excluirLembretes` responde que é na tela Meus Lembretes. `deleteReminder` existe (CRITICAL) mas não tem caminho de voz. |
| "Ligar para" familiar | CRITICAL: sempre confirma, com o nome já resolvido. Não disca — avisa pelo chat. |
| Alvo vago ("qualquer pessoa", "alguém") | Nunca escolhe ao acaso: "Para quem? … Se precisar de ajuda agora, diga socorro." |
| "Minha filha" com vários familiares | Pede o nome; nunca adivinha. |
| Mandar mensagem | Repete o texto enviado ("Mandei para Ana: Estou bem.") — veio do reconhecimento de voz e pode ter saído errado. "cancela/deixa pra lá" desiste. |
| IA dizendo que fez algo | `filtrarFalaDaIA` troca "excluí/liguei/mandei/avisei/acionei/cancelei…" por "Isso eu não consigo fazer por aqui…". |
| Confirmar remédio com mais de um pendente | MEDIUM + `ambiguo: true` → pede confirmação. |

Níveis de risco e quando confirmam: ver MOLLY_TOOLS.md.

## 4. Invenção de dados ("alucinação")

- Dados do usuário (lembretes, alertas, familiares): a IA só pode usar o
  que vem no contexto; o app manda um **resumo** dos lembretes, nunca o
  documento do Firestore.
- Fatos do momento (tempo, notícias, jogos, preços): só do bloco
  "Informações da internet" que o backend busca; sem ele, "não consegui ver
  agora".
- Conhecimento geral: permitido em 1–3 frases, com "não tenho certeza"
  quando for o caso. Pode simplificar (ex.: "primeiro avião" de Santos
  Dumont, que é disputado).
- Nome da pessoa: "nunca chame a pessoa por um nome que ela não disse" —
  regra criada depois de o modelo copiar o exemplo "Seu Antônio" do prompt.
- Coleta de dia/hora de lembrete é local e determinística, não da IA.

## 5. Notícias

Fonte única e pública (Agência Brasil). Sessão 26: a escolha saiu do
prompt (o modelo lia 6 manchetes em lista, com política e polícia) para o
servidor — `internet.escolher_manchetes`: no máximo 3, leves primeiro;
crime, tragédia e disputa política só entram se faltar manchete leve. O
prompt pede começar com "Segundo a Agência Brasil," e contar em frase
corrida, sem numerar, sem opinião. Testes: `test_internet.py`.

## 6. Privacidade

- Memória de longo prazo: opt-in, três travas, privada ao dono (ver
  MOLLY_MEMORY.md).
- Localização: só em perguntas de tempo, arredondada a ~1 km, nunca pede
  permissão.
- Conversas não são guardadas no app nem no backend (o log tem UID e
  erros).
- Token do Firebase em toda chamada ao backend; o backend recusa sem ele.

## 7. Quando a IA falha

A Molly diz "Estou com dificuldade para responder agora, mas seus
lembretes e o botão SOS continuam funcionando." — e é verdade: tudo das
seções 1–3 é local. Causas já vistas e onde olhar: `CURRENT_STATE.md`,
seção do backend de IA (404 modelo, 401 chave, 400 tokens, 429 limite).

## Lacunas conhecidas

- Sem segundo provedor de IA fora da Groq (os modelos reserva usam a mesma
  chave).
- A contagem da emergência suave não tem tela para mudar a duração.
- Queda detectada com o app fechado dispara o SOS sem contagem (não há
  tela no motor em segundo plano — ver `ARCHITECTURE.md`).
