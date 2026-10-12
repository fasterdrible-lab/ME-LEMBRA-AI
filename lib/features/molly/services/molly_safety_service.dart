/// O que [MollySafetyService.classificar] reconheceu numa fala do usuário.
enum MollySafetyIntent {
  /// Pede indicação/dose/troca de remédio ou um diagnóstico — a MOLLY
  /// nunca responde isso (TAREFAs 21/22 do prompt mestre).
  conselhoMedico,

  /// Relata ter tomado remédio a mais/errado ("tomei dois comprimidos") —
  /// a MOLLY nunca diz se "faz mal ou não"; orienta buscar ajuda humana.
  possivelExcessoDeRemedio,
  nenhuma,
}

/// Regras rígidas de segurança da MOLLY (TAREFA 22 do prompt mestre) e a
/// parte "não pode" da camada de medicamentos (TAREFA 21).
///
/// A MOLLY nunca pode: diagnosticar doenças, indicar/alterar medicação ou
/// dose, substituir o médico, afirmar que a pessoa está segura, ou
/// garantir que uma emergência foi resolvida.
///
/// Duas camadas, ambas 100% locais (não dependem da IA obedecer o prompt):
/// 1. **Entrada** — [classificar]/[respostaSegura]: perguntas médicas são
///    respondidas aqui com uma fala fixa e nunca chegam à IA. Chamado por
///    `MollyAgentService.processar` DEPOIS de `OfflineIntentService` (então
///    SOCORRO e as frases suaves de emergência continuam com prioridade —
///    "estou passando mal, tomei dois comprimidos" vira confirmação de
///    emergência, não esta orientação).
/// 2. **Saída** — [filtrarFalaDaIA]: se uma resposta livre da IA trouxer
///    algo proibido (tranquilizar, mandar mudar dose, dispensar médico),
///    troca pela fala segura padrão.
///
/// O mesmo conjunto de regras também está no `SYSTEM_PROMPT` do backend
/// (`server/ai_command_server/app.py`) — terceira camada.
///
/// Tudo aqui é puro (sem Firebase/plugins), testável direto.
class MollySafetyService {
  static const String falaConselhoMedico =
      'Sobre remédio, dose ou o que pode ser, quem orienta é o seu médico ou o farmacêutico. '
      'Eu posso te lembrar dos horários e marcar quando você tomar.';

  static const String falaExcessoDeRemedio =
      'Eu não sei dizer se isso faz mal. Ligue agora para o seu médico ou avise sua família. '
      'Se não estiver se sentindo bem, diga socorro ou ligue 192.';

  static const String falaSaidaBloqueada =
      'Isso eu não sei responder com segurança. O melhor é falar com o seu médico ou com sua família.';

  static MollySafetyIntent classificar(String texto) {
    final t = _normalizar(texto);
    if (t.isEmpty) return MollySafetyIntent.nenhuma;
    if (_pareceExcessoDeRemedio(t)) return MollySafetyIntent.possivelExcessoDeRemedio;
    if (_pedeConselhoMedico(t)) return MollySafetyIntent.conselhoMedico;
    return MollySafetyIntent.nenhuma;
  }

  /// Fala fixa para [intent], ou `null` se não for um caso de segurança.
  static String? respostaSegura(MollySafetyIntent intent) {
    switch (intent) {
      case MollySafetyIntent.conselhoMedico:
        return falaConselhoMedico;
      case MollySafetyIntent.possivelExcessoDeRemedio:
        return falaExcessoDeRemedio;
      case MollySafetyIntent.nenhuma:
        return null;
    }
  }

  /// Camada de saída: devolve [fala] intacta, ou [falaSaidaBloqueada] se
  /// ela contiver algo que a MOLLY nunca pode dizer.
  static String filtrarFalaDaIA(String fala) {
    final t = _normalizar(fala);
    if (_saidaProibida.any((r) => r.hasMatch(t))) return falaSaidaBloqueada;
    // TAREFA 29: a fala livre da IA nunca executa nada — se ela "conta" que
    // excluiu/ligou/mandou/acionou algo, é invenção. (As ferramentas de
    // verdade, ex. "Mandei para Ana", não passam por este filtro.)
    if (_acaoInventada.hasMatch(t)) return falaAcaoInventada;
    return fala;
  }

  static const String falaAcaoInventada =
      'Isso eu não consigo fazer por aqui. Posso te ajudar com lembretes, avisos para a família ou o SOS.';

  static final RegExp _acaoInventada = RegExp(
      r'\b(exclui|apaguei|deletei|removi|liguei|telefonei|mandei|enviei|avisei|chamei|disparei|acionei|cancelei)\b');

  // ---------------------------------------------------------------------

  static const String _remedio = r'(remedio|medicamento|medicacao|comprimido|pilula|capsula|gota|dose|insulina|antibiotico|calmante|dipirona|paracetamol)s?';

