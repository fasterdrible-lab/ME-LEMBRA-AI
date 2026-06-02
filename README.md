# Me Lembra Ai

> Aplicativo Flutter de lembretes acessivel para familias — versao 1.3.0

---

## O que e

App de lembretes inteligente com quatro perfis independentes:

| Perfil | Publico | Destaques |
|---|---|---|
| Vovo / Vova | Idosos | Botoes grandes, TTS/STT, SOS completo, mapa, detector de queda |
| Adulto | Adultos | Dashboard, sugestoes inteligentes |
| Filhos | Criancas | Tarefas gamificadas com barra de progresso |
| Familia | Cuidadores | Feed SOS, chat familiar com audio, monitoramento |

---

## Como rodar (desenvolvimento)

```powershell
flutter pub get
flutter run -d R9QL200MJ0N
```

## Como buildar (release)

```powershell
# Copiar para fora do OneDrive (obrigatorio — OneDrive bloqueia o Gradle)
Copy-Item -Recurse -Force "C:\Users\phpos\OneDrive\MeLembraAI\*" "C:\MeLembraAI\"
Set-Location "C:\MeLembraAI"
flutter pub get
flutter build apk --release
```

APK gerado em: `build\app\outputs\flutter-apk\app-release.apk`

Copiar para a pasta de versoes:

```powershell
Copy-Item "C:\MeLembraAI\build\app\outputs\flutter-apk\app-release.apk" `
  "C:\Users\phpos\OneDrive\Área de Trabalho\VERSOES\me-lembra-ai-vX.X.X.apk" -Force
```

---

## Stack

| Camada | Tecnologia |
|---|---|
| UI | Flutter / Dart (SDK >= 3.0) |
| Auth | Firebase Auth |
| Banco | Cloud Firestore |
| Push | Firebase Cloud Messaging |
| Notif local | flutter_local_notifications |
| Armazenamento | Firebase Storage (audios) |
| Localizacao | geolocator + google_maps_flutter |
| Voz | flutter_tts + speech_to_text |
| Audio chat | record + audioplayers |
| Backend SOS | Python (sos_notifier.py) no VPS Hetzner |

---

## Funcionalidades implementadas

- Login / Cadastro / Recuperacao de senha
- Onboarding no primeiro acesso
- 4 perfis com navegacao dedicada
- CRUD de lembretes (Firestore)
- Notificacoes locais agendadas (unica, diaria, semanal)
- Briefing matinal por voz (8h)
- Criacao de lembretes por voz (idoso)
- Detector de queda (acelerometro)
- Botao SOS — pipeline completo:
  - Registro no Firestore
  - Mensagem de chat para cuidadores
  - Ligacao automatica para numero SOS cadastrado
  - Notificacao critica fullScreen no familiar
  - Push FCM via VPS quando app fechado
  - Foreground Service "Modo protecao ativo"
  - SOS por 5x tecla de volume (app em foreground)
- Chat familiar com texto e audio (segurar para gravar)
- Tela de mapa com posicao atual e botao SOS
- Widget Android de lembretes do dia
- Historico de confirmacoes
- Modo escuro
- Testes de widget automatizados

---

## Configuracao necessaria apos clonar

1. Baixar `google-services.json` do Firebase Console e colocar em `android/app/`
2. Substituir `YOUR_GOOGLE_MAPS_API_KEY` no `android/app/src/main/AndroidManifest.xml`
3. Para o push SOS via VPS: colocar `serviceAccountKey.json` em `/root/sos_notifier/` no servidor

---

## Documentacao tecnica

| Arquivo | Conteudo |
|---|---|
| `docs/CURRENT_STATE.md` | Estado atual, funcionalidades, build, deploy |
| `docs/ARCHITECTURE.md` | Arquitetura, fluxos, Firestore, channels, canais de notificacao |
| `docs/TASKS.md` | Backlog completo (concluidas e pendentes) |
| `DEVLOG.md` | Historico de decisoes tecnicas e bugs resolvidos |

---

## Regra de ouro para este projeto

> NUNCA escrever emojis diretamente em arquivos .dart via PowerShell.
> SEMPRE usar Python com escape unicode \UXXXXXXXX.
> SEMPRE buildar em C:\MeLembraAI (fora do OneDrive).

---

## Cores do tema

| Uso | Hex |
|---|---|
| Primaria (roxo) | #7B5EA7 |
| Secundaria (azul) | #4A90D9 |
| Fundo | #F2F2F7 |
| Perigo (SOS) | #E53935 |
| Verde | #50C878 |
| Laranja | #FF8C00 |

---

Copyright © 2026 HEXAGON TECNOLOGIA. Todos os direitos reservados.
