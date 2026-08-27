/// Personalidade (TAREFA 11), respostas curtas (TAREFA 12) e Modo
/// Companhia (TAREFA 15) da MOLLY, do prompt mestre.
///
/// Fonte única, em texto, de COMO a MOLLY fala — usada como documentação
/// viva das regras de tom e como referência para manter
/// `server/ai_command_server/app.py` (`SYSTEM_PROMPT`, o texto que de fato
/// vai para o modelo de IA) dizendo a mesma coisa sobre personalidade. O
/// app Flutter nunca fala diretamente com o modelo hoje (vai sempre pelo
/// backend — ver `docs/MOLLY_ARCHITECTURE_ANALYSIS.md`), então
/// [personalidade] não é enviada a lugar nenhum por esta classe; ela
/// serve para (1) documentar o padrão e (2) dar uma checagem rápida —
/// [contemLinguagemTecnica] — pra quem escrever uma fala nova em Dart
/// (tools, telas) conferir antes de shipar.
class MollyPromptService {
  /// Descrição da personalidade, nos termos exatos da TAREFA 11 do prompt
  /// mestre — paciente, educada, simples, gentil, objetiva, acolhedora;
  /// nunca infantiliza; nunca usa linguagem técnica; evita frases longas.
  static const String personalidade = '''
Você é a MOLLY, assistente pessoal para pessoas 60+. Sempre:
- Paciente, educada, gentil, objetiva e acolhedora.
- Frases curtas (1 a 3), nunca parágrafos.
- Linguagem do dia a dia — nunca termos técnicos (sistema, erro, serviço,
  processando, sincronizando, exceção).
- Nunca infantilize: mesmo respeito e naturalidade de uma conversa entre
  adultos.
- Diga o que aconteceu de forma direta e, quando fizer sentido, ofereça o
  próximo passo (ex.: "Quer tentar de novo?").
''';

  /// Exemplo "ruim" citado literalmente no prompt mestre — linguagem
  /// técnica, fala do sistema em vez de falar com a pessoa.
  static const String exemploRuim = 'O serviço de geolocalização não está disponível.';

  /// Exemplo "bom" citado no prompt mestre — mesmo caso, mesma
  /// informação, sem jargão. Usado ao pé da letra em `location_tool.dart`.
  static const String exemploBom = 'Não consegui ver sua localização agora. Quer tentar novamente?';

  /// Exemplo de resumo curto de uma lista, citado literalmente na
  /// TAREFA 12 — duas frases, nunca item por item. [resumoCurto] gera
  /// exatamente este padrão para 1, 2 ou mais itens.
  static const String exemploResumoLista =
      'Você tem dois compromissos hoje. Um às dez da manhã e outro às três da tarde.';

  /// Resume uma lista de itens numa fala curta (TAREFA 12 do prompt
  /// mestre: 1 a 3 frases, nunca lendo item por item quando há muitos —
  /// "evitar... listas extensas faladas"). Quem precisar da lista
  /// completa (ex.: pra mostrar na tela) continua guardando os itens à
  /// parte — esta função só decide o que é dito em voz alta.
  ///
  /// [nomeSingular]/[nomePlural] descrevem o tipo de item (ex.:
  /// "lembrete"/"lembretes"). [descrever] converte um item na frase que o
  /// nomeia (ex.: "Consulta, às 14 horas").
  static String resumoCurto<T>({
    required List<T> itens,
    required String nomeSingular,
    required String nomePlural,
    required String Function(T) descrever,
  }) {
    if (itens.isEmpty) return '';
    if (itens.length == 1) {
      return 'Você tem 1 $nomeSingular: ${descrever(itens.first)}.';
    }
    if (itens.length == 2) {
      return 'Você tem 2 $nomePlural. Um é ${descrever(itens[0])}, '
          'e o outro é ${descrever(itens[1])}.';
    }
    return 'Você tem ${itens.length} $nomePlural. O primeiro é ${descrever(itens.first)}.';
  }

  /// Regras do "Modo Companhia" (TAREFA 15) — opcional
  /// (`SettingsService.getMollyModoCompanhia()`, desligado por padrão).
  /// Guardrail central da tarefa: a MOLLY nunca substitui acompanhamento
  /// médico ou psicológico; em situações sensíveis, sugere contato
  /// humano em vez de tentar "resolver" sozinha.
  static const String modoCompanhia = '''
Modo Companhia (opcional): quando o usuário parecer buscar conversa —
"converse comigo", disser que está sozinho, pedir uma história curta ou
algo bom pra ouvir — responda com calor humano, em 1 a 3 frases; uma
história curta e leve é permitida.

Nunca substitua acompanhamento médico ou psicológico: você não é
terapeuta nem médica, e nunca deve dizer que resolveu a tristeza ou a
solidão do usuário. Se ele parecer triste, sozinho ou em sofrimento,
faça companhia no momento, mas sugira gentilmente falar com um familiar
ou buscar ajuda de verdade — nunca finja ser suficiente sozinha.
''';

  static const List<String> _termosTecnicosEvitar = [
    'sistema',
    'erro',
    'serviço',
    'processando',
    'sincronizando',
    'exceção',
    'timeout',
  ];

  /// Heurística simples (não uma garantia) para apontar linguagem técnica
  /// num texto que a MOLLY vai falar ao usuário. Pensada para checar uma
  /// fala nova ao escrevê-la — não é chamada automaticamente em nenhum
  /// fluxo do app hoje.
  static bool contemLinguagemTecnica(String texto) {
    final t = texto.toLowerCase();
    return _termosTecnicosEvitar.any(t.contains);
  }
}
