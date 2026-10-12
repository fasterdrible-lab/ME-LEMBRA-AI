# Checklist de acessibilidade da MOLLY

> TAREFA 30 do prompt mestre. Criado na sessão 25 (12/10/2026) a partir de
> uma auditoria do código (`lib/features/molly/`, `lib/features/elderly/`,
> `lib/about_screen.dart`). Público do app: pessoas 60+.
>
> Legenda: ✅ atende · ⚠️ atende parcialmente / atenção · ❌ não atende ·
> 🧪 só dá para saber testando com pessoas

Use este checklist **antes de cada versão** (APK) que mexer em telas ou
falas da Molly, e na sessão de testes com idosos (seção 9).

---

## 1. Tamanho de fonte

Referência: mínimo de 18 px para texto de leitura; 22 px ou mais para o
que a pessoa precisa ler enquanto fala com a Molly.

| Onde | Tamanho medido | |
|---|---|---|
| Mensagem principal da Molly (`molly_assistant_panel.dart`) | 24 px | ✅ |
| Indicador de estado ("Estou ouvindo...") | 22 px, peso 600 | ✅ |
| Título "Hoje" / título da confirmação de emergência | 22 px negrito | ✅ |
| Contagem regressiva de emergência | 64 px negrito | ✅ |
| Botões da confirmação (Sim/Não, Cancelar) | 20 px negrito | ✅ |
| Lista de lembretes "Hoje" (tela cheia) | 18–20 px | ✅ |
| Botões da tela Melhor Idade | 24–32 px | ✅ |
| Dica abaixo do botão "Assistente Molly" (`elderly_screen.dart`) | 14 px, cinza | ⚠️ pequena |
| Configurações da Molly — títulos / descrições | 18 px / 15 px | ⚠️ descrições pequenas |
| Manual em "Sobre o App" — itens / rótulo de seção | 14 px / 12 px | ❌ pequeno para 60+ |

**Pendências:** subir a dica da tela Melhor Idade e as descrições das
Configurações da Molly para 16–17 px; subir o manual de "Sobre o App" para
16–18 px (é texto longo, o mais importante de ler bem).

## 2. Contraste

Referência WCAG 2.1: 4,5 : 1 para texto normal, 3 : 1 para texto grande
(≥ 24 px, ou ≥ 18,7 px em negrito). Medido sobre fundo branco.

| Elemento | Cor | Contraste | |
|---|---|---|---|
| "Toque no microfone para falar" | roxo `#7B5EA7` | 5,3 : 1 | ✅ |
| "Estou ouvindo..." | azul `#4A90D9` | 3,3 : 1 | ⚠️ no limite (só vale por ser texto grande) |
| "Pensando..." | laranja — era `#FF8C00` (2,3 : 1), **corrigido** para `#B35C00` | 4,7 : 1 | ✅ |
| "Falando..." | verde — era `#50C878` (2,1 : 1), **corrigido** para `#2E7D32` | 5,1 : 1 | ✅ |
| "Não consegui ouvir" | vermelho `#E53935` | 4,2 : 1 | ✅ (texto grande) |
| Texto branco no botão SOS | branco sobre `#E53935` | 4,2 : 1 | ✅ (26 px negrito) |
| Dica cinza (`Colors.black54`) | cinza ~`#757575` | 4,6 : 1 | ✅ |

- ✅ O estado da Molly **nunca depende só de cor**: sempre tem o texto
  ("Estou ouvindo...", "Pensando..."), e a bolinha colorida é só reforço.
- ⚠️ **Modo escuro não foi auditado** — as cores acima foram medidas só
  sobre fundo claro.

**Pendências:** escurecer o azul de "Estou ouvindo..." (ex.: `#1F6FB5`,
~5 : 1); auditar o modo escuro.

## 3. Tamanho dos botões (alvo de toque)

Referência: mínimo de 48 × 48 dp (Material); para 60+, quanto maior melhor.

| Botão | Tamanho | |
|---|---|---|
| Microfone da Molly | 120 × 120 dp, ícone 56 | ✅ |
| SOS no painel da Molly | largura total × 72 dp | ✅ |
| Botões da tela Melhor Idade | largura total × 70–90 dp | ✅ |
| Cancelar da contagem de emergência | largura total × 56 dp | ✅ |
| Interruptores das Configurações da Molly | linha inteira tocável (`SwitchListTile`) | ✅ |
| Velocidade da voz (Lenta / Normal) | 52 dp de altura | ✅ |

- ✅ O botão SOS fica **fora da área rolável** na tela cheia da Molly —
  nunca some, mesmo com muitos lembretes.

## 4. Velocidade da voz

- ✅ Duas velocidades em Configurações da Molly: **Normal** (taxa 0,48) e
  **Lenta** (0,36), com exemplo falado na hora ao trocar.
- ✅ Vale para todas as falas do app (`VoiceService`), não só a Molly.
- ✅ Respostas curtas por regra (1 a 3 frases; listas são resumidas, nunca
  lidas item por item — `MollyPromptService.resumoCurto`, `SYSTEM_PROMPT`).
- 🧪 Se 0,36 está lento o bastante (ou lento demais) só se sabe testando.

