/// Extração local e determinística de dia/hora/título/tipo/recorrência
/// para a coleta de lembrete por voz da MOLLY.
///
/// Porta (sem reescrever) `_extrairData`/`_extrairHora`/`_extrairHoraDeResposta`/
/// `_limparTitulo`/`_inferirTipo`/`_inferirRecorrencia`, hoje só em
/// `elderly_screen.dart` — extraídos para cá pra `molly_screen.dart`
/// (TAREFA 6) poder terminar de verdade um pedido de lembrete que a IA
/// devolveu como `perguntar` (dado incompleto), em vez de ficar presa
/// perguntando de novo à IA a cada turno.
///
/// Sessão 26: [interpretarPedido] reconhece o pedido inteiro ("me lembra do
/// remédio às oito") sem IA — funciona sem internet e não gasta token. Só
/// aceita o que entende com segurança; o resto continua indo para a IA.
///
/// 100% puro/testável: nenhuma dependência de Firebase, `speech_to_text`
/// ou `flutter_tts`.
class MollyReminderParser {
  /// Extrai hora (e minuto, se houver) de uma resposta curta a uma
  /// pergunta sobre horário (ex.: "15", "15h30", "3 da tarde", "9h",
  /// "oito e meia"). Retorna null se não parecer uma resposta de horário.
  static ({int hora, int minuto})? extrairHoraDeResposta(String texto) {
    final lower = horasPorExtensoEmDigitos(texto.toLowerCase().trim());
    final match = RegExp(r'^(\d{1,2})\s*(?:[h:]\s*(\d{1,2}))?').firstMatch(lower);
    if (match == null) return null;
    final hora = int.parse(match.group(1)!);
    final minuto = int.parse(match.group(2) ?? '0');
    if (hora > 23 || minuto > 59) return null;
    return (hora: _ajustarPeriodo(hora, lower), minuto: minuto);
  }

  /// Extrai dia/mês/ano de uma frase, ou null se não achar nada — null
  /// significa "ainda não sei", pra poder perguntar em vez de adivinhar
  /// (diferente de um parser que sempre assume "hoje" quando não reconhece
  /// nada).
  static ({int dia, int mes, int ano})? extrairData(String texto, {DateTime? agora}) {
    final hoje = agora ?? DateTime.now();
    final lower = texto.toLowerCase();
    ({int dia, int mes, int ano}) daqui(int dias) {
      final d = DateTime(hoje.year, hoje.month, hoje.day + dias);
      return (dia: d.day, mes: d.month, ano: d.year);
    }

    const meses = {
      'janeiro': 1, 'fevereiro': 2, 'março': 3, 'marco': 3,
      'abril': 4, 'maio': 5, 'junho': 6, 'julho': 7,
      'agosto': 8, 'setembro': 9, 'outubro': 10,
      'novembro': 11, 'dezembro': 12,
    };
    // Antes de "amanhã": "depois de amanhã" também contém "amanhã".
    if (lower.contains('depois de amanhã') || lower.contains('depois de amanha')) return daqui(2);
    if (lower.contains('amanhã') || lower.contains('amanha')) return daqui(1);
    if (lower.contains('hoje')) return daqui(0);
    for (final entry in meses.entries) {
      final re = RegExp(r'(\d{1,2})\s+de\s+' + entry.key);
      final match = re.firstMatch(lower);
      if (match != null) {
        return (dia: int.parse(match.group(1)!), mes: entry.value, ano: hoje.year);
      }
    }

    // "na segunda", "quinta-feira", "toda sexta": a próxima. "da segunda
    // dose" não (sem na/no/toda/próxima nem "-feira" não é dia da semana).
    final semana = _diaDaSemana.firstMatch(lower);
    if (semana != null) {
      final nome = (semana.group(1) ?? semana.group(2))!;
      final alvo = _numeroDoDiaDaSemana(nome);
      var dias = (alvo - hoje.weekday) % 7;
      if (dias == 0) dias = 7; // "na segunda" dito na segunda = a próxima
      return daqui(dias);
    }

    // "dia 15" sem mês: este mês, ou o próximo se o dia já passou.
    final soDia = RegExp(r'\bdia\s+(\d{1,2})\b').firstMatch(lower);
    if (soDia != null) {
      final n = int.parse(soDia.group(1)!);
      if (n < 1 || n > 31) return null;
      var d = DateTime(hoje.year, hoje.month, n);
      if (n < hoje.day) d = DateTime(hoje.year, hoje.month + 1, n);
      if (d.day != n) return null; // 31 num mês de 30 dias
      return (dia: d.day, mes: d.month, ano: d.year);
    }
    return null;
  }

