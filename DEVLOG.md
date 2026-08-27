# DEVLOG - Me Lembra Ai

Registro completo de decisoes tecnicas e resolucao de problemas.

---

## Sessao 1 - Configuracao inicial e correcao de encoding

### Problema 1: -Encoding utf8NoBOM nao suportado
**Erro:**
`
Out-File : O argumento "utf8NoBOM" nao pertence ao conjunto valido.
`
**Causa:** PowerShell versao antiga (Windows) nao suporta utf8NoBOM.
**Solucao:** Usar -Encoding utf8 + script Python para remover BOM:
`python
with open(path, 'r', encoding='utf-8-sig') as f: content = f.read()
with open(path, 'w', encoding='utf-8', newline='\n') as f: f.write(content)
`

---

### Problema 2: Emojis corrompidos na tela do app
**Sintoma:** Emojis apareciam como ðŸ'Š, Ã°Å¸â€™Å  etc.
**Causa:** Arquivos .dart salvos com encoding errado pelo PowerShell.
**Tentativas:**
- Substituicao via Python com string literal: falhou (encoding diferente no arquivo)
- Reescrita via PowerShell here-string: corrompeu o arquivo com caractere U+E000
- Reescrita via python -c: falhou com string multilinha contendo \n
**Solucao definitiva:** Escrever arquivo como lista de linhas em Python:
`python
lines = ['linha1', 'linha2', ...]
with open('lib/home_screen.dart', 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(lines) + '\n')
`

---

### Problema 3: Emojis na barra inferior corrompidos
**Causa:** Emojis escritos diretamente no codigo via PowerShell.
**Solucao:** Usar variaveis Python com escape unicode:
`python
casa = '\U0001F3E0'   # 🏠
pasta = '\U0001F4C2'  # 📂
mais = '\U00002795'   # ➕
config = '\U00002699' # ⚙️
`

---

### Problema 4: db nao reconhecido
**Erro:** db : O termo 'adb' nao e reconhecido
**Causa:** Android SDK nao esta no PATH do sistema.
**Solucao:** Usar Flutter diretamente:
`ash
flutter run -d R9QL200MJ0N --uninstall-first
`

---

### Problema 5: Dado corrompido no SharedPreferences
**Sintoma:** Lembrete 'Dipirona' exibia emoji corrompido mesmo apos correcao do codigo.
**Causa:** O lembrete foi salvo com emoji corrompido antes da correcao.
**Solucao:** Limpar dados do app:
`ash
flutter run --uninstall-first
# ou via adb (quando disponivel):
adb shell pm clear com.example.me_lembra_ai
`

---

## Sessao 2 - Análise de lacunas e continuidade (2026-05-11)

### Análise do estado do projeto

**Funcionalidades implementadas (verificadas):**
- [x] Firebase Auth (login, cadastro)
- [x] Tela de onboarding (3 slides)
- [x] Seleção de perfil (Vovô/Vovó, Adulto, Filhos)
- [x] Tela do Idoso: TTS, STT, SOS por voz, detecção de queda
- [x] Tela do Adulto: dashboard, sugestões inteligentes
- [x] Tela da Criança: tarefas gamificadas com barra de progresso
- [x] Tela Família: código de convite, vínculos, monitoramento
- [x] Tela de monitoramento: feed SOS + adesão a lembretes
- [x] Chat familiar: texto + áudio
- [x] Criar/Editar/Excluir lembretes (Firestore)
- [x] Notificações locais agendadas (única, diária, semanal)
- [x] FCM (push notifications)
- [x] Detector de queda (acelerômetro)
- [x] Serviço SOS com localização GPS
- [x] Briefing matinal por voz
- [x] Sugestões inteligentes de lembretes (heurística)
- [x] Regras Firestore com segurança por perfil
- [x] Pipeline de build no VPS Hetzner

**Lacunas identificadas e corrigidas nesta sessão:**

### Problema 6: Perfil "Família" ausente na seleção de perfis
**Causa:** ProfileSelectionScreen tinha apenas 3 cards (Vovô, Adulto, Filhos).
A rota `/family` existia mas não era acessível pela UI.
**Solução:**
- Adicionado card "Família" com ícone `Icons.family_restroom` em `profile_selection_screen.dart`
- Adicionado case 'Família' no `_routeForProfile` e no `_carregarPerfil` do `home_screen.dart`

### Problema 7: Imagens de perfil inexistentes causavam crash
**Causa:** `assets/images/avos.png`, `adultos.png`, `filhos.png` não existiam no repositório.
**Solução:** Substituídos `Image.asset` por `Icon` com círculo colorido em cada card de perfil.
Dependência de arquivos de imagem eliminada.

### Problema 8: withValues() incompatível com Flutter SDK local
**Causa:** `Colors.black.withValues(alpha: 0.08)` é API mais nova, causava aviso/erro em SDKs antigos.
**Solução:** Substituído por `withOpacity(0.08)` em `profile_selection_screen.dart`.

### Problema 9: Onboarding nunca exibido no primeiro acesso
**Causa:** `main.dart` redirecionava sempre para LoginScreen, ignorando a rota `/onboarding`.
**Solução:**
- `main.dart`: lê flag `onboarding_visto` do SharedPreferences antes de iniciar o app.
  Se false, exibe `OnboardingScreen` ao invés de `LoginScreen`.
- `onboarding_screen.dart`: ao concluir (ou pular), salva `onboarding_visto = true`.

### Problema 10: Sem recuperação de senha
**Causa:** LoginScreen não tinha fluxo "Esqueci minha senha".
**Solução:** Adicionado método `_esqueceuSenha()` que usa `FirebaseAuth.sendPasswordResetEmail`.
Botão "Esqueci minha senha" adicionado abaixo do campo de senha.

### Estado atual após sessão 2:
| Funcionalidade | Status |
|---|---|
| Perfil Família acessível | ✅ |
| Imagens de perfil (ícones) | ✅ |
| withOpacity correto | ✅ |
| Onboarding no primeiro acesso | ✅ |
| Recuperação de senha | ✅ |

### Próximos passos sugeridos:
- [ ] Tela de edição de perfil/nome dentro do app (sem sair para seleção)
- [ ] Notificação push servidor → familiar ao disparar SOS
- [ ] Widget de lembretes de hoje na home do Android (AppWidget)
- [ ] Tela de histórico de confirmações ("hoje você tomou X remédios")
- [ ] Modo escuro
- [ ] Internacionalização (i18n) para suporte a outros idiomas
- [ ] Testes de widget para telas críticas (LoginScreen, CreateReminderScreen)
- [ ] Publicação na Play Store (track interno)

---

## Sessão 3 - Correção de bugs críticos e build release (2026-05-12)

### Problema 11: Exclusão de lembretes não funcionava

**Sintoma:** Ao confirmar a exclusão na dialog, o lembrete permanecia na lista.

**Causa raiz (1ª tentativa):** `Navigator.pop(context, true)` usava o contexto externo do `StreamBuilder`, não o contexto da dialog — a operação `await showDialog<bool>` nunca recebia `true`.

**Causa raiz (2ª tentativa):** O padrão `await showDialog<bool>` + valor de retorno é inerentemente frágil quando o widget é reconstruído pelo `StreamBuilder` durante a abertura da dialog. O `await` pode retornar `null`.

**Solução definitiva:** Mover a chamada `ReminderService.delete()` para dentro do `onPressed` do botão de confirmação, capturando o `ScaffoldMessenger` antes de abrir a dialog.

**Arquivos alterados:**
- `lib/reminders_screen.dart` — método `_confirmarDelecao`
- `lib/features/elderly/meus_lembretes_screen.dart` — método `_excluir`
- `lib/features/elderly/elderly_screen.dart` — método `_excluirLembrete`

**Padrão correto:**
```dart
void _confirmarDelecao(BuildContext context, Reminder reminder) {
  final messenger = ScaffoldMessenger.of(context);
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            try {
              await ReminderService.delete(reminder.id);
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
            }
          },
          child: Text('Excluir'),
        ),
      ],
    ),
  );
}
```

---

### Problema 12: Card "Outros" exibia remédios incorretamente

**Sintoma:** Em `MeusLembretesScreen` (tela do idoso), o card "Outros" mostrava lembretes de remédios que deveriam estar no card "Remédios".

**Causa:** O getter `_isCategoria` comparava `r.type == 'Remédio'` (com acento), mas o valor armazenado no Firestore é `'Remedio'` (sem acento). O getter `_outros` não excluía a categoria `'tomar'` (tipo alternativo de remédio).

