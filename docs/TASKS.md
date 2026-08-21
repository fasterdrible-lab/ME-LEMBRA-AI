# TASKS.md — Me Lembra Aí

> Backlog ordenado por prioridade. Marcar `[x]` ao concluir e registrar a sessão.

---

## Concluídas

| Task | Descrição | Sessão |
|---|---|---|
| TASK-01 | Firebase Auth: login, cadastro, recuperação de senha | 1–2 |
| TASK-02 | Onboarding 3 slides + flag `onboarding_visto` | 2 |
| TASK-03 | Seleção de 4 perfis (Idoso, Adulto, Filhos, Família) | 2 |
| TASK-04 | Telas de perfil: Idoso (TTS/STT/SOS/queda), Adulto, Criança, Família | 1–2 |
| TASK-05 | CRUD de lembretes no Firestore; correção da exclusão | 3 |
| TASK-06 | Notificações locais agendadas (única, diária, semanal) | 2 |
| TASK-07 | FCM: token salvo no Firestore; notificação local em foreground | 2 |
| TASK-08 | SOS: registro Firestore + chat automático + SosListenerService | 2–3 |
| TASK-09 | Build release: ProGuard Gson, pipeline fora do OneDrive | 3 |
| TASK-10 | Troca de perfil sem sair do app (BottomSheet em ConfigScreen) | 4 |
| TASK-11 | SOS push via VPS quando app encerrado (`sos_notifier.py`) | 5 |
| TASK-12 | Tela de histórico de confirmações de lembretes | 6 |
| TASK-13 | Widget Android de lembretes do dia (AppWidget 4×2) | 7 |
| TASK-14 | Modo escuro completo (ThemeData light + dark) | 8 |
| TASK-15 | 15 widget tests automatizados (login + create_reminder) | 9 |
| TASK-17 | SOS: ligação automática (CALL_PHONE + MethodChannel ACTION_CALL) | 10 |
| TASK-18 | SOS: canal `sos_alert` com fullScreen + vibração no familiar | 10 |
| TASK-19 | Chat áudio: segurar para gravar / soltar para enviar | 10 |
| TASK-20 | Maps: tela GoogleMap com posição atual e FAB SOS | 11 |
| TASK-21 | Foreground Service "Modo proteção ativo" (SosProtectionService.kt) | 11 |
| TASK-22 | SOS por teclas: 5 × volume em ≤ 3 s (MainActivity.onKeyDown) | 11 |
| TASK-23 | Configurar chave Google Maps API no AndroidManifest | 12 |
| TASK-25 | Countdown 5 s cancelável antes de disparar SOS | 12 |
| TASK-27 | Múltiplos contatos SOS (até 3); dialog para contatos adicionais | 12 |
| TASK-24 | Histórico SOS com status "visualizado por N familiares" | 12 |
| TASK-26 | SOS por 5 toques rápidos na tela (substitui Accessibility Service) | 12 |
| TASK-28 | Feature Veículos ativada: adulto (card dashboard) + idoso (botão) | 12 |
| TASK-29 | Certificado HTTPS do backend de IA (`certbot --nginx -d api.melbrai.com.br`, rodado pelo usuário via SSH) — `curl https://api.melbrai.com.br/healthz` de fora confirma `{"status":"ok"}` sem erro de TLS | 19 |
| TASK-31 | Chat Familiar: áudio não gravava (gesto segurar/soltar exigia precisão demais) — trocado para toque único; upload e reprodução confirmados funcionando de ponta a ponta no aparelho físico. Também corrigida a responsividade do botão de play (alvo de toque pequeno + sem feedback imediato ao tocar) | 21 |
| TASK-30 | Confirmado "Falar Comando" ponta a ponta com a IA — achada e corrigida a causa raiz real: a Groq descontinuou o modelo `llama-3.3-70b-versatile` (404 model_not_found), então a IA nunca respondia de fato, mesmo com certificado e rede OK. Trocado para `openai/gpt-oss-20b` (código + `.env` da VPS) | 21 |
| TASK-32 | "Falar Comando" evoluído pra assistente conversacional multi-turno: várias trocas seguidas sem tocar o botão de novo, nova ação `perguntar` (pede esclarecimento em vez de inventar dado), contexto real dos lembretes enviado à IA (grounding, incluindo itens da lista de compras), histórico limitado a 3 trocas, temperatura baixa, limite de 6 turnos por conversa, encerramento por frase ("obrigado"/"pode parar") ou silêncio. Testado ao vivo no aparelho físico | 21 |
| TASK-33 | Bug achado em teste ao vivo: dizer "SOCORRO" às vezes fazia o app falar "não entendi" **e** disparar o SOS ao mesmo tempo — causa raiz: o STT reporta status "done" (texto ainda vazio) um instante antes de entregar o resultado reconhecido, então `_processarComando('')` rodava e falava "não entendi" antes do evento com "SOCORRO" chegar e acionar o SOS de verdade. Corrigido com uma espera de 400 ms + checagem de `_sosDisparado` antes de falar "não entendi" — sem tocar na lógica/timing do SOCORRO em si. Confirmado corrigido pelo usuário no aparelho físico | 21 |
| TASK-34 | Detector de queda não funcionava com o app fechado, mesmo com "Modo Proteção" ativo — causa raiz: `SosProtectionService.kt` (Foreground Service nativo) não tinha nenhuma ligação com o `FlutterEngine`, que é destruído junto com a Activity quando o app fecha (comportamento padrão do `FlutterActivity`). Corrigido criando um `FlutterEngine` headless dentro do próprio serviço, rodando um novo entrypoint Dart (`fallDetectorEntrypoint`). Canal "call" extraído pra `CallChannel.kt` compartilhado. Confirmado no aparelho físico que o engine nasce e sobrevive ao fechamento do app, sem crash — disparo real da queda não testável neste aparelho (sem acelerômetro). SOS por 5 toques de volume confirmado como limitação permanente (precisaria de Accessibility Service, decisão de não implementar) | 22 |

---

## Pendentes

### TASK-16 — Publicação na Play Store (track interno)
**Prioridade:** Baixa  
**Arquivos:** `android/app/build.gradle.kts`, keystore  
**Descrição:** Assinar APK com keystore de produção e enviar para o track interno do Google Play Console.  
**Aceite:** APK disponível no Google Play Console (track interno), instalável via link.

---


---

## Regra de conclusão

1. Mover a task da seção "Pendentes" para a tabela "Concluídas"
2. Anotar a sessão
3. Atualizar `CURRENT_STATE.md` com os arquivos alterados
4. Atualizar `ARCHITECTURE.md` se o fluxo ou a estrutura mudou
