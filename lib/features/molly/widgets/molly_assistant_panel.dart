import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/reminder.dart';
import '../../../services/reminder_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/sos_service.dart';
import '../memory/long_term_memory.dart';
import '../memory/short_term_memory.dart';
import '../models/molly_tool_result.dart';
import '../services/molly_agent_service.dart';
import '../services/molly_context_service.dart';
import '../services/molly_proactive_service.dart';
import '../services/molly_reminder_parser.dart';
import '../services/molly_risk_policy.dart';
import '../services/molly_voice_service.dart';
import 'listening_indicator.dart';

/// Painel interativo da MOLLY (indicador de estado, mensagem, botão de
/// microfone e botão SOS) — extraído de `molly_screen.dart` (sessão 24)
/// pra poder ser usado de duas formas sem duplicar nenhuma lógica de
/// conversa/voz/risco: (1) em tela cheia, na rota `/molly`, com a lista
/// "Hoje" abaixo; (2) como conteúdo de um `showModalBottomSheet` aberto
/// direto de `elderly_screen.dart` — "Assistente Molly" precisa acionar o
/// microfone na hora, sem navegar pra outra tela, mesma sensação do antigo
/// "Falar Comando".
///
/// Todo o restante da lógica (checagem de SOCORRO, coleta local de
/// dia/hora, confirmação de risco, confirmação visual de emergência) é a
/// mesma da tela cheia — nada foi reescrito, só movido pra cá.
///
/// **Máquina de conversa (sessão 24):** frase de encerramento
/// ("obrigado"/"pode parar"/"tchau"...) fala "Até logo!" e encerra, sem
/// contar como turno — ported de `elderly_screen.dart`. O microfone reabre
/// **sozinho** só durante a coleta de dia/hora de um lembrete (a IA
/// pediu esclarecimento) — para qualquer outra resposta completa (ouvir
/// lembretes, resposta livre da IA, comando offline), a conversa termina
/// depois de uma fala, de propósito: continuar ouvindo depois de uma
/// interação já resolvida só captura silêncio/ruído como "não entendi".
/// Essa é a mesma regra de `elderly_screen.dart` — **não** existe (nem
/// nunca existiu) reabertura automática "pra qualquer assunto".
///
/// **Gatilho de memória de longo prazo (sessão 24):** quando
/// `MollyAgentService.processar` devolve uma proposta de memória (já
/// filtrada pelo interruptor "A Molly pode lembrar minhas preferências?"),
/// [_confirmarMemoria] pergunta em voz alta e só grava
/// (`LongTermMemoryService.salvar`) depois de um "sim" — a IA nunca decide
/// sozinha.
class MollyAssistantPanel extends StatefulWidget {
  /// Quando `true`, começa a ouvir sozinho assim que o painel aparece —
  /// usado no atalho rápido de `elderly_screen.dart` pra que tocar o botão
  /// já seja o mesmo gesto de "começar a falar", sem precisar tocar o
  /// microfone de novo dentro do painel.
  final bool autoIniciar;

  /// Quando `true` (padrão, tela cheia), mostra a lista de lembretes de
  /// hoje abaixo do microfone, com o SOS fixo fora da área rolável — nunca
  /// escondido, mesmo com muitos lembretes. Quando `false` (atalho
  /// rápido), omite a lista — o painel fica curto o bastante pra não
  /// precisar rolar, então o SOS já fica sempre visível sem esforço extra.
  final bool mostrarLembretesHoje;

  const MollyAssistantPanel({
    super.key,
    this.autoIniciar = false,
    this.mostrarLembretesHoje = true,
  });

  /// Abre o atalho rápido da MOLLY como um `showModalBottomSheet` sobre a
  /// tela atual — já começa a ouvir sozinho ([autoIniciar]), sem lista de
  /// lembretes ([mostrarLembretesHoje]: false). Usado por
  /// `elderly_screen.dart`: o pedido era que "Assistente Molly" acionasse
  /// a escuta na hora, sem precisar navegar pra outra tela — um bottom
  /// sheet fica sobre a tela atual (que continua por baixo, intacta) em
  /// vez de substituí-la, diferente de `Navigator.pushNamed('/molly')`.
  static Future<void> abrirComoAtalho(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 28,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 28,
        ),
        child: const SafeArea(
          top: false,
          child: MollyAssistantPanel(autoIniciar: true, mostrarLembretesHoje: false),
        ),
      ),
    );
  }

  @override
  State<MollyAssistantPanel> createState() => _MollyAssistantPanelState();
}

