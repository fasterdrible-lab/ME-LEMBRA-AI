import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/reminder.dart';
import '../../../services/reminder_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/sos_service.dart';
import '../memory/short_term_memory.dart';
import '../models/molly_tool_result.dart';
import '../services/molly_agent_service.dart';
import '../services/molly_context_service.dart';
import '../services/molly_risk_policy.dart';
import '../services/molly_voice_service.dart';
import '../widgets/listening_indicator.dart';

/// Tela principal da MOLLY (TAREFA 6 do prompt mestre).
///
/// Interface pensada para 60+: botões grandes, alto contraste, poucas
/// opções na tela, feedback visual (indicador de estado) e sonoro (TTS via
/// [MollyVoiceService]). O botão SOS **nunca** fica escondido — está fixo
/// na parte de baixo, fora da área rolável, em qualquer estado da tela.
///
/// Ainda não está ligada a nenhum ponto de entrada do app (nenhum botão
/// existente navega para cá) — é aditiva de propósito, por trás da rota
/// `/molly`, para poder ser testada sem tocar o fluxo do "Falar Comando"
/// já em produção em `elderly_screen.dart` (ver `docs/MOLLY_ARCHITECTURE_ANALYSIS.md`).
///
/// Desde a TAREFA 18, uma frase de possível emergência mais suave que
/// "SOCORRO" (detectada por `OfflineIntentService`) mostra uma
/// confirmação visual com contagem regressiva cancelável antes de
/// disparar o SOS — ver [_confirmarPossivelEmergencia]. "SOCORRO" em si
/// continua disparando na hora, sem essa etapa, via [_checarSocorro].
///
/// Desde a TAREFA 7, mantém um [ShortTermMemory] por visita à tela: tocar
/// o microfone de novo depois de uma resposta continua a MESMA conversa
/// (histórico enviado à IA, contador de turnos), então "quando é minha
/// consulta?" seguido de "me lembra duas horas antes" já funciona sem
/// precisar reabrir a tela. O que ainda falta, deliberadamente: se a IA
/// pedir esclarecimento sobre dia/hora de um lembrete (`perguntar`), esta
/// tela ainda não faz a coleta local determinística que
/// `elderly_screen.dart` faz (isso depende de extrair os parsers de
/// data/hora para fora dele — TAREFA 17, OfflineIntentService); por ora só
/// fala a pergunta da IA e volta a chamar a IA no próximo toque, com o
/// mesmo risco de "esquecimento" entre turnos que motivou aquela extração
/// lá. A máquina de conversa completa (frases de encerramento, vários
/// turnos sem tocar o botão) continua sendo de um controller futuro
/// (`molly_controller.dart`), não desta tela.
class MollyScreen extends StatefulWidget {
  const MollyScreen({super.key});

  @override
  State<MollyScreen> createState() => _MollyScreenState();
}

class _MollyScreenState extends State<MollyScreen> {
  static const Color _primary = Color(0xFF7B5EA7);

  final MollyVoiceService _voz = MollyVoiceService();
  final ShortTermMemory _memoria = ShortTermMemory();
  String _mensagem = 'Como posso ajudar?';

  // Mesma proteção de `elderly_screen.dart`: evita que a checagem local de
  // "SOCORRO" dispare mais de uma vez em rápida sucessão, e evita que o
  // texto reconhecido depois de um SOCORRO ainda seja processado como
  // comando normal.
  bool _sosDisparado = false;

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

    _memoria.registrarPrimeiraFalaSeNecessario(limpo);
    _memoria.avancarTurno();

    if (mounted) setState(() => _mensagem = limpo);
    _voz.marcarPensando();
    final contexto = await MollyContextService.montar(memoria: _memoria);
    final resultado = await MollyAgentService.processar(
      texto: limpo,
      memoria: _memoria,
      lembretesContexto: contexto.lembretesParaIA,
    );
    await _falarResultado(resultado);

    if (_memoria.atingiuLimiteDeTurnos) {
      const aviso = 'Vamos continuar depois. Toque no microfone de novo quando quiser.';
      if (mounted) setState(() => _mensagem = aviso);
      await _voz.falar(aviso);
      _memoria.encerrar();
    }
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
    }
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
  /// — só o suficiente para o portão de risco funcionar de ponta a ponta
  /// nesta tela.
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        title: const Text('MOLLY', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Column(
                  children: [
                    ValueListenableBuilder<MollyVoiceState>(
                      valueListenable: _voz.estado,
                      builder: (context, estado, _) => ListeningIndicator(estado: estado),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _mensagem,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, height: 1.3),
                    ),
                    const SizedBox(height: 36),
                    ValueListenableBuilder<MollyVoiceState>(
                      valueListenable: _voz.estado,
                      builder: (context, estado, _) => _BotaoMicrofone(
                        ouvindo: estado == MollyVoiceState.listening,
                        onTap: _tocarMicrofone,
                      ),
                    ),
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
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: _BotaoSOS(onPressed: _acionarSOSManual),
              ),
            ),
          ],
        ),
      ),
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
