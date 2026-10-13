/// Como a Molly entende respostas curtas (sessão 26) — puro e testável.
///
/// Por palavra inteira, nunca por pedaço de texto: "assim" não contém
/// "sim", "não, pode deixar" não é um sim, "minha filha chega amanhã" não é
/// despedida.
class MollyRespostas {
  static const _negativas = {'nao', 'nunca', 'jamais', 'negativo'};
  static const _positivas = {
    'sim', 'pode', 'claro', 'confirmo', 'confirmar', 'isso', 'quero', 'ok', 'uhum', 'certo',
    'avisa', 'avise', 'manda', 'mande', 'liga', 'ligue',
  };

  /// "sim", "pode", "pode sim", "claro" → sim. Qualquer "não" na frase
  /// vence ("não, pode deixar") — num pedido crítico (avisar a família numa
  /// crise, ligar), na dúvida, é não.
  static bool ehAfirmativo(String texto) {
    final p = _palavras(texto);
    if (p.any(_negativas.contains)) return false;
    return p.any(_positivas.contains);
  }

  /// "tchau", "pode parar" e "até logo" encerram em qualquer frase.
  /// "obrigado", "chega", "só isso" só numa frase curta — no meio de um
  /// desabafo ("obrigada por me ouvir, mas ainda estou triste") a conversa
  /// continua.
  static bool ehDespedida(String texto) {
    final t = ' ${_palavras(texto).join(' ')} ';
    const fortes = [' tchau ', ' pode parar ', ' pode encerrar ', ' ate mais ', ' ate logo '];
    if (fortes.any(t.contains)) return true;
    if (_palavras(texto).length > 5) return false;
    const curtas = [
      ' obrigado ', ' obrigada ', ' brigado ', ' brigada ', ' valeu ', ' so isso ', ' e so ',
      ' chega ', ' terminei ', ' finalizar ',
    ];
    return curtas.any(t.contains);
  }

  static List<String> _palavras(String texto) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const para = 'aaaaaeeeeiiiiooooouuuuc';
    final buf = StringBuffer();
    for (final ch in texto.toLowerCase().split('')) {
      final i = de.indexOf(ch);
      buf.write(i == -1 ? ch : para[i]);
    }
    return buf.toString().split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toList();
  }
}
