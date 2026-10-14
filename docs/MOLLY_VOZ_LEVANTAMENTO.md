# Levantamento — palavra "Molly" e interromper a Molly (sessão 26)

> 2026-10-12. Sem código no app. Base para decidir as TAREFAs 16 (wake
> word) e 33 (voz em tempo real) do prompt mestre.

## Resumo

| Caminho | Viável hoje? | Custo | Recomendação |
|---|---|---|---|
| Vosk para ouvir "Molly" | **Não**, com o modelo pronto: "molly" não existe no vocabulário | Grátis | Descartar |
| Picovoice Porcupine | Técnico sim; **plano grátis encerrado** (relatos, 30/06/2026) | Pago (empresarial) | Descartar por custo |
| `open_wake_word` / `wakekit` (Apache-2.0, ONNX) | Talvez — pacotes novos (0.3.0 / 0.1.4), sem teste | Grátis | Protótipo em branch, se a TAREFA 16 for prioridade |
| Interromper a Molly **por toque** | **Sim** — só falta ligar o botão | Grátis | **Fazer primeiro** |
| Interromper a Molly **pela voz** (eco cancelado) | Provável — peças existem no app (`record`) | Grátis | Protótipo em branch, medir no A07 |
| LiveKit (TAREFA 33 original) | Sim, mas com servidor e voz pagos por minuto | Pago, recorrente | Adiar |

## 1. Palavra "Molly" com Vosk — testado

Baixado o modelo oficial `vosk-model-small-pt-0.3` (32 MB zip, 52 MB
descompactado — o único em português viável no celular). A tabela de
palavras fica embutida em `Gr.fst` (~100 mil palavras; "socorro",
"lembra", "remédio" estão lá).

**"molly" não está**, nem "moly", "moli", "mollie". As mais próximas são
"mole" e "mali". O Vosk só reconhece palavras do vocabulário do modelo
(o modo "gramática", usado para ouvir uma palavra só, também). Usar
"mole" no lugar dispararia com "pão mole", "está mole". Acrescentar a
palavra exige recompilar o modelo com as ferramentas do Kaldi e os
arquivos-fonte do modelo grande — fora do alcance de um app.

Além disso: `vosk_flutter` oficial está parado (0.3.48, ~2 anos); o fork
`vosk_flutter_2` também (última atualização 2023, só Android).

**Conclusão: Vosk não serve para "Molly".** Também não vale trocar o
reconhecimento atual por ele: o modelo pequeno erra mais que o do Google
(que o app usa e que funciona sem internet em muitos aparelhos, com o
pacote de português baixado).

## 2. Outras opções para "Molly"

- **Picovoice Porcupine** (já pesquisado na TAREFA 16): segundo relatos
  na comunidade Home Assistant repassando e-mail da empresa, o plano
  grátis acabou em 30/06/2026, sem plano não comercial previsto — **não
  confirmado na página oficial**. O comentário em
  `lib/features/molly/services/wake_word_service.dart` (item 5) ainda
  fala em "tier gratuito" e está desatualizado.
- **`flutter_wake_word`** (DaVoice): exige chave de licença; termos não
  publicados.
- **`open_wake_word` 0.3.0 / `wakekit` 0.1.4**: Apache-2.0, rodam no
  aparelho (ONNX). `wakekit` diz treinar a palavra a partir de voz
  sintética (TTS) — não está claro se o treino roda no celular ou num
  computador. Pacotes muito novos: risco de manutenção.

**Restrições que valem para qualquer uma** (não dependem da biblioteca):
- Ouvir com o app fechado exige serviço em primeiro plano do tipo
  `microphone` (Android 14+), que **não pode ser iniciado com o app em
  segundo plano** — nem depois de reiniciar o celular sem a pessoa abrir
  o app. Pode dividir o serviço atual (`health|microphone`).
- Indicador de microfone **sempre aceso** na barra do Android — pode
  assustar ou confundir o idoso.
- Bateria: escuta contínua o dia inteiro. Precisa medir.
- O microfone não pode ser usado por dois ao mesmo tempo: a escuta da
  palavra precisa parar antes do reconhecimento normal começar.
- Play Store: declarar o uso contínuo do microfone e o tipo de serviço.

## 3. Interromper a Molly enquanto ela fala

Hoje, enquanto a Molly fala, ninguém está ouvindo — a pessoa precisa
esperar ela terminar. Dois níveis:

**3a. Por toque (recomendado, certo).** Tocar o microfone (ou a tela)
enquanto ela fala: para a fala na hora e começa a ouvir. A primitiva já
existe (`MollyVoiceService.interromperFala`, TAREFA 5). Trabalho pequeno,
sem risco, funciona em qualquer aparelho.

**3b. Pela voz (experimental).** Peças conferidas no código das
bibliotecas que o app já tem:
- `record` 6.2 (já no app): grava com `AudioSource.VOICE_COMMUNICATION` e
  liga o `AcousticEchoCanceler`/`NoiseSuppressor` do Android
  (`echoCancel`/`noiseSuppress`), entregando o áudio ao vivo
  (`startStream`) ou o volume (`onAmplitudeChanged`).
- Ideia: enquanto a Molly fala, medir o volume do microfone com o eco
  cancelado; voz da pessoa por ~0,3 s acima do limite → `flutter_tts.stop()`
  → para a gravação → abre o `speech_to_text` normal.

Riscos a medir no Galaxy A07:
- **O eco pode não ser cancelado.** O cancelador do Android usa como
  referência o áudio de chamada; o `flutter_tts` toca como mídia. Em
  muitos aparelhos a Molly "ouviria a si mesma" e se interromperia.
  Forçar modo de chamada (`MODE_IN_COMMUNICATION`) muda o volume e a
  saída do som — ruim para quem ouve pouco.
- **Perde o começo da frase**: entre detectar a voz e o reconhecedor
  abrir, ~0,3–0,5 s.
- **TV ou conversa no ambiente** podem interromper a Molly no meio.
- `speech_to_text` não deixa escolher a fonte de áudio (usa o
  reconhecedor do sistema), então a detecção tem que ser separada.

## 4. LiveKit (TAREFA 33 como está no prompt)

Resolve conversa contínua e interrupção de verdade, mas exige: servidor
de voz (LiveKit Cloud, pago por minuto, ou instalado na VPS), um agente
em Python e provedores de reconhecimento e síntese **em tempo real**
(pagos por minuto) — custo recorrente por uso, além de dependência de
internet boa. Para o público e o tamanho do app hoje, não compensa antes
de esgotar 3a/3b.

## 5. Experimento de eco (3b) — medido em 14/10/2026: seguir

Branch **`feature/molly-interromper-voz`** (não vai para a versão do
usuário). Tela `lib/features/molly/screens/molly_eco_teste_screen.dart`,
rota `/molly-eco-teste` — roda sozinha ao abrir e escreve no log linhas
`ECO_TESTE <fase> aec=<bool> n=<amostras> mediana=… p90=… max=… dBFS`.

| Fase | O que acontece | Para que serve |
|---|---|---|
| `1_silencio_aec` | silêncio, com cancelamento de eco | ruído do ambiente |
| `2_molly_aec` | a Molly fala sozinha, com cancelamento | quanto da voz dela vaza no microfone |
| `3_molly_sem_aec` | a Molly fala sozinha, sem cancelamento (fonte `mic`) | referência: o eco bruto |
| `4_voce_aec` | a pessoa fala sozinha, com cancelamento | nível da voz da pessoa |
| `5_molly_e_voce_aec` | os dois falam juntos, com cancelamento | o caso real da interrupção |

Gravação: `record` 6.2, PCM 16 bits a 16 kHz mono, `echoCancel` e
`noiseSuppress` ligados, fonte `voiceCommunication`, e
**`audioInterruption: none`** — o padrão do plugin (`pause`) pausa a
gravação quando a fala da Molly toma o foco de áudio.

**Critério:** dá para interromper pela voz se a fase 2 ficar perto da 1 e
bem abaixo das fases 4 e 5 (uns 15 dB de folga no p90). Se a 2 ficar
perto da 4, a Molly "ouviria a si mesma" e o caminho para aí — o toque
continua sendo a forma de interromper.

**Como rodar** (aparelho conectado, pessoa pronta — fases 1–3 em silêncio,
4 contando até 15, 5 contando até 20 junto com a Molly; celular na mesa a
~30 cm, volume de mídia no máximo):

```powershell
# na branch feature/molly-interromper-voz, build em C:\MeLembraAI
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb logcat -c
adb shell am start -n com.melembra.ai/.MainActivity --es route /molly-eco-teste
adb logcat -d | Select-String ECO_TESTE
```