  /// "tomei dois comprimidos", "tomei o remédio duas vezes", "tomei a mais",
  /// "tomei o remédio errado", "tomei o dobro", "acho que tomei demais".
  static final List<RegExp> _excesso = [
    RegExp(r'\btomei\b.*\b(dois|duas|tres|2|3|varios|varias)\b.*\b' + _remedio),
    RegExp(r'\btomei\b.*\b(duas|tres|2|3) vezes\b'),
    RegExp(r'\btomei\b.*\b(a mais|demais|o dobro|errado|errada|de novo sem querer)\b'),
    RegExp(r'\b(tomei|engoli)\b.*\b' + _remedio + r'\b.*\b(de outra pessoa|do meu marido|da minha mulher|da minha esposa)\b'),
  ];

  /// Indicação, dose, troca, suspensão, combinação, ou diagnóstico.
  /// Cuidado com falsos positivos: "o que eu tenho hoje?" (lembretes) e
  /// "me lembra do remédio às oito" NÃO podem cair aqui.
  static final List<RegExp> _conselho = [
    RegExp(r'\b(devo|deveria|posso)\b.*\btomar\b.*\b(para|pra)\b\s*(dor|febre|gripe|pressao|tosse|dormir|ansiedade|diabete)'),
    RegExp(r'\bquant[oa]s?\b.*\b(comprimidos?|gotas?|mg|miligramas?|ml|doses?)\b.*\b(devo|posso|tomo|tenho que)\b'),
    RegExp(r'\b(posso|devo)\b.*\b(parar de tomar|deixar de tomar)\b'),
    RegExp(r'\b(aumentar|diminuir|dobrar)\b.*\bdose\b'),
    RegExp(r'\bposso tomar\b.*\b(junto|com bebida|com alcool|com cerveja|em jejum)\b'),
    RegExp(r'\b(sera que|acho que)\b.*\b(estou|to|tou)\b\s*(com\s*(gripe|febre|covid|dengue|infeccao|pressao alta|diabetes|virose|pneumonia|anemia|cancer|alguma doenca)|doente)\b'),
    RegExp(r'\b(que|qual) doenca\b'),
    RegExp(r'\b(e|eh|sera que e)\b\s*(grave|cancer|infarto|derrame|avc|covid|dengue)\b'),
  ];

  /// "Qual remédio devo tomar?" — indicação. Mas "qual remédio eu devo
  /// tomar agora/hoje?" é pergunta de HORÁRIO (os lembretes), a menos que
  /// venha junto de um sintoma ("agora, pra dor de cabeça").
  static final RegExp _qualRemedio =
      RegExp(r'\b(qual|que)\b.*\b' + _remedio + r'\b.*\b(devo|deveria|posso|e bom|serve)\b');
  static final RegExp _palavraDeHorario =
      RegExp(r'\b(agora|hoje|amanha|de manha|a tarde|a noite|esta noite|horario|que horas)\b');
  static final RegExp _sintoma = RegExp(r'\b(dor|febre|gripe|tosse|enjoo|tontura|pressao|dormir|ansiedade)\b');

  /// Trocar/aumentar/diminuir/misturar só contam quando o assunto é remédio
  /// ("posso trocar o horário do lembrete?" não é conselho médico).
  static final RegExp _mexerNoRemedio = RegExp(
      r'\b(posso|devo)\b.*\b(trocar|aumentar|diminuir|dobrar|misturar|tomar outro|tomar outra)\b.*\b' + _remedio);

  /// O que uma resposta livre da IA nunca pode conter.
  static final List<RegExp> _saidaProibida = [
    RegExp(r'\bvoce (esta|ta) (segur[oa]|fora de perigo)\b'),
    RegExp(r'\bvoce vai ficar bem\b'),
    RegExp(r'\bfora de perigo\b'),
    RegExp(r'\bnao (e|eh) (nada )?grave\b'),
    RegExp(r'\bnao precisa (ir ao |ir no |procurar (o |um )?|de |chamar (o |um )?)?medico\b'),
    RegExp(r'\b(emergencia|problema) (ja )?(foi |esta )?resolvid[oa]\b'),
    RegExp(r'\b(aumente|diminua|dobre|pare de tomar|deixe de tomar|tome mais|tome menos)\b'),
    RegExp(r'\bpode (tomar mais|aumentar|diminuir|dobrar|parar de tomar)\b'),
    RegExp(r'\bvoce (tem|esta com|deve estar com) (uma |um )?(gripe|infeccao|virose|dengue|covid|pneumonia|anemia|diabetes)\b'),
  ];

  static bool _pareceExcessoDeRemedio(String t) => _excesso.any((r) => r.hasMatch(t));
  static bool _pedeConselhoMedico(String t) {
    if (_conselho.any((r) => r.hasMatch(t))) return true;
    if (_mexerNoRemedio.hasMatch(t)) return true;
    if (_qualRemedio.hasMatch(t)) {
      return !_palavraDeHorario.hasMatch(t) || _sintoma.hasMatch(t);
    }
    return false;
  }

  /// Minúsculas e sem acentos — as regras acima são escritas sem acento
  /// (`\b` do Dart não trata letras acentuadas como letra de palavra).
  static String _normalizar(String s) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const para = 'aaaaaeeeeiiiiooooouuuuc';
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = de.indexOf(ch);
      buf.write(i == -1 ? ch : para[i]);
    }
    return buf.toString().trim();
  }
}
