# Me Lembra Ai

> Aplicativo Flutter de lembretes acessivel, voltado para idosos, adultos e criancas.

---

## Descricao

O **Me Lembra Ai** e um app de lembretes inteligente com interface amigavel.
Permite criar lembretes por categoria, com horario, recorrencia e alertas.

---

## Perfis disponiveis

| Perfil | Descricao |
|---|---|
| Vovo / Vova | Interface acessivel com alertas por voz e SOS |
| Adulto | Lembretes inteligentes e agenda integrada |
| Crianca | Monitorado por responsavel |

---

## Estrutura do projeto

`
me_lembra_ai/
  lib/
    main.dart                    # Ponto de entrada
    home_screen.dart             # Tela principal com lista de lembretes
    profile_selection_screen.dart # Selecao de perfil inicial
    create_reminder_screen.dart  # Tela de criacao de lembrete
    reminders_screen.dart        # Lista completa de lembretes
    categories_screen.dart       # Tela de categorias
    config_screen.dart           # Tela de configuracoes
    services/
      profile_service.dart       # Servico de perfil (SharedPreferences)
  assets/
    images/
      avos.png
      adultos.png
      crianca.png
  pubspec.yaml
`

---

## Formato dos lembretes (SharedPreferences)

Os lembretes sao salvos como strings no formato pipe-separated:

`
tipo|titulo|descricao|recorrencia|hora
`

**Exemplo:**
`
Remedio|Losartana 50mg|Todos os dias|diario|10:00
Consulta|Dr. Carlos|Cardiologista|unico|14:30
Aniversario|Ju|Lembrar de ligar|unico|
Mercado|Mercado|Lista com 8 itens|unico|
Reuniao|Reuniao de Sprint|Segunda - 09:00|semanal|09:00
Tomar|Tomar agua|A cada 2 horas|recorrente|12:00
`

---

## Categorias e icones

| Categoria | Emoji | Cor de fundo |
|---|---|---|
| Remedio | 💊 | #FFEEEE |
| Consulta | 🩺 | #EEF4FF |
| Aniversario | 🎂 | #FFF3E0 |
| Mercado | 🛒 | #E8F5E9 |
| Reuniao | 🤝 | #EDE7F6 |
| Tomar | 💧 | #E3F2FD |
| Padrao | 🔔 | #F2F2F7 |

---

## Como rodar

`ash
flutter pub get
flutter run -d SEU_DEVICE_ID
`

**Dispositivo de desenvolvimento:**
- Samsung Galaxy A07 (SM A075M) — ID: R9QL200MJ0N

---

## Dependencias principais

`yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.x.x
`

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

## Problemas conhecidos e solucoes

### Encoding de emojis no Windows
**Problema:** PowerShell salva arquivos com BOM ou encoding errado,
corrompendo emojis e caracteres especiais no Dart.

**Solucao:** Sempre usar Python para escrever arquivos .dart:
`python
with open('lib/arquivo.dart', 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
`

**Emojis:** Sempre usar escape unicode Python (\U0001F48A) ao injetar
emojis em strings Dart via script Python.

---

## Notas de desenvolvimento

- O PowerShell no Windows nao suporta -Encoding utf8NoBOM em versoes antigas.
- Usar python removebom.py apos qualquer escrita via PowerShell.
- O db nao esta no PATH — usar lutter run --uninstall-first para reinstalar.