**Solução:** Corrigidas todas as comparações de tipo em `_isCategoria` para usar os valores exatos armazenados. Adicionado caso para `r.type == 'Tomar'`. O getter `_outros` passa a excluir explicitamente os tipos `'Remedio'` e `'Tomar'`.

**Arquivo alterado:** `lib/features/elderly/meus_lembretes_screen.dart`

---

### Problema 13: Onboarding pulava diretamente para ProfileSelectionScreen

**Sintoma:** Ao concluir o onboarding, o app ia direto para a seleção de perfis sem passar pela tela de login — o usuário nunca autenticava.

**Causa:** `onboarding_screen.dart` navegava para `ProfileSelectionScreen`. O `main.dart` detectava corretamente que o usuário não estava logado, mas `_concluir()` usava `pushAndRemoveUntil` para `ProfileSelectionScreen`, contornando o fluxo de auth.

**Solução:**
- `onboarding_screen.dart`: `_concluir()` navega para `LoginScreen`.
- `login_screen.dart`: após `signInWithEmailAndPassword`, navega explicitamente para `ProfileSelectionScreen` via `pushAndRemoveUntil`, sem depender do `StreamBuilder` do `main.dart`.

**Arquivos alterados:**
- `lib/features/onboarding/onboarding_screen.dart`
- `lib/login_screen.dart`

---

### Problema 14: Crash no dispositivo ao cancelar notificações (TypeToken)

**Sintoma:** App travava com `PlatformException: TypeToken must be created with a type argument` ao tentar cancelar uma notificação agendada no dispositivo físico (build release).

**Causa:** O R8 (minificador do Android) removia as assinaturas de tipo genérico de classes Gson usadas internamente pelo `flutter_local_notifications`. Em builds debug (sem R8) o erro não ocorria.

**Solução:** Adicionadas regras ProGuard em `android/app/proguard-rules.pro` para preservar as classes `TypeToken` do Gson:
```
-keepattributes Signature
-keepattributes *Annotation*
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.** { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
```

**Arquivo alterado:** `android/app/proguard-rules.pro`

---

### Problema 15: Build falhava com AccessDeniedException (OneDrive)

**Sintoma:** `flutter build apk --release` falhava com `AccessDeniedException` e `AAPT2 timeout` após ~4 minutos.

**Causa:** O OneDrive sincronizava arquivos intermediários da build em tempo real (especialmente as libs nativas `.so` da pasta `arm64-v8a`), mantendo locks nos arquivos que o Gradle precisava escrever.

**Solução:** Projeto copiado para `C:\MeLembraAI` (fora do OneDrive). Build executado a partir deste diretório.

```powershell
Copy-Item -Recurse -Force "C:\Users\phpos\OneDrive\MeLembraAI" "C:\MeLembraAI"
Set-Location "C:\MeLembraAI"
flutter build apk --release
```

**Observação:** Toda vez que houver alterações no código-fonte (OneDrive), é necessário recopiar os arquivos alterados para `C:\MeLembraAI` antes de fazer o build.

---

### Resultado da sessão 3

| Correção | Status |
|---|---|
| Exclusão de lembretes (3 telas) | ✅ |
| Card "Outros" sem remédios | ✅ |
| Onboarding → Login → ProfileSelection | ✅ |
| Crash TypeToken (ProGuard/R8) | ✅ |
| Build release fora do OneDrive | ✅ |
| APK gerado (62.3 MB) | ✅ |
| APK copiado para Área de Trabalho | ✅ |

**APK gerado:** `me-lembra-ai-v1.1.0.apk` (62.3 MB) — `C:\MeLembraAI\build\app\outputs\flutter-apk\app-release.apk`


### Arquivos corrigidos:
| Arquivo | Status |
|---|---|
| lib/main.dart | OK - limpo, sem emojis |
| lib/home_screen.dart | OK - emojis via unicode Python |
| lib/profile_selection_screen.dart | OK - sem emojis |

### Funcionalidades implementadas:
- [x] Tela de selecao de perfil (Vovo/Vova, Adulto, Crianca)
- [x] Tela home com header gradiente roxo
- [x] Lista de lembretes 'Hoje' e 'Em breve'
- [x] Cards com icone emoji colorido por categoria
- [x] Badge HOJ nos lembretes com hora definida
- [x] FAB roxo flutuante para adicionar lembrete
- [x] Barra inferior: Inicio / Categorias / Adicionar / Config
- [x] Botao SOS (dialog de confirmacao)
- [x] Data formatada em portugues no header

### Proximos passos sugeridos:
- [ ] Corrigir outros arquivos com encoding (create_reminder_screen, categories_screen, config_screen)
- [ ] Adicionar notificacoes locais (flutter_local_notifications)
- [ ] Implementar funcao de editar/deletar lembrete
- [ ] Implementar perfil Crianca com tela de monitoramento
- [ ] Adicionar suporte a voz (text-to-speech) para perfil Vovo
- [x] SOS: ligação automática (CALL_PHONE + MethodChannel ACTION_CALL)
- [x] SOS: notificação crítica fullScreen canal `sos_alert` no familiar
- [x] Chat áudio: segurar para gravar / soltar para enviar (GestureDetector + timer)
- [x] Maps: tela com GoogleMap, localização atual e FAB SOS
- [x] Foreground Service "Modo proteção ativo" (SosProtectionService.kt)
- [x] SOS por teclas: 5x volume em 3s dispara SOS (onKeyDown + EventChannel)
- [ ] Configurar chave Google Maps API no AndroidManifest
- [ ] Publicar na Play Store

---

## Sessão 10-11 — SOS completo, Maps e Foreground Service (2026-05-29)

### Implementações

**SOS auto-call (TASK-17):**
- `CALL_PHONE` adicionado ao AndroidManifest + queries `tel:`
- MethodChannel `com.melembra.ai/call` → `Intent.ACTION_CALL` no MainActivity
- `SosService._triggerCall()`: pede CALL_PHONE → ligação direta; negado → discador

**Notificação SOS crítica (TASK-18):**
- Canal `sos_alert`: Importance.max + fullScreenIntent + vibração Int64List[0,500,200,500,200,500]
- `NotificationService.showSosAlert()` usado pelo SosListenerService
- `server/sos_notifier.py`: FCM_CHANNEL_ID = "sos_alert", priority MAX, data com nome/motivo

**Chat áudio (TASK-19):**
- `GestureDetector` onLongPressStart/End no botão mic
- Timer de duração exibido no banner de gravação
- Toque simples mantido como toggle (acessibilidade)

**Maps (TASK-20):**
- `google_maps_flutter: ^2.9.0` adicionado ao pubspec
- `MapScreen`: GoogleMap + marcador posição atual + FAB "Enviar SOS com localização"
- Rota `/map`; botão "Minha Localizacao" na tela do idoso
- **Ação necessária:** substituir `YOUR_GOOGLE_MAPS_API_KEY` no AndroidManifest

**Foreground Service (TASK-21):**
- `SosProtectionService.kt`: Service com notificação persistente, START_STICKY, dataSync
- Toggle "Modo Protecao" na ConfigScreen; persiste via SharedPreferences
- `restoreIfEnabled()` chamado no `main()` após reinício

**SOS por teclas (TASK-22):**
- `onKeyDown` em MainActivity: 5x volume em ≤ 3s → EventChannel `volume_sos_events`
- `VolumeSosService.dart`: escuta evento e chama SosService.trigger(motivo: 'volume')
- Toggle "SOS por Teclas" na ConfigScreen

### Problema 16: Ícone inválido no SosProtectionService
**Causa:** `android.R.drawable.ic_lock_lock` não existe no SDK padrão.
**Solução:** Substituído por `android.R.drawable.ic_dialog_info`.

### Resultado
| Item | Status |
|---|---|
| APK gerado | ✅ `me-lembra-ai-v1.2.0.apk` (63.8 MB) |
| Warnings Java | Apenas obsolescence de source value 8 — não afeta funcionamento |
| Erros de compilação | Nenhum |

---

## Sessão 12 — Backlog zerado, manual e v1.3.0 (2026-06-01)

### Implementações

**Correções de bugs:**
- Fix TTS "lembrete de lembrete": `_inferirTipo` retornava `'Lembrete'` como fallback → mensagem ficava "Lembrete de Lembrete criado". Alterado para `'Remedio'` como fallback (perfil idoso). Mensagem TTS agora usa mapa de tipo → frase legível.
- Fix categoria Remédios: `_inferirTipo` retornava valores com acento (`'Remédio'`) incompatíveis com os valores canônicos do Firestore (`'Remedio'`). Corrigidos todos os retornos para valores sem acento.

**TASK-23:** Chave Google Maps API configurada no `AndroidManifest.xml`.