## 5. Número de passos

| Tarefa | Passos | |
|---|---|---|
| Falar com a Molly | 1 toque ("Assistente Molly" já começa a ouvir) | ✅ |
| Criar lembrete por voz | 1 frase; se faltar dia/hora, no máximo 2 perguntas curtas | ✅ |
| Ouvir os lembretes de hoje | 1 toque + 1 frase | ✅ |
| Acionar SOS | 1 toque (ou dizer "socorro") + contagem de 5 s para cancelar | ✅ |
| Responder "conseguiu tomar seu remédio?" | 1 toque na notificação + "sim"/"não" | ✅ |
| Mudar uma configuração da Molly | Configurações → Configurações da Molly → interruptor (3 toques) | ✅ |
| Encerrar a conversa | dizer "obrigado" / "pode parar", ou fechar o painel | ✅ |

## 6. Clareza da linguagem

- ✅ Personalidade definida (`molly_prompt_service.dart`, `SYSTEM_PROMPT`):
  frases curtas, sem termos técnicos, sem infantilizar.
- ✅ Checagem de jargão nas falas fixas (`MollyPromptService.contemLinguagemTecnica`).
- ✅ Mensagem de falha da IA é humana: "Estou com dificuldade para
  responder agora, mas seus lembretes e o botão SOS continuam funcionando."
- ✅ Números de telefone falados em grupos de dígitos ("1 1, 9 8 7 6 5, …").
- ⚠️ Respostas livres da IA podem variar — revisar periodicamente amostras
  reais (ver `MOLLY_TESTING.md`, bateria de regressão do backend).

## 7. Feedback visual

- ✅ Estado sempre escrito: "Toque no microfone", "Estou ouvindo...",
  "Pensando...", "Falando...", "Não consegui ouvir".
- ✅ O que a pessoa disse aparece na tela antes da resposta.
- ✅ A resposta da Molly fica escrita na tela (útil com "Resposta por voz"
  desligada ou para quem ouve mal).
- ✅ Emergência: contagem regressiva enorme (64 px) + botão Cancelar.
- ⚠️ Sem indicação visual de volume da voz captada (a pessoa não vê se
  está falando baixo demais).

## 8. Feedback sonoro

- ✅ Toda resposta é falada (pode ser desligado em Configurações da Molly).
- ✅ Lembretes falados em voz alta no horário no perfil Melhor Idade —
  mas só com o app aberto ou usado há pouco (timer dentro do app).
- ✅ Canal de notificação reforçado do idoso (`me_lembra_ai_idoso`):
  prioridade máxima, vibração longa (3 × 0,8 s), categoria "lembrete",
  visível na tela bloqueada. Existia sem uso até a sessão 25; agora todo
  lembrete (e o "conseguiu tomar seu remédio?") do perfil Melhor Idade sai
  nele. Lembretes agendados antes continuam no canal comum até serem
  recriados/editados.
- ⚠️ "Tela cheia" (acender a tela e abrir por cima de tudo) não funciona:
  exige a permissão `USE_FULL_SCREEN_INTENT`, não declarada — a Play Store
  só a libera para apps de alarme/chamada.
- ✅ Início da escuta tem o bipe do próprio reconhecimento de voz do Android.
- ⚠️ Sem som próprio de "não entendi" / "terminei de ouvir" — só a fala.
- ⚠️ Sem vibração ao começar a ouvir (ajudaria quem ouve mal).

---

## 9. Roteiro de teste com idosos (🧪)

Nada disso substitui ver uma pessoa 60+ usando. Sugestão de sessão
(15–20 min, com o celular dela ou o de referência, sem ajudar a não ser
que ela peça):

1. "Pergunte para a Molly o que você tem hoje." — conseguiu achar o botão?
   esperou o "Estou ouvindo"?
2. "Peça para ela te lembrar de tomar água às quatro." — entendeu as
   perguntas de dia/hora, se vieram?
3. "Pergunte se vai chover hoje."
4. "Mande uma mensagem para (familiar) dizendo que está tudo bem."
5. "Mude a velocidade da voz para lenta." — achou o caminho sozinha?
6. Pedir para ler em voz alta a resposta que está na tela — leu sem
   esforço? aproximou o celular do rosto?
7. Simular o SOS e **cancelar** dentro dos 5 s. — o botão Cancelar foi
   encontrado a tempo?

Anotar para cada item: conseguiu sozinha? quanto tempo? hesitou onde?
o que disse ("não entendi", "muito rápido", "não enxergo")? Registrar os
achados neste arquivo, numa seção nova com a data.

---

## Histórico

| Data | O que mudou |
|---|---|
| 12/10/2026 | Checklist criado. Corrigidas as cores de "Pensando..." (2,3 → 4,7 : 1) e "Falando..." (2,1 → 5,1 : 1). Pendências: fontes de 14–15 px (dica, descrições, manual), azul no limite, modo escuro não auditado, feedback sonoro/vibração ao ouvir. Nenhum teste com idosos feito ainda. |
| 12/10/2026 | Canal reforçado do idoso passou a ser usado (prioridade máxima + vibração longa). Tela cheia segue pendente (permissão). |