  /// Extrai hora/minuto de uma frase completa ("às 15h30", "às oito e
  /// meia") ou de uma resposta curta ("15"). Null se não achar nada —
  /// mesmo espírito de [extrairData].
  static ({int hora, int minuto})? extrairHora(String texto) {
    final lower = horasPorExtensoEmDigitos(texto.toLowerCase());

    final reMeioDia = RegExp(r'(?:ao\s+)?meio[- ]dia(?:\s+e\s+(\d{1,2}))?', caseSensitive: false);
    final mMeioDia = reMeioDia.firstMatch(lower);
    if (mMeioDia != null) {
      return (hora: 12, minuto: int.parse(mMeioDia.group(1) ?? '0'));
    }
    if (lower.contains('meia-noite') || lower.contains('meia noite')) {
      final mMN = RegExp(r'meia[- ]noite\s+e\s+(\d{1,2})', caseSensitive: false).firstMatch(lower);
      return (hora: 0, minuto: mMN != null ? int.parse(mMN.group(1)!) : 0);
    }

    final reHora = RegExp(
      r'[àa]s?\s+(\d{1,2})'
      r'(?:\s*[h:]\s*(\d{1,2})'
      r'|\s+e\s+(\d{1,2})'
      r'|\s+horas?\s+e\s+(\d{1,2}))?',
    );
    final mHora = reHora.firstMatch(lower);
    if (mHora != null) {
      final hora = int.parse(mHora.group(1)!);
      final min = mHora.group(2) ?? mHora.group(3) ?? mHora.group(4);
      final minuto = int.parse(min ?? '0');
      if (hora > 23 || minuto > 59) return null;
      return (hora: _ajustarPeriodo(hora, lower), minuto: minuto);
    }

    return extrairHoraDeResposta(texto);
  }

  /// Remove o pedido ("me lembra de") e os trechos de data/hora, deixando
  /// só o título (ex.: "me lembra da consulta com o dentista às 15h" →
  /// "consulta com o dentista").
  static String limparTitulo(String texto) {
    var semPedido = texto.trim().replaceFirst(_gatilhoLembrete, '').trim();
    if (semPedido.length != texto.trim().length) {
      // "não deixa eu esquecer o remédio" → "remédio", não "o remédio".
      semPedido = semPedido.replaceFirst(RegExp(r'^(o|a|os|as)\s+(?![\d])', caseSensitive: false), '');
    }
    // Espaço na frente: um trecho de data/hora logo no começo também corta.
    semPedido = ' $semPedido';
    // (?!\p{L}) em vez de \b: o \b do Dart não funciona depois de letra
    // acentuada ("amanhã" no fim da frase não era cortado).
    const fim = r'(?!\p{L})';
    final patterns = [
      RegExp(r'\s+no\s+dia' + fim, caseSensitive: false, unicode: true),
      RegExp(r'\s+dia\s+\d', caseSensitive: false),
      RegExp(r'\s+depois\s+de\s+amanh', caseSensitive: false),
      RegExp(r'\s+amanhã' + fim, caseSensitive: false, unicode: true),
      RegExp(r'\s+amanha' + fim, caseSensitive: false, unicode: true),
      RegExp(r'\s+hoje' + fim, caseSensitive: false, unicode: true),
      RegExp(r'\s+daqui' + fim, caseSensitive: false, unicode: true),
      // Só com horário logo depois: "ligar para a Ana"/"buscar as
      // crianças" não podem virar "ligar"/"buscar".
      RegExp(r'\s+(?:para\s+)?[àa]s?\s+' + _numeroDeHora, caseSensitive: false, unicode: true),
      RegExp(r'\s+de\s+manhã' + fim, caseSensitive: false, unicode: true),
      RegExp(r'\s+à\s+(tarde|noite|manhã)' + fim, caseSensitive: false, unicode: true),
      RegExp(r'\s+ao\s+meio' + fim, caseSensitive: false, unicode: true),
      RegExp(r'\s+meio[- ]dia' + fim, caseSensitive: false, unicode: true),
      RegExp(r'\s+meia[- ]noite' + fim, caseSensitive: false, unicode: true),
      RegExp(r'\s+tod[oa]s?\s+(os\s+|as\s+)?(dias?|semanas?|manhãs?|noites?)' + fim, caseSensitive: false, unicode: true),
      RegExp(r'\s+(na|no|nesta|neste|nessa|nesse|toda|todo|pr[óo]xim[ao])\s+'
          r'(segunda|ter[çc]a|quarta|quinta|sexta|s[áa]bado|domingo)', caseSensitive: false),
      RegExp(r'\s+(segunda|ter[çc]a|quarta|quinta|sexta)[- ]feira', caseSensitive: false),
    ];
    int cutAt = semPedido.length;
    for (final re in patterns) {
      final m = re.firstMatch(semPedido);
      if (m != null && m.start < cutAt) cutAt = m.start;
    }
    final result = semPedido.substring(0, cutAt).trim();
    return result.isNotEmpty ? result : texto.trim();
  }

