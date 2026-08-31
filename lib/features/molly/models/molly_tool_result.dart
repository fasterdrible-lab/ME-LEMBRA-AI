/// Resultado de um turno processado por [MollyAgentService]: o que
/// aconteceu e o que falar de volta ao usuário.
///
/// Deliberadamente não fala nada sozinho (sem `VoiceService.speak` aqui
/// dentro) — quem chama decide como e quando reproduzir `fala`/
/// `falasEmSequencia`. Isso mantém o núcleo da MOLLY testável sem TTS e
/// alinhado ao fluxo do prompt mestre (Resposta → TTS são etapas
/// separadas).
class MollyToolResult {
  /// Se a ação foi executada com sucesso (ou é uma resposta de conversa
  /// normal). `false` só em falha real (ex.: não conseguiu salvar).
  final bool sucesso;

  /// `true` quando a IA pediu esclarecimento (`acao == 'perguntar'`) em vez
  /// de executar algo. Quem chama decide como coletar a resposta — hoje,
  /// em `elderly_screen.dart`, isso vira coleta local determinística de
  /// dia/hora (ver `_mesclarSlots`/`_finalizarOuPerguntarProximoCampo`),
  /// porque a IA "esquece" dado já informado entre turnos (achado da
  /// sessão 22). Este serviço não decide essa política sozinho.
  final bool precisaEsclarecimento;

  /// `true` quando a ferramenta não foi executada porque o nível de risco
  /// exige confirmação primeiro (TAREFA 4 do prompt mestre — ver
  /// `MollyRiskPolicy`). Diferente de [precisaEsclarecimento]: aqui a
  /// intenção já está clara, só falta o "sim" do usuário antes de agir.
  /// `dados['parametrosPendentes']` guarda os parâmetros já resolvidos —
  /// depois do "sim", quem chama reexecuta a mesma ferramenta com eles
  /// (`MollyRiskPolicy.confirmarEExecutar`), sem passar pela IA de novo.
  final bool precisaConfirmacao;

  /// `true` quando uma frase pareceu um possível pedido de socorro, mas
  /// não o gatilho explícito "SOCORRO" (TAREFA 18 do prompt mestre — ex.:
  /// "estou passando mal", "preciso de ajuda"). Diferente de
  /// [precisaConfirmacao]: aqui a confirmação é visual, com contagem
  /// regressiva cancelável (mesmo padrão do botão SOS manual), não um
  /// "sim"/"não" falado — por isso é um campo à parte, pra quem chama
  /// (`molly_screen.dart`) saber que precisa mostrar aquele diálogo
  /// específico, não o de confirmação por voz. O disparo do SOS em si
  /// nunca acontece aqui — só depois que a contagem terminar sem
  /// cancelamento, chamando `SosService.trigger()` como sempre.
  final bool precisaConfirmacaoDeEmergencia;

  /// `true` quando a IA sugeriu uma preferência durável do usuário pra
  /// guardar na memória de longo prazo (ex.: "pode me chamar de Seu
  /// Antônio", "eu sempre almoço ao meio-dia") — `dados['memoriaProposta']`
  /// guarda `{tipo, valor, confianca}`. Nunca é a IA quem decide salvar:
  /// isso só chega aqui já filtrado pelo interruptor geral
  /// (`SettingsService.getMollyMemoriaAutorizada`, ver
  /// `MollyAgentService.processar`), e mesmo assim quem chama
  /// (`molly_assistant_panel.dart`) precisa perguntar em voz alta e ouvir
  /// um "sim" antes de chamar `LongTermMemoryService.salvar()` — a mesma
  /// regra de dupla trava da TAREFA 8/9 do prompt mestre.
  final bool precisaConfirmacaoDeMemoria;

  /// `true` quando a IA não respondeu (offline, backend fora do ar, erro).
  /// Quem chama deve tentar o parser local existente antes de desistir —
  /// mesmo comportamento de hoje em `_processarComando` — e só usar `fala`
  /// como último recurso (ela já traz uma mensagem no espírito da
  /// TAREFA 25 do prompt mestre, "failsafe da IA").
  final bool iaIndisponivel;

