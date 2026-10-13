import '../../../models/family_member.dart';
import '../../../services/chat_service.dart';
import '../models/molly_risk_level.dart';
import '../models/molly_tool_definition.dart';
import '../models/molly_tool_result.dart';
import '../services/molly_cache_service.dart';

/// Ferramentas de família da MOLLY (TAREFA 3 do prompt mestre) — wrappers
/// finos sobre `FamilyService`/`ChatService`, nenhuma chamada nova ao
/// Firestore.
class FamilyTool {
  static final MollyToolDefinition getFamilyMembers = MollyToolDefinition(
    nome: 'getFamilyMembers',
    descricao: 'Lista os familiares vinculados ao usuário.',
    risco: MollyRiskLevel.low,
    parametros: const [],
    executar: (_) async {
      final membros = await MollyCache.familiares();
      if (membros.isEmpty) {
        return MollyToolResult.sucesso(
          'Você ainda não tem nenhum familiar vinculado.',
          acao: 'getFamilyMembers',
        );
      }
      final nomes = membros.map((m) => m.nome).toList();
      final frase = nomes.length == 1
          ? '${nomes.first} está vinculado à sua conta.'
          : '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last} estão vinculados à sua conta.';
      return MollyToolResult.sucesso(frase, acao: 'getFamilyMembers', dados: {'familiares': membros});
    },
  );

  static const MollyToolDefinition sendFamilyMessage = MollyToolDefinition(
    nome: 'sendFamilyMessage',
    descricao: 'Envia uma mensagem de texto a um familiar vinculado, pelo chat familiar.',
    risco: MollyRiskLevel.medium,
    parametros: [
      MollyToolParam(nome: 'nomeFamiliar', tipo: 'string', descricao: 'Nome do familiar destinatário.'),
      MollyToolParam(nome: 'mensagem', tipo: 'string', descricao: 'Texto da mensagem.'),
    ],
    executar: _sendFamilyMessage,
  );

  static Future<MollyToolResult> _sendFamilyMessage(Map<String, dynamic> p) async {
    final nomeFamiliar = (p['nomeFamiliar'] as String).trim();
    final mensagem = (p['mensagem'] as String).trim();
    final resolucao = resolverFamiliar(await MollyCache.familiares(), nomeFamiliar);
    final membro = resolucao.membro;
    if (membro == null) {
      return MollyToolResult.falha(resolucao.falaProblema!, acao: 'sendFamilyMessage');
    }
    try {
      final enviado = await MollyCache.escrever(() => ChatService.send(membro.uid, mensagem));
      // Repete o que foi mandado: o texto veio do reconhecimento de voz e a
      // pessoa precisa ouvir se saiu certo.
      return MollyToolResult.sucesso(
        enviado
            ? 'Mandei para ${membro.nome}: $mensagem'
            : 'Estou sem internet agora. Mando para ${membro.nome} assim que ela voltar: $mensagem',
        acao: 'sendFamilyMessage',
      );
    } catch (_) {
      return MollyToolResult.falha('Não consegui enviar a mensagem agora.', acao: 'sendFamilyMessage');
    }
  }

  /// "Ligar" para um familiar. O app hoje não guarda telefone por
  /// familiar — só o(s) número(s) de SOS genéricos, sem vínculo com uma
  /// conta específica (gap documentado em
  /// `docs/MOLLY_ARCHITECTURE_ANALYSIS.md`, item 3 dos riscos). Por isso
  /// esta ferramenta não disca de verdade: avisa o familiar pelo chat para
  /// que ele ligue de volta. Continua CRITICAL (mesma categoria de
  /// "chamada telefônica" da TAREFA 4) porque, da perspectiva do usuário,
  /// a intenção é a mesma — sempre confirmar antes de executar.
  static const MollyToolDefinition callFamilyMember = MollyToolDefinition(
    nome: 'callFamilyMember',
    descricao: 'Avisa um familiar vinculado, pelo chat, para que ele ligue de volta.',
    risco: MollyRiskLevel.critical,
    parametros: [
      MollyToolParam(nome: 'nomeFamiliar', tipo: 'string', descricao: 'Nome do familiar a avisar.'),
    ],
    executar: _callFamilyMember,
  );