  /// Infere recorrência a partir do texto ("todo dia", "toda semana", etc.).
  static String inferirRecorrencia(String texto) {
    final t = texto.toLowerCase();
    if (t.contains('todo dia') ||
        t.contains('todos os dias') ||
        t.contains('diariamente') ||
        t.contains('toda manha') ||
        t.contains('toda manhã') ||
        t.contains('todo manha') ||
        t.contains('todo manhã')) {
      return 'diario';
    }
    if (t.contains('toda semana') ||
        t.contains('todo semana') ||
        t.contains('semanalmente') ||
        t.contains('toda segunda') ||
        t.contains('toda terça') ||
        t.contains('toda quarta') ||
        t.contains('toda quinta') ||
        t.contains('toda sexta') ||
        t.contains('todo sábado') ||
        t.contains('todo domingo')) {
      return 'semanal';
    }
    return 'unico';
  }

  /// Infere o tipo (categoria) a partir do texto.
  static String inferirTipo(String texto) {
    final t = texto.toLowerCase();
    // "tomar água" é categoria própria ("Tomar") — checar antes do "tomar"
    // genérico abaixo, que por padrão vira remédio.
    if (t.contains('água') || t.contains('agua')) return 'Tomar';
    if (t.contains('remédio') ||
        t.contains('remedio') ||
        t.contains('medicamento') ||
        t.contains('comprimido') ||
        t.contains('pílula') ||
        t.contains('pilula') ||
        t.contains('cápsula') ||
        t.contains('capsula') ||
        t.contains('insulina') ||
        _tomarRemedio(t)) {
      return 'Remedio';
    }
    if (t.contains('compra') || t.contains('mercado') || t.contains('supermercado') || t.contains('lista')) {
      return 'Mercado';
    }
    if (t.contains('aniversário') || t.contains('aniversario') || t.contains('niver')) {
      return 'Aniversario';
    }
    if (t.contains('churrasco') ||
        t.contains('festa') ||
        t.contains('evento') ||
        t.contains('reunião') ||
        t.contains('reuniao') ||
        t.contains('família') ||
        t.contains('familia')) {
      return 'Reuniao';
    }
    if (t.contains('consulta') || t.contains('médico') || t.contains('medico') || t.contains('dentista') || t.contains('exame')) {
      return 'Consulta';
    }
    // Nenhuma categoria reconhecida: não assume "Remédio" (lista sensível,
    // usada pra medicação real) — cai em "Lembrete" genérico.
    return 'Lembrete';
  }

  /// "tomar a losartana" é remédio; "tomar banho/café/sol" não — senão
  /// ganharia o aviso "Você conseguiu tomar seu remédio?" (sessão 26).
  static bool _tomarRemedio(String t) {
    final m = RegExp(r'tomar\s+(?:o\s+|a\s+|os\s+|as\s+|um\s+|uma\s+|meu\s+|minha\s+|meus\s+|minhas\s+)?(\p{L}+)',
            unicode: true)
        .firstMatch(t);
    if (m == null) return false;
    return !_naoRemedio.contains(m.group(1));
  }