  /// Nome da ação executada (`ouvir_lembretes`, `criar_lembrete`, etc.) —
  /// útil para telemetria/depuração, não para lógica de negócio.
  final String acao;

  /// Frase principal para falar/exibir ao usuário.
  final String fala;

  /// Quando a resposta faz mais sentido como várias falas curtas em
  /// sequência (ex.: resumo + um lembrete por frase), em vez de uma frase
  /// só. Vazio quando `fala` já é suficiente.
  final List<String> falasEmSequencia;

  /// Dados estruturados extras, para uso futuro por UI (ex.: a lista de
  /// `Reminder` por trás de um resumo falado). Não é serializado nem
  /// enviado a nenhum backend.
  final Map<String, dynamic>? dados;

  const MollyToolResult({
    required this.sucesso,
    required this.fala,
    this.precisaEsclarecimento = false,
    this.precisaConfirmacao = false,
    this.precisaConfirmacaoDeEmergencia = false,
    this.precisaConfirmacaoDeMemoria = false,
    this.iaIndisponivel = false,
    this.acao = 'responder',
    this.falasEmSequencia = const [],
    this.dados,
  });

  /// Anexa uma proposta de memória de longo prazo a este resultado já
  /// pronto — preserva tudo o mais (fala, sucesso, outras flags de
  /// confirmação) e só liga [precisaConfirmacaoDeMemoria]. Usado por
  /// `MollyAgentService.processar` depois de executar a ação normal: a
  /// proposta da IA é um "acréscimo" sobre qualquer resultado, não um tipo
  /// de resultado à parte.
  MollyToolResult comPropostaDeMemoria({
    required String tipo,
    required String valor,
    required double confianca,
  }) =>
      MollyToolResult(
        sucesso: sucesso,
        fala: fala,
        precisaEsclarecimento: precisaEsclarecimento,
        precisaConfirmacao: precisaConfirmacao,
        precisaConfirmacaoDeEmergencia: precisaConfirmacaoDeEmergencia,
        precisaConfirmacaoDeMemoria: true,
        iaIndisponivel: iaIndisponivel,
        acao: acao,
        falasEmSequencia: falasEmSequencia,
        dados: {...?dados, 'memoriaProposta': {'tipo': tipo, 'valor': valor, 'confianca': confianca}},
      );

  factory MollyToolResult.sucesso(
    String fala, {
    String acao = 'responder',
    List<String> falasEmSequencia = const [],
    Map<String, dynamic>? dados,
  }) =>
      MollyToolResult(
        sucesso: true,
        fala: fala,
        acao: acao,
        falasEmSequencia: falasEmSequencia,
        dados: dados,
      );

  factory MollyToolResult.falha(String fala, {String acao = 'responder'}) =>
      MollyToolResult(sucesso: false, fala: fala, acao: acao);

  factory MollyToolResult.esclarecimento(String fala, {String acao = 'perguntar'}) =>
      MollyToolResult(sucesso: true, precisaEsclarecimento: true, fala: fala, acao: acao);

  factory MollyToolResult.confirmar(
    String fala, {
    required String acao,
    required Map<String, dynamic> parametrosPendentes,
  }) =>
      MollyToolResult(
        sucesso: true,
        precisaConfirmacao: true,
        fala: fala,
        acao: acao,
        dados: {'parametrosPendentes': parametrosPendentes},
      );

  /// [motivo] guarda a frase original reconhecida (ex.: "estou passando
  /// mal"), útil pra registrar em `sos_alerts` (`SosService.trigger`
  /// já aceita `motivo`) e pra depuração — não muda o comportamento do
  /// disparo em si.
  factory MollyToolResult.possivelEmergencia(String motivo) => MollyToolResult(
        sucesso: true,
        precisaConfirmacaoDeEmergencia: true,
        fala: 'Parece que você precisa de ajuda.',
        acao: 'possivel_emergencia',
        dados: {'motivo': motivo},
      );

  factory MollyToolResult.semIA() => const MollyToolResult(
        sucesso: false,
        iaIndisponivel: true,
        acao: 'sem_ia',
        fala: 'Estou com dificuldade para responder agora, mas seus '
            'lembretes e o botão SOS continuam funcionando.',
      );
}
