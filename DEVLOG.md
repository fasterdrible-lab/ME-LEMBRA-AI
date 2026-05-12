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
- [ ] Publicar na Play Store

---

## Regra de ouro para este projeto

> NUNCA escrever emojis diretamente em arquivos .dart via PowerShell.
> SEMPRE usar Python com escape unicode \UXXXXXXXX.
> SEMPRE usar python removebom.py apos escrita via PowerShell.

