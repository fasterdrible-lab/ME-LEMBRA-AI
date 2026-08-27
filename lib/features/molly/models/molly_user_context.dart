/// Retrato controlado do usuário que a MOLLY tem permissão de conhecer
/// AGORA (TAREFA 10 do prompt mestre) — nunca o Firestore inteiro, só um
/// resumo já filtrado e pequeno, montado por `MollyContextService`.
class MollyUserContext {
  final String? nome;
  final String? perfil;
  final DateTime agora;

  /// Lembretes de ontem em diante, resumidos (título/tipo/data — nunca o
  /// documento completo), capados em 15.
  final List<Map<String, dynamic>> proximosLembretes;

  /// Lembretes confirmados nos últimos 30 dias, resumidos.
  final List<Map<String, dynamic>> historicoRecente;

  /// Só os nomes dos familiares vinculados — nunca uid/papel/vínculo.
  final List<String> familiares;

  /// Memórias de longo prazo (`type`/`value`), vazio se o usuário não
  /// autorizou a memória (`SettingsService.getMollyMemoriaAutorizada`).
  final List<Map<String, dynamic>> preferencias;

  final bool sosAtivo;
  final bool chatAtivo;
  final bool notificacoesAtivas;

  /// Quantos turnos a conversa atual já teve, e se está em modo de coleta
  /// de dia/hora — de [ShortTermMemory], quando fornecida a
  /// `MollyContextService.montar`.
  final int conversaTurnos;
  final bool conversaColetandoLembrete;

  const MollyUserContext({
    required this.nome,
    required this.perfil,
    required this.agora,
    required this.proximosLembretes,
    required this.historicoRecente,
    required this.familiares,
    required this.preferencias,
    required this.sosAtivo,
    required this.chatAtivo,
    required this.notificacoesAtivas,
    required this.conversaTurnos,
    required this.conversaColetandoLembrete,
  });

  /// Formato mínimo que o backend de IA hoje sabe interpretar
  /// (`AiCommandService.interpretar`, contexto `lembretes`). O restante
  /// deste objeto (familiares, preferências, configurações, histórico)
  /// **não é mandado à IA nesta tarefa** — o contrato do backend não foi
  /// alterado (ampliar o que a IA vê é decisão própria, futura, ligada à
  /// TAREFA 32 de abstração de provedor). Até lá, este contexto mais
  /// completo serve para outros consumidores dentro do app (proatividade,
  /// briefing, telas) sem duplicar a lógica de busca em cada um.
  List<Map<String, dynamic>> get lembretesParaIA => proximosLembretes;
}