class _MollyAssistantPanelState extends State<MollyAssistantPanel> {
  final MollyVoiceService _voz = MollyVoiceService();
  final ShortTermMemory _memoria = ShortTermMemory();
  String _mensagem = 'Como posso ajudar?';

  // Mesma proteção de `elderly_screen.dart`: evita que a checagem local de
  // "SOCORRO" dispare mais de uma vez em rápida sucessão, e evita que o
  // texto reconhecido depois de um SOCORRO ainda seja processado como
  // comando normal.
  bool _sosDisparado = false;

  @override
  void initState() {
    super.initState();
    // Espera o primeiro frame — chamar antes disso arrisca usar um
    // BuildContext ainda não totalmente montado (relevante sobretudo
    // quando o painel nasce dentro de um showModalBottomSheet).
    WidgetsBinding.instance.addPostFrameCallback((_) => _aoAbrir());
  }

  /// Roda uma vez, assim que o painel aparece: primeiro a proatividade
  /// (avisa remédio atrasado sem o usuário precisar perguntar — Fase 8 do
  /// prompt mestre), só depois — se [autoIniciar] — começa a ouvir. Nessa
  /// ordem de propósito: falar por cima do início da escuta faria o
  /// usuário perder o começo do que ela ia dizer.
  Future<void> _aoAbrir() async {
    if (!mounted) return;
    final aviso = await MollyProactiveService.verificarRemedioAtrasado();
    if (aviso != null && mounted) {
      setState(() => _mensagem = aviso);
      await _voz.falar(aviso);
    }
    if (widget.autoIniciar && mounted) {
      await _tocarMicrofone();
    }
  }

  @override
  void dispose() {
    _voz.dispose();
    super.dispose();
  }

  Future<void> _tocarMicrofone() async {
    if (_voz.estado.value == MollyVoiceState.listening) {
      _voz.pararEscuta();
      return;
    }
    setState(() => _mensagem = 'Pode falar.');
    final disponivel = await _voz.escutar(
      aoOuvirParcial: _checarSocorro,
      aoReconhecerFinal: _processarFala,
      aoErro: (_) {
        if (mounted) {
          setState(() => _mensagem = 'Não consegui ouvir. Toque no microfone e tente de novo.');
        }
      },
    );
    if (!disponivel && mounted) {
      setState(() => _mensagem = 'Não consegui usar o microfone neste aparelho.');
    }
  }

  /// "SOCORRO" tem prioridade máxima e é checado 100% local, a qualquer
  /// momento da escuta — nunca passa pela IA nem pelo `MollyToolRegistry`
  /// (ver `docs/MOLLY_ARCHITECTURE_ANALYSIS.md` e TAREFA 18 do prompt
  /// mestre). Mesmo padrão de `elderly_screen.dart`.
  void _checarSocorro(String textoParcial) {
    if (_sosDisparado) return;
    if (!textoParcial.toUpperCase().contains('SOCORRO')) return;

    _sosDisparado = true;
    _voz.pararEscuta();
    if (mounted) setState(() => _mensagem = 'Acionando o SOS...');
    SosService.trigger(motivo: 'voz');
    Future<void>.delayed(const Duration(seconds: 10), () => _sosDisparado = false);
  }

