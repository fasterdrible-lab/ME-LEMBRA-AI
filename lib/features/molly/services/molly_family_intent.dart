/// Pedidos de família reconhecidos localmente (TAREFA 20 do prompt mestre).
enum MollyFamilyIntentTipo {
  /// "Avisa a Ana que estou bem." — destino + mensagem na mesma frase.
  avisar,

  /// "Manda mensagem para meu filho." — a mensagem pode vir junto
  /// ("...dizendo que chego cedo") ou ser perguntada no turno seguinte.
  mensagem,

  /// "Quem está acompanhando meus lembretes?" — lista os cuidadores.
  quemAcompanha,

  /// "Quem é minha família?" — lista todos os familiares vinculados.
  listarFamilia,
}

class MollyFamilyCommand {
  final MollyFamilyIntentTipo tipo;

  /// Como o usuário chamou o familiar ("Ana", "minha filha"). Resolvido
  /// para um `FamilyMember` de verdade por `FamilyTool.resolverFamiliar`.
  final String? destino;

  /// Texto a enviar, já com a primeira letra maiúscula e ponto final.
  /// `null` em [MollyFamilyIntentTipo.mensagem] sem conteúdo na frase.
  final String? mensagem;

  const MollyFamilyCommand(this.tipo, {this.destino, this.mensagem});
}

/// Reconhecimento puro (sem Firebase/IA) dos comandos de família. Chamado
/// por `OfflineIntentService` — depois de SOCORRO e das frases suaves de
/// emergência, então "avisa minha filha que estou passando mal" continua
/// virando confirmação de emergência, não uma mensagem comum.
///
/// Só reconhece frases que COMEÇAM pedindo a ação (depois de um "Molly,"
/// opcional) e sem horário/data: "me lembra de avisar a Ana amanhã às 8"
/// é lembrete, não mensagem agora — mesma guarda de "ligar para X".
class MollyFamilyIntent {
  static final RegExp _endereco = RegExp(r'^\s*molly[,!]?\s*', caseSensitive: false);
  static final RegExp _temHorario = RegExp(r'\d|\bhoras?\b|amanh|depois de|daqui a', caseSensitive: false);

  static final RegExp _avisar = RegExp(
    r'^(?:avisa|avise|fala|fale|diz|diga)\s+(?:pra|pro|para|a|o|à|ao)?\s*(.+?)\s+que\s+(.+?)[.!]*$',
    caseSensitive: false,
  );

  static final RegExp _mandarMensagem = RegExp(
    r'^(?:manda|mande|envia|envie)\s+(?:uma\s+)?mensagem\s+(?:pra|pro|para|à|ao|a|o)\s+(.+?)'
    r'(?:\s+(?:dizendo|falando|que)\s+(?:que\s+)?(.+?))?[.!]*$',
    caseSensitive: false,
  );

  static final RegExp _quemAcompanha = RegExp(
    // Sem \b no fim: o \b do Dart não funciona depois de letra acentuada
    // ("vê"); os radicais já cobrem "acompanhando", "cuidando" etc.
    r'\bquem\b.*\b(acompanha|cuida|monitora|pode ver|vê|ve\b)',
    caseSensitive: false,
  );

  static final RegExp _listarFamilia = RegExp(
    r'\bquem\s+(?:é|e|são|sao)\s+(?:a\s+)?(?:minha\s+família|minha\s+familia|meus\s+familiares)\b',
    caseSensitive: false,
  );

  static MollyFamilyCommand? classificar(String texto) {
    final t = texto.trim().replaceFirst(_endereco, '').trim();
    if (t.isEmpty) return null;

    if (_listarFamilia.hasMatch(t)) {
      return const MollyFamilyCommand(MollyFamilyIntentTipo.listarFamilia);
    }
    if (_quemAcompanha.hasMatch(t) && _falaDeLembretesOuDeMim(t)) {
      return const MollyFamilyCommand(MollyFamilyIntentTipo.quemAcompanha);
    }

    if (_temHorario.hasMatch(t)) return null;

    final m = _mandarMensagem.firstMatch(t);
    if (m != null) {
      final destino = _limparDestino(m.group(1)!);
      if (destino == null) return null;
      final conteudo = m.group(2);
      return MollyFamilyCommand(
        MollyFamilyIntentTipo.mensagem,
        destino: destino,
        mensagem: conteudo == null ? null : formatarMensagem(conteudo),
      );
    }

    final a = _avisar.firstMatch(t);
    if (a != null) {
      final destino = _limparDestino(a.group(1)!);
      final conteudo = a.group(2)!.trim();
      if (destino == null || conteudo.isEmpty) return null;
      return MollyFamilyCommand(
        MollyFamilyIntentTipo.avisar,
        destino: destino,
        mensagem: formatarMensagem(conteudo),
      );
    }
    return null;
  }

  /// "quem está acompanhando meus lembretes", "quem cuida de mim", "quem
  /// pode ver meus lembretes" — mas não "quem vê a novela comigo".
  static bool _falaDeLembretesOuDeMim(String t) {
    final l = t.toLowerCase();
    return l.contains('lembrete') || l.contains('de mim') || l.contains('me acompanha') ||
        l.contains('meus remédios') || l.contains('meus remedios') || l.contains('minha conta');
  }

  /// Destino de no máximo 4 palavras (ex.: "minha filha Ana"); frases
  /// longas aqui quase sempre são outra coisa.
  static String? _limparDestino(String bruto) {
    final d = bruto.trim().replaceAll(RegExp(r'[,.!?]+$'), '');
    if (d.isEmpty) return null;
    if (d.split(RegExp(r'\s+')).length > 4) return null;
    // "fala o que eu tenho hoje" casaria com destino "o" — não é pessoa.
    if (_naoEhPessoa.contains(d.toLowerCase())) return null;
    return d;
  }

  static const Set<String> _naoEhPessoa = {
    'o', 'a', 'os', 'as', 'me', 'mim', 'pra mim', 'para mim', 'te', 'você', 'voce',
    'ele', 'ela', 'isso', 'aquilo', 'tudo', 'algo', 'alguma coisa',
  };

  /// "estou bem" → "Estou bem."
  static String formatarMensagem(String bruto) {
    var s = bruto.trim().replaceAll(RegExp(r'[.!]+$'), '');
    if (s.isEmpty) return s;
    s = s[0].toUpperCase() + s.substring(1);
    return s.endsWith('?') ? s : '$s.';
  }
}