**TASK-25:** Countdown 5 s cancelável antes de disparar SOS. `StatefulBuilder` + `Timer.periodic` dentro de `showDialog`. Botão CANCELAR grande e visível.

**TASK-27:** Múltiplos contatos SOS (até 3). `SettingsService` migrado de `getString` para `getStringList`. `config_screen.dart` com lista dinâmica de TextEditingControllers. Após SOS, dialog exibe botões para ligar para contatos adicionais via `SosService.callNumber()`.

**TASK-24:** Histórico SOS com status "visualizado". Campo `viewedBy: List<String>` adicionado ao modelo `SosAlert`. `SosFeedService.markViewed()` chamado quando familiar abre `MonitorScreen`. Nova tela `SosHistoryScreen` no perfil do idoso. Badge "Visto (N)" no tile de SOS do familiar.

**TASK-26:** SOS por 5 toques rápidos na tela. `GestureDetector` com `HitTestBehavior.translucent` envolve o corpo da `ElderlyScreen`. Lista `_tapTimes` com janela de 3 segundos. Sem permissões especiais, substitui a abordagem de Accessibility Service.

**TASK-28:** Feature de Veículos ativada nos perfis. Adulto já tinha o card; idoso recebeu botão "Meus Veículos". Firestore em `users/{uid}/vehicles/`.

**Manual do usuário:** Nova tela `AboutScreen` (`lib/about_screen.dart`) acessível via Configurações → Sobre o App. Seções expansíveis por perfil + seções SOS, Lembretes, Veículos, Configurações. Rodapé: Copyright © 2026 HEXAGON TECNOLOGIA. Todos os direitos reservados.

**Versão:** `1.2.0+5` → `1.3.0+6`

### Resultado

| Item | Status |
|---|---|
| Todos os bugs da sessão corrigidos | OK |
| 6 tasks do backlog concluídas | OK |
| Manual do usuário criado | OK |
| Versão bumped para 1.3.0 | OK |
| APK gerado | me-lembra-ai-v1.3.0.apk |

---

## Sessão 23 — Início do projeto MOLLY (2026-08-26)

