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

## Regra de ouro para este projeto

> NUNCA escrever emojis diretamente em arquivos .dart via PowerShell.
> SEMPRE usar Python com escape unicode \UXXXXXXXX.
> SEMPRE usar python removebom.py apos escrita via PowerShell.

