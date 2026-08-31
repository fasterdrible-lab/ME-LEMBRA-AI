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
/// Continua fora de [OfflineIntentService] de propósito: aquela classe
/// cobre os cinco comandos críticos fixos da TAREFA 17 (SOCORRO, "meus
/// lembretes", etc.), não a coleta multi-turno de dia/hora, que é um
/// problema diferente (evitar que a IA "esqueça" dado estruturado entre
/// turnos — achado da sessão 22, ver `docs/CURRENT_STATE.md`).
///
/// 100% puro/testável: nenhuma dependência de Firebase, `speech_to_text`
/// ou `flutter_tts`.
class MollyReminderParser {
  /// Extrai hora (e minuto, se houver) de uma resposta curta a uma
  /// pergunta sobre horário (ex.: "15", "15h30", "3 da tarde", "9h").
  /// Retorna null se não parecer uma resposta de horário.
  static ({int hora, int minuto})? extrairHoraDeResposta(String texto) {
    final lower = texto.toLowerCase().trim();
    final match = RegExp(r'^(\d{1,2})\s*(?:[h:]\s*(\d{1,2}))?').firstMatch(lower);
    if (match == null) return null;
    var hora = int.parse(match.group(1)!);
    if (hora > 23) return null;
    final minuto = int.parse(match.group(2) ?? '0');
    if ((lower.contains('tarde') || lower.contains('noite')) && hora < 12) {
      hora += 12;
    }
    return (hora: hora, minuto: minuto);
  }

  /// Extrai dia/mês/ano de uma frase, ou null se não achar nada — null
  /// significa "ainda não sei", pra poder perguntar em vez de adivinhar
  /// (diferente de um parser que sempre assume "hoje" quando não reconhece
  /// nada).
  static ({int dia, int mes, int ano})? extrairData(String texto) {
    final agora = DateTime.now();
    final lower = texto.toLowerCase();
    const meses = {
      'janeiro': 1, 'fevereiro': 2, 'março': 3, 'marco': 3,
      'abril': 4, 'maio': 5, 'junho': 6, 'julho': 7,
      'agosto': 8, 'setembro': 9, 'outubro': 10,
      'novembro': 11, 'dezembro': 12,
    };
    if (lower.contains('amanhã') || lower.contains('amanha')) {
      final d = agora.add(const Duration(days: 1));
      return (dia: d.day, mes: d.month, ano: d.year);
    }
    if (lower.contains('hoje')) {
      return (dia: agora.day, mes: agora.month, ano: agora.year);
    }
    for (final entry in meses.entries) {
      final re = RegExp(r'(\d{1,2})\s+de\s+' + entry.key);
      final match = re.firstMatch(lower);
      if (match != null) {
        return (dia: int.parse(match.group(1)!), mes: entry.value, ano: agora.year);
      }
    }
    return null;
  }

  /// Extrai hora/minuto de uma frase completa ("às 15h30") ou de uma
  /// resposta curta ("15"). Null se não achar nada — mesmo espírito de
  /// [extrairData].
  static ({int hora, int minuto})? extrairHora(String texto) {
    final lower = texto.toLowerCase();

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
      var hora = int.parse(mHora.group(1)!);
      final min = mHora.group(2) ?? mHora.group(3) ?? mHora.group(4);
      final minuto = int.parse(min ?? '0');
      if ((lower.contains('tarde') || lower.contains('noite')) && hora < 12) {
        hora += 12;
      }
      return (hora: hora, minuto: minuto);
    }

    return extrairHoraDeResposta(texto);
  }

  /// Remove trechos de data/hora do texto original, deixando só o título
  /// (ex.: "consulta com o dentista às 15h" → "consulta com o dentista").
  static String limparTitulo(String texto) {
    final patterns = [
      RegExp(r'\s+no\s+dia\b', caseSensitive: false),
      RegExp(r'\s+dia\s+\d', caseSensitive: false),
      RegExp(r'\s+amanhã\b', caseSensitive: false),
      RegExp(r'\s+amanha\b', caseSensitive: false),
      RegExp(r'\s+hoje\b', caseSensitive: false),
      RegExp(r'\s+[àa]s\b', caseSensitive: false),
      RegExp(r'\s+para\s+as?\b', caseSensitive: false),
      RegExp(r'\s+de\s+manhã\b', caseSensitive: false),
      RegExp(r'\s+à\s+(tarde|noite|manhã)\b', caseSensitive: false),
      RegExp(r'\s+ao\s+meio\b', caseSensitive: false),
      RegExp(r'\s+meio[- ]dia\b', caseSensitive: false),
      RegExp(r'\s+meia[- ]noite\b', caseSensitive: false),
    ];
    int cutAt = texto.length;
    for (final re in patterns) {
      final m = re.firstMatch(texto);
      if (m != null && m.start < cutAt) cutAt = m.start;
    }
    final result = texto.substring(0, cutAt).trim();
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
        t.contains('tomar')) {
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
}