  Future<void> _processarFala(String texto) async {
    if (_sosDisparado) return;
    final limpo = texto.trim();
    if (limpo.isEmpty) {
      if (mounted) setState(() => _mensagem = 'Não entendi. Toque no microfone e tente de novo.');
      return;
    }

    // Frase de encerramento ("obrigado", "pode parar", "tchau"...):
    // checagem 100% local e instantânea, mesmo padrão da checagem de
    // SOCORRO, nunca passa pela IA. Ported de elderly_screen.dart — não
    // conta como turno (a checagem acontece antes de avancarTurno()).
    if (_ehFraseDeEncerramento(limpo)) {
      if (mounted) setState(() => _mensagem = 'Até logo!');
      await _voz.falar('Até logo!');
      _memoria.encerrar();
      return;
    }

    _memoria.registrarPrimeiraFalaSeNecessario(limpo);
    _memoria.avancarTurno();
    if (mounted) setState(() => _mensagem = limpo);
    _voz.marcarPensando();

    if (_memoria.coletandoLembrete) {
      // Já sabemos que é um lembrete faltando dia/hora — extração local e
      // determinística a partir desta resposta, sem voltar à IA (mesma
      // regra de elderly_screen.dart, achado da sessão 22).
      _memoria.mesclarSlots(
        data: MollyReminderParser.extrairData(limpo),
        hora: MollyReminderParser.extrairHora(limpo),
      );
      await _falarResultado(await _perguntarProximoCampoOuFinalizar());
    } else {
      final contexto = await MollyContextService.montar(memoria: _memoria);
      final resultado = await MollyAgentService.processar(
        texto: limpo,
        memoria: _memoria,
        lembretesContexto: contexto.lembretesParaIA,
      );

      if (resultado.precisaEsclarecimento && _memoria.coletandoLembrete) {
        // A IA pediu esclarecimento sobre um lembrete — MollyAgentService
        // já marcou a memória para coleta local. Ignora a pergunta da
        // própria IA (mesma regra de elderly_screen.dart) e extrai o que
        // já dá pra saber a partir da fala que deu origem ao pedido.
        _memoria.mesclarSlots(
          data: MollyReminderParser.extrairData(_memoria.primeiraFala ?? limpo),
          hora: MollyReminderParser.extrairHora(_memoria.primeiraFala ?? limpo),
        );
        await _falarResultado(await _perguntarProximoCampoOuFinalizar());
      } else {
        await _falarResultado(resultado);
      }
    }

    if (_memoria.atingiuLimiteDeTurnos) {
      const aviso = 'Vamos continuar depois. Toque no microfone de novo quando quiser.';
      if (mounted) setState(() => _mensagem = aviso);
      await _voz.falar(aviso);
      _memoria.encerrar();
    }
  }

  /// Depois de mesclar os slots: se faltar dia ou hora, pergunta local (sem
  /// IA) só o que falta; se já tiver tudo, cria o lembrete via
  /// [MollyRiskPolicy] (mesmo caminho de qualquer outra ferramenta da
  /// MOLLY — nunca grava no Firestore direto) e encerra a conversa, mesma
  /// regra de `elderly_screen.dart`._finalizarOuPerguntarProximoCampo.
  Future<MollyToolResult> _perguntarProximoCampoOuFinalizar() async {
    if (!_memoria.temDia) {
      return MollyToolResult.esclarecimento('Para qual dia?', acao: 'coletar_dia');
    }
    if (!_memoria.temHora) {
      return MollyToolResult.esclarecimento('Que horas?', acao: 'coletar_hora');
    }

    final origem = _memoria.primeiraFala ?? '';
    MollyToolResult resultado;
    try {
      final agora = DateTime.now();
      var dataHora = DateTime(
        _memoria.slotAno!,
        _memoria.slotMes!,
        _memoria.slotDia!,
        _memoria.slotHora!,
        _memoria.slotMinuto ?? 0,
      );
      // Mesma regra de elderly_screen.dart: só rola pro dia seguinte quando
      // for "hoje" e a hora já passou — não mexe em datas futuras/passadas
      // explícitas, pra não surpreender com um ano trocado sem avisar.
      if (dataHora.isBefore(agora) && _memoria.slotDia == agora.day && _memoria.slotMes == agora.month) {
        dataHora = dataHora.add(const Duration(days: 1));
      }
      resultado = await MollyRiskPolicy.executar('createReminder', {
        'titulo': MollyReminderParser.limparTitulo(origem),
        'dataHora': dataHora.toIso8601String(),
        'tipo': MollyReminderParser.inferirTipo(origem),
        'recorrencia': MollyReminderParser.inferirRecorrencia(origem),
      });
    } catch (_) {
      resultado = MollyToolResult.falha('Não consegui salvar o lembrete.', acao: 'createReminder');
    }
    // A coleta terminou (com sucesso ou não) — a conversa encerra aqui,
    // mesmo comportamento de elderly_screen.dart (não continua ouvindo à
    // toa depois de já ter resolvido o pedido).
    _memoria.encerrar();
    return resultado;
  }

  Future<void> _falarResultado(MollyToolResult resultado) async {
    if (mounted) setState(() => _mensagem = resultado.fala);
    if (resultado.falasEmSequencia.isNotEmpty) {
      await _voz.falarSequencia(resultado.falasEmSequencia);
    } else {
      await _voz.falar(resultado.fala);
    }

    if (resultado.precisaConfirmacaoDeEmergencia) {
      await _confirmarPossivelEmergencia(resultado);
      return;
    }

    if (resultado.precisaConfirmacao) {
      await _ouvirConfirmacao(resultado);
      return;
    }

    if (resultado.precisaConfirmacaoDeMemoria) {
      await _confirmarMemoria(resultado);
    }
  }