  static Future<MollyToolResult> _callFamilyMember(Map<String, dynamic> p) async {
    final nomeFamiliar = (p['nomeFamiliar'] as String).trim();
    final resolucao = resolverFamiliar(await MollyCache.familiares(), nomeFamiliar);
    final membro = resolucao.membro;
    if (membro == null) {
      return MollyToolResult.falha(resolucao.falaProblema!, acao: 'callFamilyMember');
    }
    try {
      final meuNome = await MollyCache.nome() ?? 'Familiar';
      final enviado = await MollyCache.escrever(
          () => ChatService.send(membro.uid, '📞 $meuNome pediu para você ligar para ele(a).'));
      return MollyToolResult.sucesso(
        enviado
            ? 'Avisei ${membro.nome} para te ligar.'
            : 'Estou sem internet agora. Aviso ${membro.nome} assim que ela voltar. '
                'Se for urgente, diga socorro.',
        acao: 'callFamilyMember',
      );
    } catch (_) {
      return MollyToolResult.falha('Não consegui avisar ${membro.nome} agora.', acao: 'callFamilyMember');
    }
  }

  /// Crise (sessão 26): avisa a família que a pessoa está passando por um
  /// momento difícil — SÓ depois de ela dizer "sim" a "Quer que eu avise
  /// sua família?" (CRITICAL: sempre confirma). Nunca repete o que ela
  /// disse: a mensagem é fixa, o desabafo continua privado.
  static final MollyToolDefinition avisarFamiliaCrise = MollyToolDefinition(
    nome: 'avisarFamiliaCrise',
    descricao: 'Avisa os familiares que a pessoa está passando por um momento difícil (só com o sim dela).',
    risco: MollyRiskLevel.critical,
    parametros: const [],
    executar: (_) async {
      final membros = await MollyCache.familiares();
      if (membros.isEmpty) {
        return MollyToolResult.sucesso(
          'Você ainda não tem familiar vinculado no aplicativo. Ligue para alguém de confiança, ou para o CVV no 188.',
          acao: 'avisarFamiliaCrise',
        );
      }
      // Quem acompanha (cuidador) primeiro; se não houver, todos os vinculados.
      final cuidadores = membros.where((m) => m.papel == 'cuidador').toList();
      final destino = cuidadores.isNotEmpty ? cuidadores : membros;
      final meuNome = await MollyCache.nome() ?? 'Seu familiar';
      var enviouTodos = true;
      for (final m in destino) {
        try {
          final enviado = await MollyCache.escrever(() => ChatService.send(
                m.uid,
                'Aviso da Molly: $meuNome está passando por um momento difícil e pediu que eu avisasse a família. '
                'Se puder, ligue agora.',
              ));
          if (!enviado) enviouTodos = false;
        } catch (_) {
          enviouTodos = false;
        }
      }
      final quem = juntarNomes(destino.map((m) => m.nome).toList());
      return MollyToolResult.sucesso(
        enviouTodos
            ? 'Avisei $quem. Enquanto isso, eu continuo aqui com você.'
            : 'Estou sem internet agora; aviso $quem assim que ela voltar. Se puder, ligue para alguém, ou para o CVV no 188.',
        acao: 'avisarFamiliaCrise',
      );
    },
  );

  /// "Quem está acompanhando meus lembretes?" (TAREFA 20) — os familiares
  /// com papel `cuidador` no vínculo (quem usou o código de convite).
  static final MollyToolDefinition getCaregivers = MollyToolDefinition(
    nome: 'getCaregivers',
    descricao: 'Diz quais familiares acompanham os lembretes do usuário (cuidadores).',
    risco: MollyRiskLevel.low,
    parametros: const [],
    executar: (_) async {
      final membros = await MollyCache.familiares();
      return MollyToolResult.sucesso(falaQuemAcompanha(membros), acao: 'getCaregivers');
    },
  );

  /// Pura e testável.
  static String falaQuemAcompanha(List<FamilyMember> membros) {
    final cuidadores = membros.where((m) => m.papel == 'cuidador').map((m) => m.nome).toList();
    if (cuidadores.isEmpty) {
      return 'Ninguém está acompanhando seus lembretes ainda. '
          'Para isso, um familiar precisa usar o seu código de convite, na tela Família.';
    }
    return cuidadores.length == 1
        ? '${cuidadores.first} acompanha seus lembretes.'
        : '${juntarNomes(cuidadores)} acompanham seus lembretes.';
  }