> A rota só abre com o app fechado: com ele aberto, o `am start` só traz
> a tarefa para a frente ("Activity not started") — rodar
> `adb shell am force-stop com.melembra.ai` antes.

### Resultado (14/10/2026, R9QL200MJ0N, Galaxy A07, Android 16)

Celular na mesa, ambiente silencioso, usuário seguindo as instruções da
tela.

| Fase | n | mediana | p90 | máx. (dBFS) |
|---|---|---|---|---|
| `1_silencio_aec` | 50 | −58,5 | −44,8 | −40,8 |
| `2_molly_aec` | 113 | **−90,0** | **−57,9** | −40,8 |
| `3_molly_sem_aec` | 112 | −33,3 | −23,8 | −20,3 |
| `4_voce_aec` | 88 | −36,9 | −20,7 | −14,2 |
| `5_molly_e_voce_aec` | 113 | −38,5 | −19,6 | −15,7 |

Leitura:
- **O cancelamento de eco funciona neste aparelho.** Sem ele (fase 3) a voz
  da Molly chega a −23,8 dB no p90; com ele (fase 2), −57,9 — uns 34 dB a
  menos, abaixo até do ruído do ambiente (fase 1). A mediana −90 é silêncio
  digital: o supressor de ruído zera os pedaços em que só a Molly fala.
- **A voz da pessoa passa, mesmo com a Molly falando junto**: fase 5
  (p90 −19,6) igual à fase 4 (p90 −20,7) — o cancelamento não apaga a
  fala de quem interrompe.
- **Folga no p90 entre a Molly sozinha e a pessoa: ~37 dB** (−57,9 vs.
  −20,7/−19,6), bem acima dos 15 dB do critério.

**Decisão: seguir** — implementar a detecção de voz durante a fala
(próximo passo, MOLLY-44 em `TASKS.md`). Cuidados para a implementação:
- a medição usou o `record` com fonte `voiceCommunication`; o
  `speech_to_text` usa o `SpeechRecognizer` do sistema, que **não** tem
  essa garantia — o certo é detectar a voz pelo `record` (limiar de
  volume entre −40 e −35 dBFS — a calibrar; a mediana da fala foi −36,9 —
  sustentado por ~300 ms, bem acima do −57,9 do eco)
  e, ao detectar, parar a fala e o gravador e só então abrir o STT;
- um aparelho só, em ambiente quieto, celular na mesa: conferir com TV
  ligada / celular na mão antes de considerar pronto, e manter o toque
  como forma de interromper (não substituir);
- o pico da fase 2 (−40,8, igual ao do silêncio) mostra que um limiar só
  de pico daria falso disparo — usar duração mínima, não um pedaço só.

Depois da medição o release 1.7.0 (`me-lembra-ai-v1.7.0.apk`) foi
reinstalado por cima (`adb install -r`, dados mantidos, sem
`DEBUGGABLE`).

## Ordem sugerida

1. **3a — interromper por toque** (pequeno, certo, grátis).
2. **3b — interromper pela voz**, em branch, medido no A07. Só segue se
   o eco for cancelado de verdade.
3. **"Molly" por voz** só se ainda for prioridade: protótipo com
   `open_wake_word`/`wakekit` em branch, medindo acerto com vozes de
   idosos, disparos falsos e bateria.
4. LiveKit: reavaliar depois.

## Fontes

- [vosk_flutter — versões](https://pub-web-s1.flutter-io.cn/packages/vosk_flutter/versions)
- [vosk_flutter_2 — documentação](https://pub.dev/documentation/vosk_flutter_2/latest/)
- [Modelos Vosk (alphacephei.com)](https://alphacephei.com/vosk/models)
- [Fim do plano grátis do Picovoice — Home Assistant Community](https://community.home-assistant.io/t/fyi-picovoice-confirmed-free-tier-accesskeys-will-stop-working-after-june-30-2026/1012744)
- [Planos do Picovoice](https://picovoice.ai/pricing)
- [flutter_wake_word — documentação](https://pub.dev/documentation/flutter_wake_word/latest/)
- [wakekit](https://pub.dev/packages/wakekit)
- [open_wake_word — score](https://pub.dev/packages/open_wake_word/score)
- Código das bibliotecas no cache do pub: `record_android-1.5.1`
  (`PCMReader.kt`, `RecordConfig.kt`), `speech_to_text-7.3.0`,
  `flutter_tts-4.2.5`.