  /// Pergunta em voz alta antes de gravar uma preferência durável sugerida
  /// pela IA (`MollyAgentService.processar` já filtrou pelo interruptor
  /// geral antes de chegar aqui — ver docstring de lá). Só chama
  /// [LongTermMemoryService.salvar] depois de um "sim" — que ainda confere
  /// o mesmo interruptor de novo por conta própria, então mesmo essa
  /// segunda checagem não é dispensada por confiança na primeira.
  Future<void> _confirmarMemoria(MollyToolResult resultado) async {
    final proposta = resultado.dados?['memoriaProposta'] as Map<String, dynamic>?;
    final valor = proposta?['valor'] as String?;
    if (proposta == null || valor == null || valor.trim().isEmpty || !mounted) return;

    final pergunta = 'Posso lembrar disso: $valor?';
    if (mounted) setState(() => _mensagem = pergunta);
    await _voz.falar(pergunta);
    if (!mounted) return;

    await _voz.escutar(
      aoOuvirParcial: _checarSocorro,
      aoReconhecerFinal: (resposta) async {
        if (_sosDisparado) return;
        if (mounted) setState(() => _mensagem = resposta);
        _voz.marcarPensando();

        if (_ehAfirmativo(resposta)) {
          await LongTermMemoryService.salvar(
            type: (proposta['tipo'] as String?)?.trim().isNotEmpty == true
                ? proposta['tipo'] as String
                : 'preferencia',
            value: valor.trim(),
            source: 'conversa',
            confidence: (proposta['confianca'] as num?)?.toDouble() ?? 0.7,
            userApproved: true,
          );
          const ok = 'Combinado, vou lembrar disso.';
          if (mounted) setState(() => _mensagem = ok);
          await _voz.falar(ok);
        } else {
          const cancelado = 'Tudo bem, não vou guardar isso.';
          if (mounted) setState(() => _mensagem = cancelado);
          await _voz.falar(cancelado);
        }
      },
    );
  }