  /// "Ana", "Ana e Pedro", "Ana, Pedro e Rita".
  static String juntarNomes(List<String> nomes) {
    if (nomes.isEmpty) return '';
    if (nomes.length == 1) return nomes.first;
    return '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last}';
  }

  /// [resolverFamiliar] sobre os familiares vinculados de verdade.
  static Future<ResolucaoFamiliar> resolver(String alvo) async =>
      resolverFamiliar(await MollyCache.familiares(), alvo);

  /// Acha o familiar que o usuário quis dizer — puro e testável.
  ///
  /// Os familiares só têm nome (o app não guarda parentesco), então
  /// "minha filha"/"meu filho" só dá certo sozinho quando há um familiar
  /// vinculado; com mais de um, pede o nome em vez de adivinhar. "minha
  /// filha Ana" usa o nome que vem depois.
  static ResolucaoFamiliar resolverFamiliar(List<FamilyMember> membros, String alvoBruto) {
    if (membros.isEmpty) {
      return const ResolucaoFamiliar.problema('Você ainda não tem nenhum familiar vinculado.');
    }
    final todos = juntarNomes(membros.map((m) => m.nome).toList());
    var alvo = alvoBruto.trim().toLowerCase().replaceFirst(RegExp(r'^(a|o|pra|pro|para|à|ao)\s+'), '');
    if (alvo.isEmpty) return const ResolucaoFamiliar.problema('Não entendi para quem.');

    // TAREFA 29: "liga para qualquer pessoa" — nunca escolher alguém ao
    // acaso; pergunta quem e lembra do "socorro" caso seja ajuda urgente.
    if (_alvoVago.hasMatch(alvo)) {
      return ResolucaoFamiliar.problema(
          'Para quem? Seus familiares são: $todos. Se precisar de ajuda agora, diga socorro.');
    }

    final parentesco = _parentesco.firstMatch(alvo);
    if (parentesco != null) {
      final resto = parentesco.group(1)!.trim();
      if (resto.isEmpty) {
        if (membros.length == 1) return ResolucaoFamiliar.encontrado(membros.first);
        return ResolucaoFamiliar.problema('Você tem mais de um familiar: $todos. Diga o nome de quem você quer.');
      }
      alvo = resto;
    }

    for (final m in membros) {
      if (m.nome.trim().toLowerCase() == alvo) return ResolucaoFamiliar.encontrado(m);
    }
    // Parcial por palavra: "Ana" bate com "Ana Paula", mas "a" não bate com tudo.
    if (alvo.length >= 2) {
      final parciais = membros.where((m) {
        final palavras = m.nome.trim().toLowerCase().split(RegExp(r'\s+'));
        return palavras.contains(alvo) || m.nome.trim().toLowerCase().startsWith(alvo);
      }).toList();
      if (parciais.length == 1) return ResolucaoFamiliar.encontrado(parciais.first);
      if (parciais.length > 1) {
        final nomes = juntarNomes(parciais.map((m) => m.nome).toList());
        return ResolucaoFamiliar.problema('Encontrei mais de um: $nomes. Diga o nome completo.');
      }
    }
    return ResolucaoFamiliar.problema('Não encontrei um familiar chamado $alvoBruto. Seus familiares são: $todos.');
  }

  static final RegExp _alvoVago = RegExp(
      r'^(qualquer (pessoa|um|uma|familiar|parente)|algu[ée]m|ningu[ée]m|todo mundo|todos|tanto faz)$');

  /// Palavra de parentesco no começo; o que vier depois (grupo 1) é o nome.
  /// `(?=\s|$)` em vez de `\b` por causa de "irmã" (acento quebra `\b`).
  static final RegExp _parentesco = RegExp(
    r'^(?:meu|minha|meus|minhas)?\s*'
    r'(?:filh[oa]s?|net[oa]s?|espos[oa]|marido|mulher|irmão|irmã|irmao|irma|sobrinh[oa]|genro|nora|'
    r'cuidador[a]?|família|familia|parente)(?=\s|$)(.*)$',
  );
}

/// Resultado de [FamilyTool.resolverFamiliar]: ou o familiar, ou uma fala
/// curta explicando o problema (nenhum vinculado, ambíguo, não achado).
class ResolucaoFamiliar {
  final FamilyMember? membro;
  final String? falaProblema;

  const ResolucaoFamiliar.encontrado(FamilyMember this.membro) : falaProblema = null;
  const ResolucaoFamiliar.problema(String this.falaProblema) : membro = null;
}
