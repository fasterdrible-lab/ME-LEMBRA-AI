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

## Estado atual do projeto

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