Usuário trouxe um prompt mestre extenso (37 tarefas em 8 fases) para
evoluir o "Falar Comando" numa assistente pessoal modular, a MOLLY.
Detalhamento completo em `docs/CURRENT_STATE.md` (seção "MOLLY —
assistente pessoal inteligente") e `docs/MOLLY_ARCHITECTURE_ANALYSIS.md`.

**TAREFA 1 (auditoria)**: produzida antes de qualquer código, por exigência
do próprio prompt mestre. Achado central: boa parte do que a MOLLY precisa
já existe, embutido em `elderly_screen.dart` desde as sessões 21/22
(conversa multi-turno, offline-first, grounding contra alucinação,
"SOCORRO" sempre local). Gap crítico: `FamilyMember` não guarda telefone,
então não há como "ligar para a filha" por nome hoje — decisão registrada
de usar o chat familiar como padrão em vez de expandir o schema agora.

**TAREFA 2 (núcleo)**: criado `lib/features/molly/` com
`molly_agent_service.dart` (núcleo estático, sem estado, sem TTS embutido)
+ `molly_message.dart`/`molly_tool_result.dart`. Portou fielmente a lógica
de resposta hoje em `elderly_screen.dart` (`_lerLembretesDoDia`,
`_falarResumoAlertas`, `_adicionarItensNaLista`,
`_criarLembreteDeAcao`/`_salvarLembrete`) sem remover nem alterar o
original — a substituição é um passo futuro deliberado, a ser testado no
aparelho físico antes de apagar a versão antiga. Reaproveita
`AiCommandService`/`ReminderService`/`SosFeedService`/`ProfileService`/
`NotificationService` já existentes; nenhuma chamada nova ao Firestore.

`flutter analyze` (projeto inteiro): nenhum problema novo introduzido —
os 51 avisos existentes já eram anteriores a esta sessão, nenhum em
`lib/features/molly/`. `flutter test`: mesma suíte de sempre, 16 passando
/ 6 falhando (os 6 de `reminder_service_test.dart`, pré-existentes desde
abril/2026, não relacionados).

**TAREFA 3 (registro de ferramentas)**: criado
`lib/features/molly/services/molly_tool_registry.dart` + os modelos
`molly_risk_level.dart` (enum LOW/MEDIUM/CRITICAL) e
`molly_tool_definition.dart` (nome/descrição/parâmetros/risco/executar),
mais quatro arquivos em `tools/`: `reminder_tool.dart` (createReminder,
getTodayReminders, getTomorrowReminders, updateReminder, deleteReminder,
confirmReminder, getReminderHistory), `family_tool.dart` (getFamilyMembers,
sendFamilyMessage, callFamilyMember), `location_tool.dart`
(getCurrentLocation) e `profile_tool.dart` (getUserProfile) — o catálogo
de 12 ferramentas exatamente como pedido no prompt mestre. Cada ferramenta
delega a um serviço já existente; nenhuma acessa Firestore direto. O gap
documentado na Tarefa 1 (sem telefone por familiar) foi resolvido como
planejado: `callFamilyMember` avisa pelo chat familiar em vez de discar,
mas continua classificada como CRITICAL — mesma categoria de "chamada
telefônica" do prompt mestre, porque a intenção do usuário é a mesma.
`deleteReminder` também ficou CRITICAL (exclusão é irreversível), e
`getCurrentLocation` ficou MEDIUM em vez de LOW (aciona o GPS na hora, ao
contrário de uma consulta a dado já salvo) — critérios documentados em
comentário no próprio código para a TAREFA 4 revisar se necessário.
`molly_agent_service.dart` foi refatorado para chamar o registro em
`criar_lembrete`/`ouvir_lembretes` em vez de manter lógica duplicada;
`consultar_alertas`/`adicionar_item_lista` continuam internos por não
constarem na lista oficial da TAREFA 3. `flutter analyze` do módulo: zero
problemas (corrigidos avisos de `const` ao longo do caminho). `flutter
test`: mesma suíte de sempre, sem regressão.

**TAREFA 4 (classificação de risco)**: criado
`lib/features/molly/services/molly_risk_policy.dart`
(`MollyRiskPolicy.executar`), aplicando as três regras do prompt mestre
sobre o `MollyRiskLevel` já registrado em cada ferramenta: LOW roda
direto; MEDIUM roda direto a menos que quem chama sinalize `ambiguo:
true`; CRITICAL sempre pede confirmação a menos que `emergenciaAutorizada:
true` — parâmetro reservado para uma futura ferramenta crítica com um
caminho de emergência legítimo, nunca para o SOS por voz em si, que
continua inteiramente fora deste caminho (nunca é uma "ferramenta" que a
IA decide chamar). Adicionado `MollyToolResult.precisaConfirmacao` +
`.confirmar()`, deliberadamente distinto de `precisaEsclarecimento`: um é
"faltou informação" (IA pediu mais dado), o outro é "a intenção já está
clara, só falta o sim do usuário por causa do risco". Também
`MollyRiskPolicy.confirmarEExecutar`, que reexecuta a mesma ferramenta com
os parâmetros já resolvidos guardados em
`dados['parametrosPendentes']` — sem voltar a chamar a IA. `deleteReminder`
foi classificado CRITICAL (irreversível) e `getCurrentLocation` MEDIUM
(aciona sensor ao vivo) na Tarefa 3; esta tarefa não revisitou essas
classificações, só a POLÍTICA de execução em cima delas.
`molly_agent_service.dart` passou a chamar `MollyRiskPolicy.executar` em
vez de `MollyToolRegistry.executar` diretamente. Criado
`test/molly_risk_policy_test.dart` (4 testes): CRITICAL sem emergência
pede confirmação sem tocar o serviço real; CRITICAL com emergência pula a
confirmação (comprovado indiretamente — sem Firebase inicializado, a
ferramenta real lança, provando que o portão foi pulado); MEDIUM com
ambiguidade pede confirmação; ferramenta inexistente falha sem lançar
exceção. Esses testes não precisam de mocks de Firebase porque o gate de
confirmação retorna antes de qualquer chamada real a serviço. `flutter
analyze`: zero problemas. `flutter test`: suíte cresceu de 16 para 20
testes passando, mesmos 6 falhando pré-existentes.

**TAREFA 5 (voz conversacional)**: criado
`lib/features/molly/services/molly_voice_service.dart`
(`MollyVoiceService`), extraindo a lógica de STT hoje embutida em
`elderly_screen.dart` (`_iniciarEscuta`/`_finalizarComando`/`_falar`) para
uma classe própria. Diferente de todos os outros serviços da MOLLY até
agora (estáticos, sem estado), este é deliberadamente instanciável —
guarda o `SpeechToText` de verdade e o estado da conversa por voz, então
precisa de ciclo de vida (uma instância por tela, `dispose()` ao
descartar), igual ao campo `_speech` que `elderly_screen.dart` já mantém
hoje. Estado exposto via `ValueNotifier<MollyVoiceState>` (idle/
listening/thinking/speaking/error) — pensado para a TAREFA 6 (tela da
MOLLY) observar direto com `ValueListenableBuilder`, sem reimplementar a
mesma máquina de estados de novo lá. Reaproveita `speech_to_text` e o
`VoiceService` (TTS) já existentes sem tocar nenhum dos dois.

Portada a correção da TASK-33 (sessão 21) — a corrida real do plugin
`speech_to_text`, onde o status "done"/"notListening" às vezes chega antes
do `onResult` entregar a transcrição final, podia atropelar "SOCORRO" com
um "não entendi" — mas de forma generalizada: a espera de 400ms mora
agora dentro de `_finalizarTurno`, e quem chama [`escutar`] decide, via
`aoOuvirParcial`, o que fazer com cada trecho reconhecido (inclusive
detectar palavras críticas). A detecção de "SOCORRO" em si **não foi
movida para cá** — continua sendo responsabilidade explícita de quem usa
o serviço, documentado no código, para preservar a garantia de que o SOS
nunca depende desta camada estar correta.

`interromperFala()` foi incluída como primitiva (para um futuro "voltar a
falar interrompe a MOLLY"), mas sem duplexação real ouvir+falar ao mesmo
tempo — implementar isso de verdade sobre o `speech_to_text` clássico
seria um comportamento novo e não testado em campo; a decisão registrada
é deixar isso para a TAREFA 33 (voz em tempo real via LiveKit), que já é o
lugar certo do prompt mestre para "interrupção de fala".

`elderly_screen.dart` não foi alterado. Sem teste automatizado novo desta
vez: `speech_to_text`/`flutter_tts` não têm mock no projeto (gap já
registrado na Tarefa 1) — validar de verdade depende do aparelho físico ou
de infraestrutura de teste ainda não construída (TAREFA 28). `flutter
analyze`: zero problemas. `flutter test`: mesma suíte de 20/6, sem
regressão.

**TAREFA 6 (tela principal)**: criado
`lib/features/molly/screens/molly_screen.dart` +
`widgets/listening_indicator.dart` — a primeira UI própria da MOLLY,
acessível para 60+ como pedido no prompt mestre: botões grandes (mic de
120px), alto contraste, poucas opções na tela, texto grande no lugar de
depender só de cor/ícone, e as três indicações pedidas ("Estou ouvindo" /
"Pensando" / "Falando") ligadas de verdade ao `ValueNotifier<MollyVoiceState>`
de `MollyVoiceService` (TAREFA 5). Diferente de um mockup estático, a tela
conecta o fluxo real: toca o microfone → `MollyVoiceService.escutar()` →
"SOCORRO" é checado local em `aoOuvirParcial` (nunca pela IA, mesma
garantia de `elderly_screen.dart`) → texto final vira
`MollyAgentService.processar()` → resultado é falado por
`MollyVoiceService.falar()`/`falarSequencia()` → se
`resultado.precisaConfirmacao` (TAREFA 4), um único turno extra de escuta
decide sim/não e chama `MollyRiskPolicy.confirmarEExecutar()` com os
parâmetros já resolvidos (sem voltar à IA). A lista "Hoje" usa
`StreamBuilder` sobre `ReminderService.stream()` — dado real, ao vivo, não
mockado. O botão SOS fica fixo fora da área rolável, fora de qualquer
condicional — nunca escondido, cumprindo a regra explícita do prompt
mestre ("nunca esconda o botão SOS").

Decisão de escopo registrada no código: esta tela **não** implementa a
máquina de conversa completa de `elderly_screen.dart` (vários turnos
seguidos, coleta determinística de dia/hora, limite de 6 turnos, frases de
encerramento) — só um turno de pergunta/resposta mais, quando necessário,
um turno de confirmação. Isso é suficiente pra exercitar o pipeline
voz→agente→risco de ponta a ponta sem inventar a máquina de estados que
pertence a um controller futuro (`molly_controller.dart`, TAREFA 7+).

Rota `/molly` adicionada em `main.dart` (uma linha no mapa de rotas) —
única alteração fora de `lib/features/molly/` nesta tarefa. Nenhum botão
existente navega pra lá: a tela é aditiva de propósito, só alcançável
manualmente (deep link/rota nomeada) até que uma flag `mollyEnabled`
(TAREFA 35) e uma decisão consciente de trocar o "Falar Comando" existam.

Criado `test/molly_screen_test.dart` (4 testes) cobrindo só a estrutura
estática (título, indicador ocioso, mensagem inicial, botão de microfone
com `Semantics` acessível, botão SOS sempre presente, seção "Hoje") — sem
tocar o microfone, pelo mesmo motivo da Tarefa 5 (sem mock de
`speech_to_text` no projeto). `flutter analyze`: zero problemas em
`lib/features/molly/` e `lib/main.dart`. `flutter test`: suíte cresceu de
20 para 24 testes passando, mesmos 6 falhando pré-existentes.

**TAREFA 7 (memória de curto prazo)**: criado
`lib/features/molly/memory/short_term_memory.dart` (`ShortTermMemory`),
extraindo pra uma classe própria o que hoje são campos soltos em
`elderly_screen.dart` (`_historicoConversa`, `_turnosConversa`,
`_coletandoLembrete`, `_slotDia`/`_slotMes`/`_slotAno`/`_slotHora`/
`_slotMinuto`, `_primeiroTextoConversa`). Segunda classe instanciável da
MOLLY (depois de `MollyVoiceService` na Tarefa 5) — faz sentido pelo mesmo
motivo: guarda estado real de uma conversa em andamento, não é um serviço
sem estado.

Duas responsabilidades deliberadamente juntas na mesma classe, por
compartilharem o ciclo de vida (nascem e morrem com a conversa): (1) o
histórico de trocas, pra dar continuidade a perguntas em linguagem
natural — o exemplo do prompt mestre, "quando é minha consulta?" → "amanhã
às 14h" → "me lembra duas horas antes", só funciona com esse histórico —
limitado a 3 trocas (`maxTrocas`, mesmo valor de `_maxHistoricoTrocas`) e
exposto como `historicoParaIA` já no formato `List<ConversaTurno>` que
`AiCommandService.interpretar` espera; (2) os slots de dia/hora de coleta
de lembrete, que ficam **fora** desse histórico de propósito — a sessão
22 (documentada em `docs/CURRENT_STATE.md`) já tinha achado que a IA
esquece dado estruturado entre turnos mesmo recebendo o histórico, e essa
é exatamente a razão de `elderly_screen.dart` ter um mecanismo local
determinístico separado pra isso; `ShortTermMemory` só guarda o resultado
já interpretado (`mesclarSlots`), a extração de texto em si (regex de
data/hora) continua fora desta classe.

Integração real, não só um arquivo isolado:
`MollyAgentService.processar()` trocou o parâmetro solto
`historico: List<MollyMessage>` por `memoria: ShortTermMemory?` — usa
`memoria.historicoParaIA` pra montar a chamada à IA e registra a troca
sozinho ao final (`memoria.registrarTroca`), então quem chama não precisa
lembrar de atualizar a memória manualmente. Isso também permitiu remover
o método `_paresParaHistorico` (agora redundante, a mesma lógica já mora
em `ShortTermMemory.historicoParaIA`). Quando a IA responde `perguntar`,
o agente marca `memoria.coletandoLembrete = true` — preparação para a
TAREFA 17 (extrair os parsers de data/hora de `elderly_screen.dart` para
um `OfflineIntentService`), mas **ainda não consumida por nenhum
controller**: `molly_screen.dart` (TAREFA 6) recebeu uma instância de
`ShortTermMemory` por visita à tela — tocar o microfone de novo depois de
uma resposta agora continua a mesma conversa (o exemplo do prompt mestre
já funciona nesta tela) — mas ainda não faz a coleta local determinística
de dia/hora; se a IA pedir esclarecimento, a tela só fala a pergunta e
volta a chamar a IA no próximo toque, com o mesmo risco de "esquecimento"
que motivou aquele mecanismo em `elderly_screen.dart`. Isso está
documentado explicitamente no código e reportado ao usuário como lacuna
conhecida, não escondido.

Criado `test/short_term_memory_test.dart` com 6 testes 100% puro Dart
(sem Firebase, sem plugins): contagem e limite de turnos; primeira fala
guardada uma única vez; histórico da IA descarta trocas antigas além do
limite; `mesclarSlots` preenche sem sobrescrever o que já foi confirmado;
`encerrar()` reseta tudo de uma vez. `flutter analyze`: zero problemas.
`flutter test`: suíte cresceu de 24 para 30 testes passando, mesmos 6
falhando pré-existentes.

**TAREFA 8 (memória de longo prazo)**: criado
`lib/features/molly/memory/long_term_memory.dart`
(`LongTermMemoryService`) + `models/molly_memory_entry.dart`, persistindo
em `users/{uid}/molly_memory/{id}` com exatamente os campos pedidos no
prompt mestre: `type`, `value`, `source`, `createdAt`, `updatedAt`,
`confidence`, `userApproved`.

A regra mais importante da tarefa — "nunca salvar informação sensível
automaticamente sem autorização" — foi aplicada em duas camadas
independentes, de propósito redundantes: (1) `salvar()` recusa gravar se
`userApproved` não vier `true` explicitamente, sem valor padrão que
permita esquecer de passar isso; (2) mesmo com `userApproved: true`,
também confere um interruptor geral novo,
`SettingsService.getMollyMemoriaAutorizada()`
(`cfg_molly_memoria_autorizada`, padrão `false` — opt-in), que corresponde
ao "A MOLLY pode lembrar minhas preferências? SIM/NÃO" que a TAREFA 9 vai
expor numa tela. Uma memória individual aprovada não basta se o usuário
desligou a memória por completo depois — as duas checagens continuam
independentes.

`firestore.rules` ganhou a regra para `users/{uid}/molly_memory/{memId}`:
**privada ao dono**, sem `isFamilyOf(uid)` — diferente de `reminders`, que
a família lê. Decisão já registrada na Tarefa 1 (risco 7): preferências
pessoais não são automaticamente algo que um cuidador deveria enxergar.
Deploy executado nesta mesma sessão, com autorização explícita do
usuário: `firebase deploy --only firestore:rules --project
me-lembra-ai-bf0f0` — `+ Deploy complete!`, regra em produção. Registrado
também em `docs/CURRENT_STATE.md`, seção "Deploy das regras/índices do
Firestore".

CRUD completo: `salvar`, `stream`/`getAll` (mais recentes primeiro),
`atualizarValor` (edição de uma memória já aprovada — não passa pela
checagem de autorização de novo, editar é diferente de criar sem
consentimento), `excluir`, `excluirTudo`. Nada disso foi ligado ao fluxo
de conversa ainda: não existe hoje nenhum ponto do código que decida "a
Molly quer lembrar isso" e chame `salvar()` — isso demanda uma UI de
consentimento (TAREFA 9) antes de fazer sentido ligar. Sem teste
automatizado novo: mesmo gap de Firebase que já existe pra
`ReminderService`/`FamilyService`/`ChatService`/etc., nenhum desses tem
testes unitários no projeto hoje — não é uma lacuna nova desta tarefa.
`flutter analyze`: zero problemas. `flutter test`: mesma suíte de 30/6,
sem regressão.

**TAREFA 9 (tela "O que a Molly lembra")**: criado
`lib/features/molly/screens/molly_memory_screen.dart` — único ponto de
contato do usuário com a memória de longo prazo criada na TAREFA 8.
Implementa exatamente os cinco pontos pedidos no prompt mestre:
visualizar (lista ao vivo via `StreamBuilder` sobre
`LongTermMemoryService.stream()`), editar (dialog simples com
`TextField`, chama `atualizarValor`), excluir uma por uma (dialog de
confirmação, mesmo padrão de exclusão de lembrete já usado em outras
telas do app), apagar tudo (`excluirTudo`, dialog de confirmação
reforçando que é irreversível), e o interruptor "A Molly pode lembrar
minhas preferências? SIM/NÃO" — que também cumpre o pedido "impedir novas
memórias": desligá-lo não faz nada de novo aqui, só reforça a checagem
que `LongTermMemoryService.salvar()` já fazia desde a TAREFA 8
(`SettingsService.getMollyMemoriaAutorizada()`). Memórias já guardadas
continuam visíveis e editáveis mesmo com o interruptor desligado — só
gravações novas são bloqueadas.

"Privacidade totalmente transparente" (exigência explícita da tarefa) foi
levada a sério: cada card mostra o tipo (com rótulo em português, não o
`type` cru do Firestore), o valor, quando foi atualizado e a origem
(`source`) — nada fica escondido atrás de um resumo genérico. Além disso,
usei o campo `confidence` de um jeito que já estava planejado desde o
comentário original em `MollyMemoryEntry` (Tarefa 8): memórias com
`confidence < 0.7` ganham um ícone de alerta e o texto "Baixa confiança —
confira se está certo", sem descartar nada automaticamente — é a TAREFA 9
dando uso real a uma decisão de design já tomada duas tarefas atrás.

Rota `/molly-memory` adicionada em `main.dart`, mesmo padrão aditivo de
`/molly` (TAREFA 6) — nenhum botão existente navega pra lá. Criado
`test/molly_memory_screen_test.dart` com 4 testes, incluindo um de ponta
a ponta que tampa o gap de Firebase de forma diferente das outras telas:
como o interruptor usa só `SettingsService` (SharedPreferences, sem
Firestore), dá pra testar o ciclo completo — tocar o Switch na tela e
confirmar que `SettingsService.getMollyMemoriaAutorizada()` realmente
persistiu `true` — sem precisar de nenhum mock adicional. `flutter
analyze`: zero problemas. `flutter test`: suíte cresceu de 30 para 34
testes passando, mesmos 6 falhando pré-existentes.

**TAREFA 10 (contexto do usuário)**: criado
`lib/features/molly/services/molly_context_service.dart`
(`MollyContextService.montar()`) + `models/molly_user_context.dart`,
agregando num só lugar tudo que a MOLLY tem permissão de conhecer agora:
nome/perfil (`ProfileService`), próximos lembretes e histórico recente
confirmado (`ReminderService`, sempre resumidos — nunca o documento
completo), familiares (`FamilyService`, só os nomes, nunca uid/papel),
configurações relevantes (SOS/chat/notificações ativos), horário atual, e
preferências (`LongTermMemoryService`, só se
`SettingsService.getMollyMemoriaAutorizada()` — terceira camada
independente reforçando o mesmo portão de consentimento das TAREFAs 8/9).
Quando uma `ShortTermMemory` é passada, o contexto também reflete o
estado da conversa atual (turnos, `coletandoLembrete`).

A regra central da tarefa — "nunca enviar todo o Firestore ao modelo" —
foi levada além do pedido: `MollyUserContext.lembretesParaIA` continua
sendo o **único** subconjunto de fato mandado ao backend de IA hoje (o
contrato de `AiCommandService`/`app.py` não mudou nesta tarefa —
documentado explicitamente no código que ampliar isso é decisão futura,
ligada à TAREFA 32 de abstração de provedor). O resto do contexto (nome,
familiares, preferências, configurações, histórico) fica pronto para
outros consumidores do app — proatividade (TAREFA 23), briefing (TAREFA
13), telas futuras — sem cada um duplicar a lógica de busca.

Absorveu `MollyAgentService.contextoPadraoDeLembretes()` (TAREFA 2), que
fazia a mesma coisa só para lembretes — removido o método, `molly_screen.dart`
atualizado para chamar `MollyContextService.montar(memoria: _memoria)` e
usar `.lembretesParaIA` no lugar.

**Achado de infraestrutura de teste**: tentei escrever
`test/molly_context_service_test.dart` explorando que, sem usuário
logado, `ProfileService`/`ReminderService`/`FamilyService`/
`LongTermMemoryService` já retornam vazio/nulo antes de tocar o Firestore
de verdade — em teoria, testável sem mocks de Firestore. Na prática,
esbarrei num problema diferente e novo: o **primeiro** acesso a
`FirebaseAuth.instance` dentro de um processo de teste (não importa qual
serviço o dispara) constrói o delegate do `firebase_auth` e registra
`registerIdTokenListener`/`registerAuthStateListener` via platform
channel — canal que `test/support/firebase_core_mocks.dart` não mocka
(ele só cobre `firebase_core`). Sem handler, essas chamadas rejeitam de
forma assíncrona e "vazam" como falha barulhenta pra outro teste do mesmo
arquivo (aparece como `This test failed after it had already completed`),
mesmo com a lógica testada 100% correta. Descartei o arquivo de teste em
vez de aceitar uma suíte com falha instável — mesmo princípio já aplicado
a `ReminderService`/`FamilyService`/etc. (documentado desde a Tarefa 1).
Registrado aqui e em `docs/CURRENT_STATE.md` para quando a TAREFA 28
avaliar um mock de `firebase_auth` mais completo — vale a pena, porque
desbloquearia testar boa parte dos serviços já existentes no projeto, não
só os da MOLLY.

`flutter analyze`: zero problemas em `lib/features/molly/`. `flutter
test`: mesma suíte de 34/6, sem regressão.

**TAREFA 11 (personalidade)**: criado
`lib/features/molly/services/molly_prompt_service.dart` com a descrição
formal da personalidade nos termos exatos do prompt mestre — paciente,
educada, simples, gentil, objetiva, acolhedora; nunca infantiliza; nunca
usa linguagem técnica; frases curtas (1-3) — mais uma checagem leve e
reutilizável, `contemLinguagemTecnica()`, pra conferir uma fala nova
antes de shipar (não é chamada automaticamente em nenhum fluxo, é
ferramenta de revisão/teste).

Em vez de só documentar a regra, fiz uma auditoria real de todas as falas
já escritas nas Tarefas 2 a 10 (`grep` por termos técnicos em
`lib/features/molly/`) e achei duas violações concretas: "Reconhecimento
de voz indisponível." em `molly_screen.dart` e `molly_voice_service.dart`
— exatamente o padrão do exemplo "ruim" do prompt mestre (nomeia o
subsistema em vez de falar com a pessoa). Corrigidas para "Não consegui
usar o microfone agora/neste aparelho.", no mesmo espírito do exemplo
"bom" — que, aliás, eu já tinha usado ao pé da letra em
`location_tool.dart` desde a Tarefa 3, sem perceber que estava seguindo
essa regra antes dela existir formalmente.

A personalidade também foi aplicada onde ela pesa de verdade: o
`SYSTEM_PROMPT` real que vai para a Groq, em
`server/ai_command_server/app.py`. Adicionada uma seção explícita de
personalidade antes do contrato JSON de ações, com as mesmas regras do
lado Dart — assim o campo `"fala"` que a IA gera (usado em `responder`,
`perguntar`, etc.) também segue o padrão, não só as falas escritas à mão
no app. Implantado em produção nesta mesma sessão, a pedido explícito do usuário.
Detalhe do processo, pra ficar registrado: nenhuma chave SSH local do
usuário valia pra essa VPS (mesmo achado da sessão 17), então criei uma
chave dedicada nova (`~/.ssh/melembra_vps`, ed25519, sem senha) e pedi
para o usuário adicionar a chave pública ao `authorized_keys` da VPS. Em
vez disso, o usuário colou a **senha root da VPS em texto plano na
conversa**. Usei essa senha uma única vez, só para instalar a chave
pública via um script Python (`paramiko`) que não persistiu a senha em
nenhum arquivo — depois disso, toda a sessão SSH passou a usar a chave
dedicada, sem senha. Como a senha ficou exposta no histórico desta
conversa, registrei uma recomendação explícita para o usuário trocá-la
(`docs/CURRENT_STATE.md`) — a chave nova já é suficiente para qualquer
acesso futuro deste projeto a essa VPS, a senha antiga não precisa mais
ser usada em nenhum fluxo. Deploy em si: `app.py` copiado via `scp` para
`/root/ai_command_server/app.py`, `systemctl restart
melembra-ai-backend`, `healthz` confirmado `{"status":"ok"}` tanto local
(`127.0.0.1:8091`) quanto externo (`https://api.melbrai.com.br/healthz`).

Criado `test/molly_prompt_service_test.dart` com 4 testes 100% puro Dart:
os exemplos ruim/bom citados literalmente no prompt mestre, e dois casos
genéricos (maiúsculas/minúsculas, frase limpa). `flutter analyze`: zero
problemas. `flutter test`: suíte cresceu de 34 para 38 testes passando,
mesmos 6 falhando pré-existentes.

**TAREFA 12 (respostas curtas)**: adicionado
`MollyPromptService.resumoCurto<T>()` — gera uma fala de 1 a 3 frases a
partir de uma lista de itens, seguindo exatamente as regras do prompt
mestre: 0 itens devolve vazio; 1 item vira uma frase nomeando ele; 2
itens seguem ao pé da letra o exemplo literal do prompt mestre ("Você tem
2 X. Um é [...], e o outro é [...]."); 3 ou mais itens dizem só a
quantidade e citam o primeiro, sem nunca ler a lista inteira — é
exatamente essa última regra ("evitar... listas extensas faladas") que
motivou a tarefa.

Achei uma violação real ao revisar o código das tarefas anteriores:
`ReminderTool._remindersDoDia()` (por trás de `getTodayReminders` e
`getTomorrowReminders`, TAREFA 3) gerava `falasEmSequencia` com **um item
de TTS por lembrete** — ou seja, com muitos lembretes no dia, a MOLLY
literalmente leria a lista inteira item por item, o oposto exato do que
esta tarefa pede. Corrigido: agora chama `resumoCurto`, devolvendo uma
única fala. Importante — a lista completa continua em
`dados['lembretes']`, porque a regra de "resposta curta" é sobre o que é
**falado**, não sobre o que aparece na tela: `molly_screen.dart` continua
mostrando todos os lembretes no card "Hoje" normalmente, só a voz que
ficou objetiva.

O `SYSTEM_PROMPT` do backend também ganhou a regra, com o mesmo exemplo
literal do prompt mestre ("Nunca leia uma lista item por item numa
'fala' só..."), reforçando o padrão pro campo `fala` gerado pela própria
IA (não só pras falas escritas à mão no app). Implantado em produção
nesta mesma sessão, com autorização explícita do usuário — desta vez sem
nenhuma senha envolvida: a chave SSH dedicada criada na Tarefa 11
(`~/.ssh/melembra_vps`) já bastou para `scp` + `systemctl restart
melembra-ai-backend`, `healthz` confirmado `{"status":"ok"}` local e via
`https://api.melbrai.com.br/healthz`, arquivo remoto conferido idêntico
ao local por `diff`.

Ampliado `test/molly_prompt_service_test.dart` com 4 testes novos de
`resumoCurto` (0/1/2/3+ itens, incluindo o exemplo literal de 2 itens).
`flutter analyze`: zero problemas. `flutter test`: suíte cresceu de 38
para 42 testes passando, mesmos 6 falhando pré-existentes.

**TAREFA 13 (briefing matinal inteligente)**: criado
`lib/features/molly/services/molly_briefing_service.dart`
(`MollyBriefingService`), evoluindo de verdade o resumo matinal — que
até aqui era só `NotificationService.scheduleMorningBriefing()`, uma
notificação Android fixa e genérica ("Bom dia! ☀️" / "Confira seus
lembretes de hoje no Me Lembra Aí."), sem nenhum lembrete real dentro.
`gerar()`/`gerarDeLista()` montam a fala de verdade, no formato exato do
exemplo literal do prompt mestre: saudação, contagem, até dois destaques
nomeados por tipo ("Seu remédio"/"Sua consulta", mapeados em
`_sujeitoPorTipo`; tipos sem mapeamento caem pro título do lembrete, ou o
tipo cru como último recurso), fechamento "Quer que eu leia tudo?". Com 3
ou mais lembretes, só os dois primeiros (mais próximos) são destacados —
mesma disciplina de respostas curtas da TAREFA 12, para não virar uma
lista extensa falada. `gerar()` busca os lembretes reais
(`ReminderService.getAll()`, filtrados pro dia); `gerarDeLista()` fica
separado recebendo a lista já pronta, exatamente pelo mesmo motivo da
Tarefa 10 — evitar que um teste toque `FirebaseAuth.instance` e esbarre
no problema de platform channel sem mock já documentado.

**Bug pré-existente achado e corrigido** ao revisar o fluxo de
notificações pra decidir onde ligar o novo serviço:
`NotificationService._onNotificationTap()` (em `lib/services/
notification_service.dart`) lida com o toque em qualquer notificação
capitalizando o `payload` recebido e falando isso em voz alta — funciona
bem pra lembretes normais (o payload é o corpo real do lembrete), mas a
notificação matinal usa o payload fixo `'matinal'` (só um marcador,
nunca pensado pra ser falado). Resultado: tocar na notificação das 8h
fazia o app literalmente dizer **"Matinal!"** em voz alta — um bug real,
silencioso, que ninguém tinha notado porque a notificação sempre foi só
visual/textual antes desta tarefa dar um motivo pra alguém prestar
atenção nesse caminho de código. Corrigido com um caso especial: quando
`payload == 'matinal'`, chama `MollyBriefingService.gerar()` e fala o
resultado; todo o resto do comportamento (lembretes normais) ficou
intacto. Mudança pequena e isolada, mas em arquivo que a documentação
antiga (`AGENTE.md`) já classificava como risco "Alto" — testado com
`flutter analyze`/`flutter test` completos antes de seguir.

Contexto opcional citado no prompt mestre para o futuro — previsão do
tempo, aniversários, mensagens familiares — não entrou nesta tarefa; só
lembretes reais, a única fonte de dado já confiável hoje.

Criado `test/molly_briefing_service_test.dart` com 5 testes 100% puro
Dart: sem lembretes; um lembrete; o exemplo literal de dois lembretes
(remédio às 8h + consulta às 14h) reproduzido palavra por palavra; três
ou mais lembretes confirmando que só os dois primeiros aparecem na fala;
e um tipo sem sujeito mapeado caindo pro título/tipo. `flutter analyze`:
zero problemas novos (os 2 avisos pré-existentes de
`notification_service.dart` continuam lá, só com número de linha
deslocado pelas linhas que acrescentei). `flutter test`: suíte cresceu de
42 para 47 testes passando, mesmos 6 falhando pré-existentes.

**TAREFA 14 (comandos naturais)**: o pedido era garantir que frases bem
diferentes ("Me lembra do remédio às oito.", "Coloca um lembrete para
oito horas.", "Às oito eu preciso tomar meu remédio.", "Não deixa eu
esquecer o remédio às oito.") gerem sempre a mesma intenção
(`createReminder`). Como o caminho principal de NLU hoje é a Groq (via
`AiCommandService`) — que já lida naturalmente bem com paráfrase — a
ação mais concreta e de maior efeito real foi reforçar a regra
"criar_lembrete" do `SYSTEM_PROMPT` (`app.py`) citando as quatro frases
literais como sinônimos explícitos (few-shot), deixando claro pro modelo
que elas devem convergir pra mesma ação.

Além disso, criado `lib/features/molly/models/molly_intent.dart`
(`MollyIntentHints.pareceCriarLembrete`) — um sinal local, determinístico
e 100% testável (sem IA, sem rede), reconhecendo as mesmas quatro frases
e variações próximas via palavras-gatilho ("me lembra", "coloca um
lembrete", "preciso", "não deixa eu esquecer", etc.). Documentado
explicitamente como **não ligado a nenhuma decisão real ainda**: hoje
`MollyAgentService` não tem nenhum caminho de criar lembrete sem IA (só o
`elderly_screen.dart` antigo tem, com seus próprios parsers de
data/hora) — este arquivo é a base que a TAREFA 17
(`OfflineIntentService`) vai consumir quando esses parsers forem
extraídos. Por ser só um sinal, sem nada crítico decidido em cima dele, a
lista de gatilhos foi deixada propositalmente ampla (prioriza recall
sobre precisão — inclui até "preciso"/"tenho que", que sozinhos são bem
genéricos).

Criado `test/molly_intent_test.dart` (3 testes, 100% puro Dart): as
quatro frases literais da tarefa; maiúsculas/minúsculas e acentuação; e
frases de outras intenções (ouvir lembretes, adicionar na lista, SOCORRO,
consultar alertas) que não devem disparar o sinal. `flutter analyze`:
zero problemas. `flutter test`: suíte cresceu de 47 para 50 testes
passando, mesmos 6 falhando pré-existentes. Mudança no `SYSTEM_PROMPT`
implantada em produção nesta mesma sessão, com autorização do usuário —
`scp` + `systemctl restart melembra-ai-backend`, `healthz` OK interno e
externo, arquivo remoto conferido idêntico ao local por `diff`.

**TAREFA 15 (Modo Companhia)**: novo interruptor opcional
`SettingsService.getMollyModoCompanhia()`/`setMollyModoCompanhia()`
(`cfg_molly_modo_companhia`, padrão `false` — mesmo padrão de opt-in já
usado pra memória de longo prazo na Tarefa 8). Sem tela própria pra
ligar/desligar ainda: isso é trabalho da TAREFA 24
(`molly_settings_screen.dart`), que vai reunir todos esses interruptores
num só lugar.

`MollyPromptService` ganhou a constante `modoCompanhia`, documentando as
regras de tom (calor humano, história curta permitida quando pedida) e o
guardrail que é o centro real desta tarefa: a MOLLY nunca substitui
acompanhamento médico ou psicológico, e diante de sinais de tristeza ou
solidão deve sugerir contato humano em vez de tentar "resolver" sozinha —
redigido pra nunca soar como se a conversa tivesse consertado o problema
do usuário. A mesma regra foi replicada no `SYSTEM_PROMPT` real do
backend, na ação `responder` (é lá que "converse comigo"/"conte uma
história"/etc. já caem hoje, não existe uma ação dedicada de "modo
companhia" no enum).

Reparei um risco real ao escrever essa regra: um dos exemplos do prompt
mestre é "Molly, quero falar com minha filha" — sem nenhuma ação de
ligar/mensagear família implementada ainda (isso é a TAREFA 20), a IA
poderia responder algo como "Vou ligar para ela agora!" sem que nada de
fato aconteça, confundindo o usuário. Adicionei uma proteção explícita no
`SYSTEM_PROMPT` contra isso: nunca dizer que vai ligar, mandar mensagem
ou avisar alguém — só conversar e, se fizer sentido, sugerir que o
próprio usuário entre em contato.

Criado também `MollyIntentHints.pareceBuscarCompanhia()` em
`molly_intent.dart` — mesmo padrão de sinal local determinístico e
testável da TAREFA 14 (`pareceCriarLembrete`), reconhecendo as cinco
frases de exemplo do prompt mestre e variações próximas via
palavras-gatilho. Mesma disciplina de honestidade: documentado como não
ligado a nenhuma decisão real ainda — é infraestrutura pronta pra quando
um controller de conversa existir.

`test/molly_intent_test.dart` ampliado com 3 testes novos (as cinco
frases literais, maiúsculas/acentuação, não-correspondência com outras
intenções). `flutter analyze`: zero problemas. `flutter test`: suíte
cresceu de 50 para 53 testes passando, mesmos 6 falhando pré-existentes.
Mudança no `SYSTEM_PROMPT` implantada em produção nesta mesma sessão, com
autorização do usuário — `scp` + `systemctl restart
melembra-ai-backend`, `healthz` OK interno e externo, arquivo remoto
conferido idêntico ao local por `diff`.

**TAREFA 16 (preparação da wake word "Molly")**: a tarefa pedia
explicitamente pesquisa de integração com o Picovoice Porcupine antes de
qualquer código. Achados registrados por extenso em
`lib/features/molly/services/wake_word_service.dart`:

1. **"Molly" não é uma palavra-chave pronta** — as gratuitas do
   Porcupine são um conjunto fixo em inglês ("Porcupine", "Bumblebee",
   "Computer", "Jarvis", "Hey Google" etc.). Precisaria treinar uma
   palavra CUSTOM no Picovoice Console, gerando um `.ppn` por plataforma
   pra empacotar como asset — exige criar uma conta, não é só adicionar
   um pacote.
2. **`AccessKey` própria** necessária, a guardar com o mesmo cuidado da
   `GROQ_API_KEY`.
3. **Impacto de bateria real** — escuta contínua com uma rede neural
   leve rodando por cima. Manter isso funcionando em segundo plano (o
   caso de uso de verdade de uma wake word) exigiria um Foreground
   Service dedicado, exatamente a mesma lição já aprendida na sessão 22
   com o detector de queda (`SosProtectionService.kt` + `FlutterEngine`
   headless) — sem isso, o Android mata o microfone assim que o app sai
   de primeiro plano.
4. **Indicador de microfone sempre visível** no Android 12+/iOS — um app
   "sempre ouvindo" deixaria esse indicador permanentemente aceso, o que
   pode preocupar um usuário idoso mesmo sendo esperado.
5. **Licenciamento**: tier gratuito existe (uso pessoal/poucos
   dispositivos); uso comercial em escala pede licença paga.

Seguindo a orientação explícita da própria tarefa ("não integrar
imediatamente no núcleo se houver impacto significativo de bateria"), a
entrega ficou só na abstração: `WakeWordService` (estado
idle/listening/detected/unavailable/error via `ValueNotifier`,
`iniciar`/`parar`/`dispose`) + `UnavailableWakeWordService` (única
implementação existente, sempre reporta indisponível) +
`SettingsService.getWakeWordEnabled()`/`setWakeWordEnabled()`
(`cfg_wake_word_enabled`, padrão `false`) — exatamente como a tarefa
pediu ("implementar primeiro como feature flag").
`WakeWordService.criar()` já lê essa flag, mas devolve a implementação
indisponível de qualquer forma hoje — nada no projeto ganhou uma
dependência nativa nova: `pubspec.yaml` não tem `porcupine_flutter` nem
`picovoice_flutter`, não existe `AccessKey` nem modelo `.ppn` em lugar
nenhum. A implementação real fica bloqueada até o usuário decidir criar
a conta Picovoice e treinar a palavra "Molly", mais uma avaliação de
bateria em campo no aparelho físico de referência.

Criado `test/wake_word_service_test.dart` com 4 testes 100% puro Dart:
o stub começa e permanece indisponível, nunca reporta sucesso ao
iniciar nem dispara o callback de detecção; `parar()` não lança mesmo
sem nunca ter iniciado; e `WakeWordService.criar()` sempre devolve a
implementação indisponível, com a flag ligada ou desligada. `flutter
analyze`: zero problemas. `flutter test`: suíte cresceu de 53 para 57
testes passando, mesmos 6 falhando pré-existentes. Sem mudança no
backend nesta tarefa — nada pra implantar na VPS.

**TAREFA 17 (modo offline)**: diferente das três anteriores — onde
construí infraestrutura (sinais de intenção, abstração de wake word)
deliberadamente ainda não ligada a nada, documentando isso com
transparência — esta tarefa entrou de fato no pipeline real. Criado
`lib/features/molly/services/offline_intent_service.dart`
(`OfflineIntentService`), reconhecendo localmente os cinco comandos
críticos do exemplo do prompt mestre:

- **"Molly, socorro."** → `SosService.trigger(motivo: 'voz')` direto.
  Segunda camada de segurança: o caminho principal continua sendo a
  checagem ao vivo durante a escuta (`aoOuvirParcial` em
  `molly_screen.dart`), mais rápida porque não espera o resultado final
  do STT. Esta aqui cobre qualquer chamador que não faça aquela checagem
  (texto digitado, um controller futuro diferente).
- **"Molly, meus lembretes."** → `getTodayReminders` via
  `MollyRiskPolicy` (LOW, roda direto).
- **"Molly, ligar para Ana."** → extrai o nome com uma regex ancorada no
  início da frase (depois de tirar um "Molly," inicial) e vai por
  `callFamilyMember`, que é CRITICAL — sempre pede confirmação. A regex
  tem uma guarda explícita contra dígito/"hora"/"amanh"/"lembr" no nome
  extraído, pra não atropelar um lembrete disfarçado de ligação (ex.:
  "não deixa eu esquecer de ligar pro médico às 8" é lembrete, não
  chamada — testado explicitamente).
- **"Molly, que horas são?"** → resposta 100% local, sem nenhum serviço,
  só `DateTime.now()` + `horaFalada()`.
- **"Molly, confirmar remédio."** → busca o(s) remédio(s) de hoje ainda
  não confirmados; com exatamente um candidato, confirma direto; com
  mais de um, passa `ambiguo: true` pro `confirmReminder` — o **primeiro
  uso real** do parâmetro `ambiguo` da TAREFA 4, que desde então só
  existia testado isoladamente, sem nenhum chamador de verdade.

Arquitetura: `classificar()` (a detecção em si, o que a tarefa realmente
pede) é pura — nenhuma chamada a Firebase, IA ou serviço, só string
matching — separada de propósito de `tentar()` (que executa de fato).
Isso significa que os cinco reconhecimentos são 100% testáveis sem
esbarrar no problema de `FirebaseAuth` documentado na Tarefa 10, mesmo
que a EXECUÇÃO de quatro dos cinco comandos toque Firebase por trás.

A integração real: `MollyAgentService.processar()` agora chama
`OfflineIntentService.tentar()` **antes** de qualquer chamada à IA — é
literalmente o fluxo desenhado no prompt mestre ("entrada → detecção
local → reconhecida? → sim: executa local / não: envia pra IA"), e
também prepara o terreno pra TAREFA 31 (otimização de custos, que pede
exatamente este mesmo fluxo). Consequência prática: esses cinco comandos
agora funcionam mesmo que a Groq esteja fora do catálogo de novo (já
aconteceu duas vezes, sessões 19 e 21) ou sem internet — o que a tarefa
pedia explicitamente ("esses comandos não devem depender de LLM").

Criado `test/offline_intent_service_test.dart` com 10 testes: os cinco
comandos literais da tarefa; SOCORRO em qualquer caixa e dentro de frase
maior; variações de "ligar para"; os dois falsos-positivos evitados
deliberadamente (lembrete disfarçado de ligação); variações de "meus
lembretes"/"que horas"/"confirmar remédio"; frases de outras intenções
não reconhecidas; e dois testes de `tentar()` em si (o caminho 100%
local de "que horas", e uma frase não reconhecida devolvendo `null`).
`flutter analyze`: zero problemas. `flutter test`: suíte cresceu de 57
para 67 testes passando, mesmos 6 falhando pré-existentes. Sem mudança
no backend — nada pra implantar na VPS.

**TAREFA 18 (SOS por voz)**: ampliação direta da TAREFA 17. Adicionado
`OfflineIntent.possivelEmergencia` em `offline_intent_service.dart`,
reconhecendo as cinco frases mais suaves do exemplo do prompt mestre —
"me ajuda", "chama minha filha", "chama alguém", "estou passando mal",
"preciso de ajuda" — deliberadamente tratadas DIFERENTE de "SOCORRO": a
checagem de "SOCORRO" continua rodando primeiro em `classificar()`
(prioridade sobre as frases suaves quando aparecem juntas, testado
explicitamente) e continua disparando o SOS na hora, sem nenhuma etapa a
mais; as cinco frases novas nunca disparam sozinhas.

Para representar essa diferença, `MollyToolResult` ganhou
`precisaConfirmacaoDeEmergencia` — um campo NOVO, deliberadamente
separado de `precisaConfirmacao` (TAREFA 4): são duas modalidades de
confirmação diferentes por natureza, uma é contagem regressiva visual
com botão "Cancelar" (o que esta tarefa pede), a outra é um "sim"/"não"
falado (o que o portão de risco genérico usa) — misturar os dois sob a
mesma flag faria `molly_screen.dart` mostrar o diálogo errado.

`molly_screen.dart` ganhou `_confirmarPossivelEmergencia()`, reproduzindo
o diálogo exato do exemplo do prompt mestre — título "Parece que você
precisa de ajuda.", corpo "Vou acionar seu contato de emergência." com o
número regressivo, botão "Cancelar" — usando o mesmo padrão de
`Timer.periodic` + `StatefulBuilder` que `elderly_screen.dart` já usa
pro countdown do botão SOS manual (TASK-25). Não toquei em
`elderly_screen.dart` pra reaproveitar o código de lá (fora do escopo
desta sessão, mesma disciplina de todas as tarefas anteriores) — escrevi
uma versão nova e mais simples aqui, sem o diálogo de discagem manual
multi-contato que a tela antiga tem (não pedido explicitamente por esta
tarefa). A duração da contagem virou configurável de verdade
(`SettingsService.getSosCountdownSegundos`/`setSosCountdownSegundos`,
padrão 5s) — exatamente o que a tarefa pediu ("contagem curta
configurável"), mesmo sem tela ainda pra mudar o valor (TAREFA 24). O
disparo técnico em si nunca sai de `SosService.trigger()` — a detecção é
100% local, a IA nunca é consultada nem decide nada nesse caminho.

**Achado registrado com transparência, não escondido**: a detecção hoje
é só `.contains()` nas cinco frases — então algo como "ontem eu estava
passando mal, mas já melhorei" dispararia o mesmo diálogo de emergência
por engano, porque não distingue passado de presente. Esse é exatamente
o problema que a TAREFA 19 (Prevenção de Falsos Positivos) existe pra
resolver, com o mesmo exemplo ("ontem eu falei que estava passando mal"
não deve disparar SOS) — documentado como lacuna conhecida em
`docs/CURRENT_STATE.md`, não corrigido nesta tarefa de propósito, pra
não me adiantar ao escopo da próxima.

`test/offline_intent_service_test.dart` ampliado com 3 testes: as cinco
frases suaves reconhecidas; SOCORRO com prioridade quando aparece junto
com uma frase suave; e `tentar()` montando a confirmação de emergência
sem tocar Firebase (o resultado é construído por uma factory pura,
`MollyToolResult.possivelEmergencia`, sem nenhum await real nesse
branch). `flutter analyze`: zero problemas. `flutter test`: suíte
cresceu de 67 para 70 testes passando, mesmos 6 falhando
pré-existentes. Sem mudança no backend — nada pra implantar na VPS.

---

## Regra de ouro para este projeto

> NUNCA escrever emojis diretamente em arquivos .dart via PowerShell.
> SEMPRE usar Python com escape unicode \UXXXXXXXX.
> SEMPRE usar python removebom.py apos escrita via PowerShell.

