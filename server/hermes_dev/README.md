# Hermes Dev

Sistema de manutenção autônoma supervisionada para o Me Lembra Aí. Separado do
Hermes Produto (assistente de voz dentro do app, avaliado e descartado na
sessão 15 — ver `docs/CURRENT_STATE.md`; este é o agente de **desenvolvimento**,
não de produto).

## Como usar

No Claude Code, dentro deste repositório:

```
/hermes-dev corrige o crash ao excluir um lembrete quando a lista está vazia
```

O orquestrador (`.claude/skills/hermes-dev/SKILL.md`) conduz o fluxo completo:
investigação → branch/worktree isolado → correção → testes → revisão
independente → quality gate → relatório → preparação de PR. Nunca faz
`git push`/`merge`/deploy sozinho.

## Arquitetura (Fase 1)

O "orquestrador" e os "agentes" (`BugHunterAgent`, `DeveloperAgent`,
`ReviewerAgent`, `TestRunnerAgent`) **são o próprio Claude Code**, não um
serviço separado: um skill (`.claude/skills/hermes-dev/`) que atua como
`HermesDevOrchestrator`, e quatro subagentes (`.claude/agents/hermes-*.md`)
com escopo de ferramentas restrito por papel. Essa decisão foi tomada
explicitamente com o usuário em vez de construir um serviço Python
independente com sua própria chamada de LLM — evita duplicar infraestrutura
que o Claude Code já resolve (isolamento de worktree, subagentes, políticas
de permissão) e não exige hospedar/pagar por mais um serviço na VPS
compartilhada.

```
server/hermes_dev/
├── config/autonomy.json          # AUTONOMY_LEVEL (manual | assisted | autonomous*)
├── policies/
│   ├── protected_files.json      # TAREFA 12
│   ├── risk_classifier.json      # TAREFA 5 (LOW/MEDIUM/HIGH/CRITICAL)
│   ├── severity_classifier.json  # TAREFA 4 (P0-P4)
│   └── command_policy.json       # TAREFA 15 (espelhado em .claude/settings.json)
├── bugs/queue.json               # TAREFA 21 — estado de cada bug
├── reports/<bug_id>.md           # TAREFA 24 — um relatório por bug corrigido
└── logs/audit.jsonl              # TAREFA 30 — log append-only

.claude/
├── agents/hermes-bug-hunter.md   # investiga, só leitura
├── agents/hermes-developer.md    # corrige, dentro do worktree isolado
├── agents/hermes-test-runner.md  # valida (analyze/test/build), só leitura+bash
├── agents/hermes-reviewer.md     # revisão independente, só leitura
└── skills/hermes-dev/SKILL.md    # HermesDevOrchestrator
```

*`autonomous` está documentado no config mas não implementado — a spec original
pede explicitamente para não implementar autonomia total sobre produção nesta
etapa.

## O que NÃO foi implementado nesta fase (e por quê)

Adiado por exigir decisões de infraestrutura que não fazem sentido decidir
implicitamente:

- **Crash Intake HTTP** (`POST /dev/crashes`) e agrupamento por fingerprint —
  precisaria de um serviço hospedado (a VPS já é compartilhada com vários
  outros projetos e portas do usuário) e uma decisão sobre onde/como os
  crashes do app chegariam até lá.
- **Dashboard web** — precisaria de hospedagem e autenticação próprias; sem
  isso hoje, `bugs/queue.json` e `reports/*.md` já dão visibilidade do estado.
- **Firebase Emulator (Auth/Firestore/Storage)** — útil para testes de
  integração mais realistas, mas não bloqueia o núcleo do fluxo (o Test
  Runner de Fase 1 roda `flutter analyze`/`flutter test`/`flutter build`, que
  já cobre a maioria dos bugs sem tocar Firestore de verdade).
- **Regression Memory estruturada** (`hermes_memory/bugs|architecture|decisions|regressions|testing|lessons/`) —
  por ora, `reports/<bug_id>.md` cumpre esse papel de forma simples; o Bug
  Hunter é instruído a checar `reports/` antes de investigar do zero.
- **Watchdog completo** (limite de tokens/custo, tempo de build) — o limite de
  5 iterações de correção (TAREFA 9) está implementado no orquestrador; os
  demais limites (custo por bug, tempo máximo de build) ficam para quando
  houver um caso real de estouro.

Nada disso foi esquecido — cada um está listado aqui para não virar trabalho
invisível. Se algum desses virar prioridade, é um pedido separado.

## Arquivos protegidos e risco CRITICAL

Ver `policies/protected_files.json` e `policies/risk_classifier.json`. Em
resumo: tudo relacionado a SOS, detector de queda, ligação automática e
serviços de emergência exige aprovação humana **antes** de qualquer edição,
não só antes do merge.