  static const _naoRemedio = {
    'banho', 'café', 'cafe', 'chá', 'cha', 'sol', 'suco', 'leite', 'sopa', 'lanche', 'ar',
    'ônibus', 'onibus', 'conta', 'cuidado', 'providência', 'providencia', 'decisão', 'decisao',
    'vacina', 'cerveja', 'vinho', 'refrigerante', 'água', 'agua',
  };

  // ── Pedido completo, sem IA (sessão 26) ─────────────────────────────

  /// "me lembra", "não deixa eu esquecer", "coloca um lembrete"... no
  /// começo da frase (depois de um "Molly," opcional), com o "de/do/que"
  /// que costuma vir em seguida.
  static final RegExp _gatilhoLembrete = RegExp(
    r'^(?:molly,?\s*)?(?:'
    r'me\s+lembr(?:a|e|ar)'
    r'|n[ãa]o\s+(?:me\s+)?deix[ae]\s+(?:eu\s+)?esquecer'
    r'|(?:coloca|cria|criar|marca|anota|faz|adiciona|p[õo]e)\s+(?:um\s+)?lembrete'
    r')(?:\s+(?:de|do|da|dos|das|que|pra|para|pro))?(?![\p{L}])',
    caseSensitive: false,
    unicode: true,
  );

  /// O que a IA entende melhor que regras locais — nesses casos o pedido
  /// segue para ela (com internet) em vez de virar um lembrete errado.
  static final List<RegExp> _foraDoLocal = [
    RegExp(r'\bantes\b'),
    RegExp(r'\bdepois\b(?!\s+de\s+amanh)'),
    RegExp(r'\bquando\b'),
    RegExp(r'semana que vem|m[êe]s que vem|ano que vem|fim de semana'),
    RegExp(r'pr[óo]xim[ao]\s+(semana|m[êe]s|ano)'),
    RegExp(r'todo\s+m[êe]s|mensal|todo\s+dia\s+\d|todo\s+ano'),
  ];

  /// Reconhece um pedido de lembrete completo, sem IA. Devolve null quando
  /// a frase não é claramente um pedido de lembrete, não tem do que
  /// lembrar, ou tem algo que só a IA entende bem (ex.: "duas horas antes
  /// da consulta") — nesses casos quem chama segue para a IA.
  ///
  /// `dataHora` null = falta a hora (quem chama pergunta "Que horas?").
  /// Sem data, vale a próxima vez que esse horário chegar (hoje ou amanhã).
  static ({String titulo, String tipo, String recorrencia, DateTime? dataHora})? interpretarPedido(
    String texto, {
    DateTime? agora,
  }) {
    final original = texto.trim();
    final gatilho = _gatilhoLembrete.firstMatch(original);
    if (gatilho == null) return null;
    final lower = original.toLowerCase();
    if (_foraDoLocal.any((re) => re.hasMatch(lower))) return null;

    final titulo = limparTitulo(original);
    final resto = original.substring(gatilho.end).trim();
    // Sem assunto ("me lembra às 8"): a IA pergunta "do quê?".
    if (resto.isEmpty || titulo.toLowerCase() == lower || _soTempo(titulo)) return null;

    final now = agora ?? DateTime.now();
    final tipo = inferirTipo(titulo);
    final recorrencia = inferirRecorrencia(lower);
    final tituloFinal = titulo[0].toUpperCase() + titulo.substring(1);

    final relativo = _daqui(lower);
    if (relativo == _daquiInvalido) return null;
    if (relativo != null) {
      return (titulo: tituloFinal, tipo: tipo, recorrencia: recorrencia, dataHora: now.add(relativo));
    }

    final hora = extrairHora(lower);
    if (hora == null) return (titulo: tituloFinal, tipo: tipo, recorrencia: recorrencia, dataHora: null);

    final data = extrairData(lower, agora: now);
    var dataHora = data == null
        ? DateTime(now.year, now.month, now.day, hora.hora, hora.minuto)
        : DateTime(data.ano, data.mes, data.dia, hora.hora, hora.minuto);
    // Sem data, ou "hoje" num horário que já passou: a próxima vez (amanhã).
    final ehHoje = dataHora.year == now.year && dataHora.month == now.month && dataHora.day == now.day;
    if (ehHoje && dataHora.isBefore(now)) dataHora = dataHora.add(const Duration(days: 1));
    return (titulo: tituloFinal, tipo: tipo, recorrencia: recorrencia, dataHora: dataHora);
  }

