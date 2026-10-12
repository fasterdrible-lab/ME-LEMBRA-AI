# Memória da MOLLY

> TAREFA 34 do prompt mestre. Estado em 12/10/2026. Ver também
> [MOLLY_ARCHITECTURE.md](MOLLY_ARCHITECTURE.md).

Duas memórias, com regras opostas: a de **curto prazo** é automática e
some ao fim da conversa; a de **longo prazo** nunca grava nada sem um
"sim" explícito.

## Curto prazo — a conversa atual

`lib/features/molly/memory/short_term_memory.dart` (`ShortTermMemory`),
uma instância por painel aberto.

| Guarda | Para quê | Limite |
|---|---|---|
| Histórico de trocas (usuário → Molly) | mandado à IA (`historicoParaIA`) para continuidade ("quando é minha consulta?" → "me lembra duas horas antes") | últimas **3** trocas (o backend também corta em 3) |
| Contagem de turnos | encerrar conversas longas: "Vamos continuar depois..." | **6** turnos |
| Primeira fala | título/tipo/recorrência do lembrete em coleta | — |
| Slots de dia/hora (`slotDia`, `slotHora`...) | coleta de lembrete **local**, fora do histórico da IA | — |

Por que os slots não vão para a IA: em testes (sessão 22) o modelo
"esquecia" dado já informado entre turnos. A partir do primeiro `perguntar`
da IA, a coleta de dia/hora é 100% local (`MollyReminderParser`).

`encerrar()` limpa tudo — chamado ao criar o lembrete, no limite de turnos
e em "obrigado"/"pode parar".

## Longo prazo — preferências

`lib/features/molly/memory/long_term_memory.dart` (`LongTermMemoryService`).

**Onde:** Firestore `users/{uid}/molly_memory/{id}`

```json
{"type": "nome_preferido | horario_rotina | preferencia | ...",
 "value": "Seu Antônio",
 "source": "conversa",
 "confidence": 0.9,
 "userApproved": true,
 "createdAt": "timestamp", "updatedAt": "timestamp"}
```

**Privada ao dono:** `firestore.rules` não dá leitura à família (diferente
de `reminders`). Preferências pessoais não são automaticamente da família.

### Como uma memória nasce (três travas)

```
Pessoa: "pode me chamar de Seu Antônio"
  └─ IA (backend) devolve, junto da resposta, memoria: {tipo, valor, confianca}
       └─ trava 1: MollyAgentService só repassa se
          SettingsService.getMollyMemoriaAutorizada() == true
          (senão descarta em silêncio — nem pergunta)
            └─ trava 2: o painel pergunta em voz alta
               "Posso lembrar disso: Seu Antônio?" e só segue com "sim"
                 └─ trava 3: LongTermMemoryService.salvar() recusa se
                    userApproved != true OU o interruptor estiver desligado
```

O interruptor geral é **Configurações da Molly → Memória** (padrão:
desligado). Desligar impede memórias novas; as já guardadas continuam até
serem apagadas.

### O que o usuário controla

Tela **"O que a Molly lembra"** (`/molly-memory`, aberta por
Configurações da Molly → "Ver o que a Molly lembra"):

- ver tudo, com tipo, valor, data e origem;
- editar o valor (edição não passa pela trava de autorização — editar o
  que já foi aprovado é diferente de criar);
- excluir uma por uma, ou apagar tudo (com confirmação);
- memórias com confiança < 0,7 aparecem destacadas ("confira se está certo").

### Onde a memória é usada

`MollyContextService` inclui as preferências no retrato do usuário **só**
se o interruptor estiver ligado. Hoje o backend de IA recebe apenas os
lembretes (`lembretesParaIA`); passar preferências à IA é uma evolução
pendente.

## Outros dados guardados

| Dado | Onde | Observação |
|---|---|---|
| Contagem de "lembra de novo" do remédio | SharedPreferences `molly_relembrar_<id>_<data>` | máx. 2 por remédio por dia |
| Configurações da Molly | SharedPreferences `cfg_*` | ver MOLLY_ARCHITECTURE.md |
| Conversas | **não são guardadas** | só o histórico de 3 trocas, em memória, enquanto o painel está aberto |

No backend, o `journalctl` registra o UID, o modelo usado e erros —
**não** o texto das conversas. Ressalvas: a mensagem de erro da Groq vai
para o log como veio (em teoria pode citar trecho gerado), e falhas na
busca do tempo registram a URL consultada (cidade ou coordenadas
arredondadas a ~1 km).