  /// TAREFA 18 do prompt mestre: uma frase de possível emergência mais
  /// suave que "SOCORRO" (ex.: "estou passando mal") nunca dispara o SOS
  /// na hora — mostra esta confirmação visual com contagem regressiva
  /// cancelável primeiro, mesmo padrão do botão SOS manual
  /// (`elderly_screen.dart`, TASK-25). O disparo em si só acontece se a
  /// contagem terminar sem toque em "Cancelar", sempre via
  /// `SosService.trigger()` — o LLM nunca decide isso sozinho (a detecção
  /// veio de `OfflineIntentService`, 100% local).
  Future<void> _confirmarPossivelEmergencia(MollyToolResult pendente) async {
    if (_sosDisparado || !mounted) return;

    final duracao = await SettingsService.getSosCountdownSegundos();
    if (!mounted) return;
    var contador = duracao;
    Timer? timer;
    var cancelado = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setStateDialog) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (!mounted) {
              timer?.cancel();
              return;
            }
            if (contador <= 1) {
              timer?.cancel();
              if (Navigator.canPop(dialogCtx)) Navigator.pop(dialogCtx);
            } else {
              setStateDialog(() => contador--);
            }
          });
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Parece que você precisa de ajuda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vou acionar seu contato de emergência.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 12),
                Text(
                  '$contador',
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Color(0xFFE53935)),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    cancelado = true;
                    timer?.cancel();
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (cancelado || !mounted) return;
    _sosDisparado = true;
    await SosService.trigger(motivo: 'voz');
    Future<void>.delayed(const Duration(seconds: 10), () => _sosDisparado = false);
  }

  /// Único turno extra de confirmação (sim/não) para uma ação MEDIUM
  /// ambígua ou CRITICAL (TAREFA 4). Não é a máquina de conversa completa
  /// — só o suficiente para o portão de risco funcionar de ponta a ponta.
  Future<void> _ouvirConfirmacao(MollyToolResult pendente) async {
    await _voz.escutar(
      aoOuvirParcial: _checarSocorro,
      aoReconhecerFinal: (resposta) async {
        if (_sosDisparado) return;
        if (mounted) setState(() => _mensagem = resposta);
        _voz.marcarPensando();

        if (_ehAfirmativo(resposta)) {
          final parametros =
              (pendente.dados?['parametrosPendentes'] as Map<String, dynamic>?) ?? const {};
          final resultadoFinal = await MollyRiskPolicy.confirmarEExecutar(pendente.acao, parametros);
          await _falarResultado(resultadoFinal);
        } else {
          const cancelado = 'Tudo bem, não fiz nada.';
          if (mounted) setState(() => _mensagem = cancelado);
          await _voz.falar(cancelado);
        }
      },
    );
  }

  bool _ehAfirmativo(String texto) {
    final t = texto.toLowerCase();
    const palavras = ['sim', 'pode', 'isso mesmo', 'confirmo', 'confirmar', 'claro', 'é isso', 'e isso'];
    return palavras.any((p) => t.contains(p));
  }

  /// Detecta frases de encerramento da conversa ("obrigado", "pode parar",
  /// "só isso", "tchau"...) — mesma lista de `elderly_screen.dart`,
  /// checagem local instantânea, nunca passa pela IA.
  bool _ehFraseDeEncerramento(String texto) {
    final t = texto.toLowerCase();
    const frases = [
      'obrigado', 'obrigada', 'pode parar', 'só isso', 'so isso',
      'é só', 'e so', 'tchau', 'até mais', 'ate mais',
      'chega', 'terminei', 'pode encerrar', 'finalizar',
    ];
    return frases.any((f) => t.contains(f));
  }

  Future<void> _acionarSOSManual() async {
    final disparado = await SosService.trigger(motivo: 'manual');
    if (!disparado && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O Botão de Pânico (SOS) está desativado. Ative em Configurações.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final indicador = ValueListenableBuilder<MollyVoiceState>(
      valueListenable: _voz.estado,
      builder: (context, estado, _) => ListeningIndicator(estado: estado),
    );
    final mensagem = Text(
      _mensagem,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, height: 1.3),
    );
    final botaoMic = ValueListenableBuilder<MollyVoiceState>(
      valueListenable: _voz.estado,
      builder: (context, estado, _) => _BotaoMicrofone(
        ouvindo: estado == MollyVoiceState.listening,
        onTap: _tocarMicrofone,
      ),
    );
    final botaoSOS = _BotaoSOS(onPressed: _acionarSOSManual);

    if (!widget.mostrarLembretesHoje) {
      // Atalho rápido (bottom sheet): coluna curta, sem lista de
      // lembretes pra rolar — o SOS já fica visível sem esforço, não
      // precisa ficar fixo separadamente.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicador,
          const SizedBox(height: 20),
          mensagem,
          const SizedBox(height: 36),
          botaoMic,
          const SizedBox(height: 32),
          botaoSOS,
        ],
      );
    }

    // Tela cheia (/molly): SOS fixo fora da área rolável — nunca
    // escondido, mesmo com muitos lembretes na lista "Hoje" (mesma
    // garantia de sempre, só reorganizada nesta extração).
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              children: [
                indicador,
                const SizedBox(height: 20),
                mensagem,
                const SizedBox(height: 36),
                botaoMic,
                const SizedBox(height: 44),
                const Divider(height: 1),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Hoje', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                _ListaLembretesHoje(),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: botaoSOS,
        ),
      ],
    );
  }
}

class _BotaoMicrofone extends StatelessWidget {
  final bool ouvindo;
  final VoidCallback onTap;

  const _BotaoMicrofone({required this.ouvindo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cor = ouvindo ? const Color(0xFF4A90D9) : const Color(0xFF7B5EA7);
    return Semantics(
      button: true,
      label: ouvindo ? 'Parar de ouvir' : 'Falar com a Molly',
      child: Material(
        color: cor,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 120,
            height: 120,
            child: Icon(
              ouvindo ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
        ),
      ),
    );
  }
}

class _BotaoSOS extends StatelessWidget {
  final VoidCallback onPressed;

  const _BotaoSOS({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 3,
        ),
        child: const Text('SOS', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ListaLembretesHoje extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reminder>>(
      stream: ReminderService.stream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: CircularProgressIndicator(),
          );
        }
        final agora = DateTime.now();
        final hoje = snapshot.data!
            .where((r) =>
                r.dateTime.year == agora.year &&
                r.dateTime.month == agora.month &&
                r.dateTime.day == agora.day)
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        if (hoje.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nenhum lembrete para hoje.',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          );
        }

        return Column(
          children: [
            for (final r in hoje)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  title: Text(
                    r.title.isNotEmpty ? r.title : r.type,
                    style: const TextStyle(fontSize: 20),
                  ),
                  trailing: Text(
                    '${r.dateTime.hour.toString().padLeft(2, '0')}:${r.dateTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