  /// "pra oito horas", "às 8 da noite": o "título" é só um horário.
  static bool _soTempo(String titulo) => _palavras(horasPorExtensoEmDigitos(titulo.toLowerCase())).every((w) =>
      RegExp(r'^\d{1,2}(:\d{2}|h\d{0,2})?$').hasMatch(w) ||
      const {
        'às', 'as', 'ao', 'à', 'a', 'para', 'pra', 'pras', 'hora', 'horas', 'e', 'meia', 'da', 'de',
        'manhã', 'manha', 'tarde', 'noite', 'meio-dia', 'meia-noite', 'hoje', 'amanhã', 'amanha',
      }.contains(w));

  static const _daquiInvalido = Duration(microseconds: -1);

  /// "daqui a 20 minutos", "daqui uma hora", "daqui meia hora", "daqui a
  /// duas horas e meia". Null = não falou "daqui"; [_daquiInvalido] =
  /// falou mas não deu pra entender (segue para a IA).
  static Duration? _daqui(String lower) {
    final p = _palavras(lower);
    final i = p.indexOf('daqui');
    if (i == -1) return null;
    var j = i + 1;
    if (j < p.length && (p[j] == 'a' || p[j] == 'há' || p[j] == 'ha')) j++;
    if (j + 1 < p.length && p[j] == 'meia' && p[j + 1].startsWith('hora')) {
      return const Duration(minutes: 30);
    }
    final n = _lerNumero(p, j);
    if (n == null || n.$2 >= p.length) return _daquiInvalido;
    final unidade = p[n.$2];
    if (unidade.startsWith('minuto') && n.$1 >= 1 && n.$1 <= 600) return Duration(minutes: n.$1);
    if (unidade.startsWith('hora') && n.$1 >= 1 && n.$1 <= 24) {
      var d = Duration(hours: n.$1);
      final k = n.$2 + 1;
      if (k + 1 < p.length && p[k] == 'e' && p[k + 1] == 'meia') d += const Duration(minutes: 30);
      return d;
    }
    return _daquiInvalido;
  }

  // ── Números por extenso ("às oito e meia" → "às 8:30") ──────────────

  static const _numeroDeHora =
      r'(?:\d|(?:uma|duas|dois|tr[êe]s|quatro|cinco|seis|sete|oito|nove|dez|onze|doze|treze|catorze|quatorze|'
      r'quinze|dezesseis|dezessete|dezoito|dezenove|vinte)(?!\p{L}))';

  /// "da tarde/noite" soma 12. Sem período, 1 a 5 horas é da tarde ("às
  /// quatro" = 16h): ninguém marca às 4 da madrugada sem dizer, e a
  /// confirmação fala o horário — dá pra corrigir.
  static int _ajustarPeriodo(int hora, String lower) {
    if ((lower.contains('tarde') || lower.contains('noite')) && hora < 12) return hora + 12;
    final disseManha = lower.contains('manhã') || lower.contains('manha') || lower.contains('madrugada');
    if (!disseManha && hora >= 1 && hora <= 5) return hora + 12;
    return hora;
  }

  static const Map<String, int> _unidades = {
    'zero': 0, 'um': 1, 'uma': 1, 'dois': 2, 'duas': 2, 'três': 3, 'tres': 3,
    'quatro': 4, 'cinco': 5, 'seis': 6, 'sete': 7, 'oito': 8, 'nove': 9, 'dez': 10,
    'onze': 11, 'doze': 12, 'treze': 13, 'catorze': 14, 'quatorze': 14, 'quinze': 15,
    'dezesseis': 16, 'dezessete': 17, 'dezoito': 18, 'dezenove': 19,
  };
  static const Map<String, int> _dezenas = {'vinte': 20, 'trinta': 30, 'quarenta': 40, 'cinquenta': 50};

  /// Palavras que podem vir logo depois de um horário — "as duas caixas"
  /// não é horário, "as duas da tarde" é.
  static const _depoisDeHorario = {
    'hora', 'horas', 'e', 'da', 'de', 'em', 'pra', 'para', 'no', 'na', 'todo', 'toda',
    'todos', 'todas', 'amanhã', 'amanha', 'hoje', 'depois', 'ponto', 'h',
  };

  static List<String> _palavras(String lower) =>
      lower.replaceAll(RegExp(r'[,.!?;]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// Número de 0 a 59, por extenso ou em dígitos, começando em p[i].
  /// Devolve (valor, índice da próxima palavra) ou null.
  static (int, int)? _lerNumero(List<String> p, int i) {
    if (i >= p.length) return null;
    final digitos = int.tryParse(p[i]);
    if (digitos != null) return (digitos, i + 1);
    final u = _unidades[p[i]];
    if (u != null) return (u, i + 1);
    final d = _dezenas[p[i]];
    if (d == null) return null;
    if (i + 2 < p.length && p[i + 1] == 'e') {
      final u2 = _unidades[p[i + 2]];
      if (u2 != null && u2 >= 1 && u2 <= 9) return (d + u2, i + 3);
    }
    return (d, i + 1);
  }

  /// Troca horários por extenso por dígitos, só onde é horário de verdade:
  /// depois de "às/as" e seguido de fim de frase ou palavra de horário, ou
  /// numa resposta curta só com palavras de horário ("oito e meia").
  /// "as duas caixas" fica como está.
  static String horasPorExtensoEmDigitos(String lower) {
    final p = _palavras(lower);
    if (p.isEmpty) return lower;
    final respostaCurta = p.every((w) =>
        _unidades.containsKey(w) ||
        _dezenas.containsKey(w) ||
        int.tryParse(w) != null ||
        const {'e', 'meia', 'hora', 'horas', 'da', 'de', 'manhã', 'manha', 'tarde', 'noite', 'às', 'as', 'em', 'ponto'}
            .contains(w));
    final saida = <String>[];
    var mudou = false;
    var i = 0;
    while (i < p.length) {
      final contexto = (i == 0 && respostaCurta) || (saida.isNotEmpty && (saida.last == 'às' || saida.last == 'as'));
      final n = contexto ? _lerNumero(p, i) : null;
      if (n != null && n.$1 <= 23) {
        var j = n.$2;
        int? minuto;
        var k = j;
        if (k < p.length && (p[k] == 'hora' || p[k] == 'horas')) k++;
        if (k + 1 < p.length && p[k] == 'e') {
          if (p[k + 1] == 'meia') {
            minuto = 30;
            j = k + 2;
          } else {
            final m = _lerNumero(p, k + 1);
            if (m != null && m.$1 < 60) {
              minuto = m.$1;
              j = m.$2;
            }
          }
        }
        final seguinte = j < p.length ? p[j] : null;
        if (respostaCurta || seguinte == null || _depoisDeHorario.contains(seguinte)) {
          saida.add(minuto == null ? '${n.$1}' : '${n.$1}:${minuto.toString().padLeft(2, '0')}');
          mudou = true;
          i = j;
          continue;
        }
      }
      saida.add(p[i]);
      i++;
    }
    return mudou ? saida.join(' ') : lower;
  }

  static final RegExp _diaDaSemana = RegExp(
    r'\b(?:na|no|nesta|neste|nessa|nesse|toda|todo|pr[óo]xim[ao])\s+(segunda|ter[çc]a|quarta|quinta|sexta|s[áa]bado|domingo)'
    r'|(segunda|ter[çc]a|quarta|quinta|sexta)[- ]feira',
  );

  static int _numeroDoDiaDaSemana(String nome) {
    if (nome.startsWith('segunda')) return DateTime.monday;
    if (nome.startsWith('ter')) return DateTime.tuesday;
    if (nome.startsWith('quarta')) return DateTime.wednesday;
    if (nome.startsWith('quinta')) return DateTime.thursday;
    if (nome.startsWith('sexta')) return DateTime.friday;
    if (nome.startsWith('s')) return DateTime.saturday;
    return DateTime.sunday;
  }
}
