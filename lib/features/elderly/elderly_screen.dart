import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/reminder.dart';
import '../../services/ai_command_service.dart';
import '../../services/fall_detector_service.dart';
import '../../services/notification_service.dart';
import '../../services/profile_service.dart';
import '../../services/reminder_service.dart';
import '../../services/settings_service.dart';
import '../../services/sos_service.dart';
import '../../services/voice_service.dart';
import '../../services/sos_feed_service.dart';
import '../family/family_contact_sheet.dart';
import '../maps/map_screen.dart';
import '../vehicle/vehicle_screen.dart';
import 'meus_lembretes_screen.dart';

/// Tela do perfil Idoso.
///
/// Foco em acessibilidade:
/// - Tipografia grande e alto contraste.
/// - Botões grandes e espaçados.
/// - Leitura por voz (TTS) dos lembretes.
/// - Entrada por voz (STT) com palavra-chave "SOCORRO" para acionar SOS.
class ElderlyScreen extends StatefulWidget {
  const ElderlyScreen({super.key});

  @override
  State<ElderlyScreen> createState() => _ElderlyScreenState();
}

class _ElderlyScreenState extends State<ElderlyScreen> {
  static const Color _primary = Color(0xFF7B5EA7);
  static const Color _danger = Color(0xFFE53935);

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _sosDisparado = false;
  bool _sosEmExecucao = false;
  String _mensagem = 'Bem-vindo!';
  String _textoReconhecido = '';
  String _capturaComando = '';
  bool _comandoProcessado = false;

  // Assistente conversacional (Falar Comando): memória curta da conversa
  // atual e contador de turnos, para permitir várias trocas seguidas sem
  // precisar tocar o botão de novo a cada frase.
  final List<ConversaTurno> _historicoConversa = [];
  int _turnosConversa = 0;
  static const int _maxTurnosConversa = 6;
  static const int _maxHistoricoTrocas = 3;

  // SOS por toques: 5 toques em 3 s
  final List<DateTime> _tapTimes = [];

  void _registrarToque() {
    final agora = DateTime.now();
    _tapTimes.removeWhere(
        (t) => agora.difference(t) > const Duration(seconds: 3));
    _tapTimes.add(agora);
    if (_tapTimes.length >= 5) {
      _tapTimes.clear();
      _acionarSOS();
    }
  }

  @override
  void initState() {
    super.initState();
    FallDetectorService.start();
    NotificationService.scheduleMorningBriefing();
  }

  @override
  void dispose() {
    _speech.stop();
    FallDetectorService.stop();
    super.dispose();
  }

  Future<void> _falar(String texto) async {
    setState(() => _mensagem = texto);
    await VoiceService.speak(texto);
  }

  Future<void> _lerLembretesDoDia() async {
    final hoje = await _carregarLembretesHoje();
    if (hoje.isEmpty) {
      await _falar('Você não tem lembretes para hoje.');
      return;
    }

    final qtd = hoje.length;
    final frase = qtd == 1
        ? 'Você tem 1 lembrete hoje.'
        : 'Você tem $qtd lembretes hoje.';
    setState(() => _mensagem = frase);
    await VoiceService.enqueue(frase);
    for (final Reminder r in hoje) {
      final titulo = r.title.isNotEmpty ? r.title : r.type;
      await VoiceService.enqueue('$titulo, às ${_horaFalada(r.dateTime)}.');
    }
  }

  Future<List<Reminder>> _carregarLembretesHoje() async {
    final agora = DateTime.now();
    final lembretes = await ReminderService.getAll();
    return lembretes.where((r) =>
        r.dateTime.year == agora.year &&
        r.dateTime.month == agora.month &&
        r.dateTime.day == agora.day).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  /// Formata um horário para fala natural em pt-BR.
  /// Ex.: 16:27 -> "16 horas e 27 minutos"; 16:00 -> "16 horas".
  String _horaFalada(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute;
    final hStr = h == 1 ? '1 hora' : '$h horas';
    if (m == 0) return hStr;
    final mStr = m == 1 ? '1 minuto' : '$m minutos';
    return '$hStr e $mStr';
  }

  Future<void> _excluirLembrete(Reminder r) async {
    if (!mounted) return;
    final notifId = (r.title.hashCode ^ r.dateTime.millisecondsSinceEpoch)
        .remainder(2147483647)
        .abs();
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Excluir lembrete', style: TextStyle(fontSize: 24)),
        content: Text(
          'Deseja excluir "${r.title.isNotEmpty ? r.title : r.type}"?',
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(fontSize: 20)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ReminderService.delete(r.id, notificationId: notifId);
                if (mounted) setState(() {});
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Erro ao excluir: $e')),
                );
              }
            },
            child: const Text('Excluir', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }

  /// Ponto único de entrada por voz da tela do idoso: ouve um comando
  /// livre e roteia para a ação certa (ouvir lembretes, criar lembrete,
  /// adicionar item na lista, checar alertas SOS ou, a qualquer momento,
  /// "SOCORRO" com prioridade máxima). Substitui os antigos botões
  /// separados "Ouvir lembretes", "Criar lembrete por voz" e "Meus
  /// Alertas SOS" — tudo passa a ser feito só falando.
  Future<void> _falarComando() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      _encerrarConversa();
      return;
    }
    // Todo toque manual no botão começa uma conversa do zero.
    _encerrarConversa();
    await _iniciarEscuta();
  }

  /// Abre o microfone por um turno. Chamado tanto pelo toque no botão
  /// quanto automaticamente ao final de cada turno da conversa, pra deixar
  /// o assistente escutando a próxima fala sem precisar tocar de novo.
  Future<void> _iniciarEscuta() async {
    final disponivel = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && _isListening) {
          if (mounted) setState(() => _isListening = false);
          _finalizarComando();
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );

    if (!disponivel) {
      await _falar('Reconhecimento de voz indisponível.');
      return;
    }

    _capturaComando = '';
    _comandoProcessado = false;
    setState(() {
      _isListening = true;
      _textoReconhecido = '';
    });

    _speech.listen(
      localeId: 'pt_BR',
      // Tempos generosos: usuários idosos costumam falar com pausas entre
      // palavras, e um pauseFor curto corta a frase no meio (ex.:
      // "adicionar carne ao" sem "mercado" — confirmado em log real).
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(seconds: 6),
      onResult: (result) {
        _capturaComando = result.recognizedWords;
        setState(() {
          _textoReconhecido = _capturaComando;
          if (_capturaComando.isNotEmpty) _mensagem = _capturaComando;
        });

        // SOCORRO tem prioridade máxima: dispara na hora, sem esperar
        // terminar de entender o resto do comando, mesmo no meio de uma
        // conversa com o assistente.
        if (_capturaComando.toUpperCase().contains('SOCORRO') && !_sosDisparado) {
          _sosDisparado = true;
          _comandoProcessado = true;
          _speech.stop();
          if (mounted) setState(() => _isListening = false);
          _encerrarConversa();
          _acionarSOS();
          Future<void>.delayed(const Duration(seconds: 10), () {
            if (mounted) _sosDisparado = false;
          });
          return;
        }

        if (result.finalResult) {
          _finalizarComando();
        }
      },
    );
  }

  void _finalizarComando() {
    if (_comandoProcessado) return;
    _comandoProcessado = true;
    _processarComando(_capturaComando);
  }

  /// Detecta frases de encerramento da conversa ("obrigado", "pode parar",
  /// "só isso", "tchau"...) — checagem local instantânea, mesmo padrão da
  /// checagem de SOCORRO, nunca passa pela IA.
  bool _ehFraseDeEncerramento(String texto) {
    final t = texto.toLowerCase();
    const frases = [
      'obrigado', 'obrigada', 'pode parar', 'só isso', 'so isso',
      'é só', 'e so', 'tchau', 'até mais', 'ate mais',
      'chega', 'terminei', 'pode encerrar', 'finalizar',
    ];
    return frases.any((f) => t.contains(f));
  }

  /// Reseta o estado da conversa multi-turno (histórico + contador de
  /// turnos). Chamado ao encerrar por frase, por silêncio, pelo limite de
  /// turnos, por toque manual de parada, ou por SOCORRO.
  void _encerrarConversa() {
    _historicoConversa.clear();
    _turnosConversa = 0;
  }

  /// Monta um resumo leve dos lembretes (título/tipo/data-hora, nunca o
  /// documento completo) para dar contexto real à IA e evitar alucinação.
  /// Para lembretes de "Compras", inclui também a descrição (é lá que
  /// ficam os itens da lista) — sem isso a IA sabe que a lista existe mas
  /// não o que tem dentro, e não consegue responder "o que tem na minha
  /// lista?" sem inventar.
  Future<List<Map<String, dynamic>>> _lembretesParaContextoIA() async {
    try {
      final todos = await ReminderService.getAll();
      final agora = DateTime.now();
      final relevantes = todos
          .where((r) =>
              r.dateTime.isAfter(agora.subtract(const Duration(days: 1))))
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return relevantes
          .take(15)
          .map((r) => {
                'titulo': r.title.isNotEmpty ? r.title : r.type,
                'tipo': r.type,
                'data_hora': r.dateTime.toIso8601String(),
                if (r.type == 'Compras' && r.description.trim().isNotEmpty)
                  'itens': r.description.trim().split('\n'),
              })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Interpreta o comando reconhecido e decide a ação: ouvir lembretes,
  /// checar alertas SOS, adicionar item na lista de compras, ou (padrão)
  /// criar um lembrete novo a partir da frase. Ao final, se a conversa não
  /// tiver sido encerrada, volta a escutar sozinho pro próximo turno.
  Future<void> _processarComando(String raw) async {
    if (!mounted) return;
    final texto = raw.trim();
    if (texto.isEmpty) {
      // O STT às vezes reporta "done"/"notListening" (texto ainda vazio)
      // um instante antes de entregar o resultado de verdade — inclusive
      // "SOCORRO". Uma pequena espera evita falar "não entendi" por cima
      // de uma emergência que está prestes a ser reconhecida.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted || _sosDisparado) return;
      await _falar('Não entendi. Toque em Falar Comando e tente de novo.');
      _encerrarConversa();
      return;
    }
    debugPrint('ElderlyScreen: comando reconhecido: "$texto"');

    // Frase de encerramento: checagem 100% local e instantânea (mesmo
    // padrão da checagem de SOCORRO), nunca passa pela IA.
    if (_ehFraseDeEncerramento(texto)) {
      await _falar('Até logo!');
      _encerrarConversa();
      return;
    }

    _turnosConversa++;
    final t = texto.toLowerCase();

    final pedeOuvirLembretes = t.contains('lembrete') &&
        (t.contains('ouvir') || t.contains('ler') || t.contains('quais') ||
            t.contains('que lembretes') || t.contains('tenho lembrete'));
    final pedeAlertas = t.contains('alerta') ||
        (t.contains('sos') &&
            (t.contains('meus') || t.contains('histórico') || t.contains('historico')));

    if (pedeOuvirLembretes) {
      await _lerLembretesDoDia();
    } else if (pedeAlertas) {
      await _falarResumoAlertas();
    } else if (_isAdicionarNaLista(texto)) {
      await _adicionarItemNaListaDeCompras(texto);
    } else {
      // Frase fora dos atalhos locais: tenta interpretar com IA (backend
      // próprio, que chama a Groq), passando histórico da conversa e um
      // resumo dos lembretes reais pra ela não inventar dado. Se não
      // conseguir (sem internet, backend fora do ar, timeout de ~6s), cai
      // no parser local de sempre.
      final lembretesContexto = await _lembretesParaContextoIA();
      final acaoIA = await AiCommandService.interpretar(
        texto,
        historico: List.unmodifiable(_historicoConversa),
        lembretesContexto: lembretesContexto,
      );
      if (acaoIA != null) {
        await _executarAcaoIA(acaoIA);
        _historicoConversa.add(ConversaTurno(texto, acaoIA.fala));
        if (_historicoConversa.length > _maxHistoricoTrocas) {
          _historicoConversa.removeAt(0);
        }
      } else {
        // Padrão (sem IA disponível): trata como pedido de criar lembrete.
        await _criarLembreteDoTexto(texto);
      }
    }

    if (!mounted) return;
    if (_turnosConversa >= _maxTurnosConversa) {
      await _falar(
          'Vamos continuar depois. Toque em Falar Comando de novo quando quiser.');
      _encerrarConversa();
      return;
    }
    await _iniciarEscuta();
  }

  /// Executa a ação estruturada devolvida pelo backend de IA.
  Future<void> _executarAcaoIA(ComandoAction acao) async {
    switch (acao.acao) {
      case 'ouvir_lembretes':
        await _lerLembretesDoDia();
        break;
      case 'consultar_alertas':
        await _falarResumoAlertas();
        break;
      case 'adicionar_item_lista':
        if (acao.itens.isNotEmpty) {
          await _adicionarItensNaLista(acao.itens);
        } else {
          await _falar('Não entendi o item. Tente novamente.');
        }
        break;
      case 'criar_lembrete':
        await _criarLembreteDeAcao(acao);
        break;
      case 'perguntar':
      case 'responder':
      default:
        await _falar(acao.fala.isNotEmpty ? acao.fala : 'Não entendi. Pode repetir?');
    }
  }

  /// Fala um resumo dos alertas SOS do próprio usuário (substitui a tela
  /// "Meus Alertas SOS" — nada pra tocar, só ouvir).
  Future<void> _falarResumoAlertas() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      await _falar('Não consegui verificar seus alertas agora.');
      return;
    }
    final alertas = await SosFeedService.streamOwnAlerts(uid).first;
    if (alertas.isEmpty) {
      await _falar('Você não tem nenhum alerta de SOS registrado.');
      return;
    }
    final total = alertas.length;
    final ultimo = alertas.first;
    final visto = ultimo.viewedBy.length;
    final agora = DateTime.now();
    final dt = ultimo.createdAt;
    final quandoStr = dt == null
        ? 'agora há pouco'
        : (dt.year == agora.year && dt.month == agora.month && dt.day == agora.day)
            ? 'hoje às ${_horaFalada(dt)}'
            : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} às ${_horaFalada(dt)}';
    final vistoFrase = visto > 0
        ? 'visto por $visto familiar${visto > 1 ? 'es' : ''}'
        : 'ainda não visto por ninguém';
    final qtdFrase = total == 1
        ? 'Você tem 1 alerta de SOS registrado.'
        : 'Você tem $total alertas de SOS registrados.';
    await _falar('$qtdFrase O mais recente foi $quandoStr, $vistoFrase.');
  }

  Future<void> _acionarSOS() async {
    // Evita disparar duas contagens/ligações ao mesmo tempo se o SOS for
    // acionado por mais de um caminho (botão, voz, toques, volume, queda)
    // em rápida sucessão.
    if (_sosEmExecucao) return;

    if (!await SettingsService.getSos()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('O Botão de Pânico (SOS) está desativado. '
                'Ative em Configurações para usar o SOS.'),
          ),
        );
      }
      return;
    }

    _sosEmExecucao = true;
    try {
      await _executarFluxoSOS();
    } finally {
      _sosEmExecucao = false;
    }
  }

  Future<void> _executarFluxoSOS() async {
    int contador = 5;
    Timer? timer;
    bool cancelado = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setStateDialog) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (!mounted) { timer?.cancel(); return; }
            if (contador <= 1) {
              timer?.cancel();
              if (Navigator.canPop(dialogCtx)) Navigator.pop(dialogCtx);
            } else {
              setStateDialog(() => contador--);
            }
          });
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('SOS', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _danger)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Disparando SOS em...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20)),
                const SizedBox(height: 12),
                Text('$contador',
                    style: const TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color: _danger)),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 60),
                    textStyle: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    cancelado = true;
                    timer?.cancel();
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('CANCELAR'),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (cancelado || !mounted) return;
    VoiceService.speak('Emergência! Ajuda está a caminho.');
    await SosService.trigger(motivo: 'manual');

    if (!mounted) return;
    final numeros = await SettingsService.getSosNumeros();
    if (numeros.isNotEmpty && mounted) {
      // A ligação automática pode não completar por motivos fora do
      // controle do app (rede/operadora). Esta tela garante um caminho
      // manual de 1 toque para cada contato, usando o mesmo tipo de
      // discagem que uma ligação digitada à mão (abre o discador já
      // preenchido em vez de tentar ligar direto pelo app).
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirmar chamada de emergência',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: const Text(
              'Se a ligação automática não completou, toque para ligar agora:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18)),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ...numeros.map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _danger,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 58),
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.phone, size: 26),
                  label: Text('LIGAR AGORA — $n'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    SosService.openDialer(n);
                  },
                ),
              ),
            )),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      );
    }
  }

  /// Extrai data/hora de uma frase em português (ex: "consulta dia 15 de maio às 15").
  /// Retorna now+1min se não reconhecer nenhum horário.
  DateTime _parsearDataHora(String texto) {
    final agora = DateTime.now();
    final lower = texto.toLowerCase();
    const meses = {
      'janeiro': 1, 'fevereiro': 2, 'março': 3, 'marco': 3,
      'abril': 4, 'maio': 5, 'junho': 6, 'julho': 7,
      'agosto': 8, 'setembro': 9, 'outubro': 10,
      'novembro': 11, 'dezembro': 12,
    };

    int dia = agora.day;
    int mes = agora.month;
    final int ano = agora.year;
    int hora = -1;
    int minuto = 0;

    if (lower.contains('amanhã') || lower.contains('amanha')) {
      final d = agora.add(const Duration(days: 1));
      dia = d.day;
      mes = d.month;
    }

    for (final entry in meses.entries) {
      final re = RegExp(r'(\d{1,2})\s+de\s+' + entry.key);
      final match = re.firstMatch(lower);
      if (match != null) {
        dia = int.parse(match.group(1)!);
        mes = entry.value;
        break;
      }
    }

    // Suporte a por extenso: "meio-dia" / "ao meio dia" = 12h, "meia-noite" = 0h
    // Captura também minutos opcionais: "meio dia e dez" → 12h10
    final reMeioDia = RegExp(
        r'(?:ao\s+)?meio[- ]dia(?:\s+e\s+(\d{1,2}))?',
        caseSensitive: false);
    final mMeioDia = reMeioDia.firstMatch(lower);
    if (mMeioDia != null) {
      hora = 12;
      minuto = int.parse(mMeioDia.group(1) ?? '0');
    } else if (lower.contains('meia-noite') || lower.contains('meia noite')) {
      hora = 0;
      // "meia noite e dez" → 0h10
      final reMeiaNoite = RegExp(r'meia[- ]noite\s+e\s+(\d{1,2})', caseSensitive: false);
      final mMN = reMeiaNoite.firstMatch(lower);
      if (mMN != null) minuto = int.parse(mMN.group(1)!);
    }

    // Formatos numéricos:
    // "às 15h30" | "às 15:30" | "às 15 e 30" | "às 15 horas e 30" | "às 15"
    if (hora < 0) {
      final reHora = RegExp(
        r'[àa]s?\s+(\d{1,2})'
        r'(?:\s*[h:]\s*(\d{1,2})'
        r'|\s+e\s+(\d{1,2})'
        r'|\s+horas?\s+e\s+(\d{1,2}))?',
      );
      final mHora = reHora.firstMatch(lower);
      if (mHora != null) {
        hora = int.parse(mHora.group(1)!);
        // Tenta capturar minutos de qualquer grupo alternativo
        final min = mHora.group(2) ?? mHora.group(3) ?? mHora.group(4);
        minuto = int.parse(min ?? '0');
        if ((lower.contains('tarde') || lower.contains('noite')) && hora < 12) {
          hora += 12;
        }
      }
    }

    if (hora < 0) return agora.add(const Duration(minutes: 1));

    var result = DateTime(ano, mes, dia, hora, minuto);
    if (result.isBefore(agora) && dia == agora.day && mes == agora.month) {
      result = result.add(const Duration(days: 1));
    }
    return result;
  }

  /// Remove a parte temporal do título para exibição limpa.
  String _limparTitulo(String texto) {
    final patterns = [
      RegExp(r'\s+no\s+dia\b', caseSensitive: false),
      RegExp(r'\s+dia\s+\d', caseSensitive: false),
      RegExp(r'\s+amanhã\b', caseSensitive: false),
      RegExp(r'\s+amanha\b', caseSensitive: false),
      RegExp(r'\s+hoje\b', caseSensitive: false),
      // Corta em "às" mesmo sem dígito logo após (STT pode dizer "às doze")
      RegExp(r'\s+[àa]s\b', caseSensitive: false),
      // Formatos extras: "para as", "de manhã", "à tarde", "à noite"
      RegExp(r'\s+para\s+as?\b', caseSensitive: false),
      RegExp(r'\s+de\s+manhã\b', caseSensitive: false),
      RegExp(r'\s+à\s+(tarde|noite|manhã)\b', caseSensitive: false),
      // Expressões de horário por extenso
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
  String _inferirRecorrencia(String texto) {
    final t = texto.toLowerCase();
    if (t.contains('todo dia') || t.contains('todos os dias') ||
        t.contains('diariamente') || t.contains('toda manha') ||
        t.contains('toda manhã') || t.contains('todo manha') ||
        t.contains('todo manhã')) return 'diario';
    if (t.contains('toda semana') || t.contains('todo semana') ||
        t.contains('semanalmente') || t.contains('toda segunda') ||
        t.contains('toda terça') || t.contains('toda quarta') ||
        t.contains('toda quinta') || t.contains('toda sexta') ||
        t.contains('todo sábado') || t.contains('todo domingo')) return 'semanal';
    return 'unico';
  }

  /// Infere o tipo (category) a partir do texto.
  String _inferirTipo(String texto) {
    final t = texto.toLowerCase();
    // "tomar água" é categoria própria ("Tomar", seção de água em
    // meus_lembretes_screen.dart) — checar antes do "tomar" genérico
    // abaixo, que por padrão vira remédio.
    if (t.contains('água') || t.contains('agua')) return 'Tomar';
    if (t.contains('remédio') || t.contains('remedio') ||
        t.contains('medicamento') || t.contains('comprimido') ||
        t.contains('tomar')) return 'Remedio';
    if (t.contains('compra') || t.contains('mercado') ||
        t.contains('supermercado') || t.contains('lista')) return 'Mercado';
    if (t.contains('aniversário') || t.contains('aniversario') ||
        t.contains('niver')) return 'Aniversario';
    if (t.contains('churrasco') || t.contains('festa') ||
        t.contains('evento') || t.contains('reunião') ||
        t.contains('reuniao') || t.contains('família') ||
        t.contains('familia')) return 'Reuniao';
    if (t.contains('consulta') || t.contains('médico') ||
        t.contains('medico') || t.contains('dentista') ||
        t.contains('exame')) return 'Consulta';
    // Nenhuma categoria reconhecida: não assume "Remédio" (lista sensível,
    // usada pra medicação real) — cai em "Lembrete" genérico (seção
    // "Outros" em meus_lembretes_screen.dart).
    return 'Lembrete';
  }

  /// Para compras, extrai itens ("comprar leite, pão e arroz" → linhas).
  String _extrairItensCompra(String texto) {
    final lower = texto.toLowerCase();
    final idx = lower.indexOf('comprar');
    if (idx < 0) return '';
    var raw = texto.substring(idx + 7).trim();
    // Remove datas/horas no final
    raw = raw.replaceAll(RegExp(r'\s+(no\s+dia|dia\s+\d|às?\s+\d|amanhã|amanha|hoje).*',
        caseSensitive: false), '');
    // Separa por vírgula ou " e "
    final itens = raw
        .split(RegExp(r',|\se\s'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return itens.join('\n');
  }

  /// Detecta se o comando é "adicionar X na/à lista de compras".
  bool _isAdicionarNaLista(String texto) {
    final t = texto.toLowerCase();
    final temVerbo = t.contains('adicionar') || t.contains('adiciona') ||
        t.contains('adicione') ||
        t.contains('colocar') || t.contains('coloca') ||
        t.contains('coloque') ||
        t.contains('incluir') || t.contains('inclui') ||
        t.contains('inclua') ||
        t.contains('botar') || t.contains('bota') ||
        t.contains('bote') ||
        t.contains('acrescentar') || t.contains('acrescenta') ||
        t.contains('acrescente') ||
        t.contains('põe') || t.contains('poe') || t.contains('ponha');
    final temLista = t.contains('lista') || t.contains('compra') ||
        t.contains('mercado');
    return temVerbo && temLista;
  }

  /// Extrai o nome do(s) item(ns) de "adicionar [item] na lista de compras".
  List<String> _extrairItensDoComando(String texto) {
    var t = texto.toLowerCase();
    // Remove o verbo inicial
    for (final v in [
      'acrescentar ', 'acrescenta ', 'acrescente ',
      'adicionar ', 'adiciona ', 'adicione ',
      'colocar ', 'coloca ', 'coloque ',
      'incluir ', 'inclui ', 'inclua ',
      'botar ', 'bota ', 'bote ',
      'põe ', 'poe ', 'ponha ',
    ]) {
      final idx = t.indexOf(v);
      if (idx >= 0) { t = t.substring(idx + v.length); break; }
    }
    // Remove destino "na / à / a / pra / para (a) minha lista (de compras)",
    // "no / ao / pro mercado" e variações — cobre os jeitos mais comuns de
    // falar isso em português, já que o reconhecimento de voz às vezes
    // recorta preposições de forma diferente do esperado.
    t = t
        .replaceAll(
            RegExp(r'\s+(n[ao]|à|a|pra|para\s+a|para\s+o)\s+minha\s+lista.*',
                caseSensitive: false),
            '')
        .replaceAll(
            RegExp(r'\s+(n[ao]|à|a|pra|para\s+a|para\s+o)\s+lista.*',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s+de\s+compras.*', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'\s+(n[ao]|ao|pro|para\s+o)\s+mercado.*',
                caseSensitive: false),
            '')
        .replaceAll(
            RegExp(r'\s+(n[ao]|ao|pro|para\s+o)\s+supermercado.*',
                caseSensitive: false),
            '')
        .trim();
    // Separa por vírgula ou " e "
    return t
        .split(RegExp(r',|\se\s'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Adiciona item(ns) a um lembrete de Compras existente, ou cria novo card.
  Future<void> _adicionarItemNaListaDeCompras(String raw) async {
    final novosItens = _extrairItensDoComando(raw);
    if (novosItens.isEmpty) {
      await _falar('Não entendi o item. Tente novamente.');
      return;
    }
    await _adicionarItensNaLista(novosItens);
  }

  /// Adiciona item(ns) já extraídos (por regex local ou pela IA) a um
  /// lembrete de Compras existente, ou cria um novo card.
  Future<void> _adicionarItensNaLista(List<String> novosItens) async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final perfil = await ProfileService.getProfile() ?? '';

    // Busca lembrete de Compras já existente — só pelo tipo exato
    // ('Compras', usado por este mesmo fluxo), nunca por texto solto no
    // título: um lembrete qualquer com "mercado"/"compra" no título (ex.:
    // um mal-interpretado pelo parser local) não deve virar a lista.
    final todos = await ReminderService.getAll();
    Reminder? listaExistente;
    for (final r in todos) {
      if (r.type == 'Compras') {
        listaExistente = r;
        break;
      }
    }

    if (listaExistente != null) {
      // Acrescenta à lista existente
      final itensAtuais = listaExistente.description.trim().isNotEmpty
          ? listaExistente.description.trim().split('\n')
              .where((e) => e.isNotEmpty).toList()
          : <String>[];
      final tudo = [...itensAtuais, ...novosItens];
      await ReminderService.update(listaExistente.copyWith(
        description: tudo.join('\n'),
      ));
    } else {
      // Cria novo card de Compras
      final dateTime = DateTime.now().add(const Duration(minutes: 1));
      await ReminderService.add(Reminder(
        id: '',
        userId: userId,
        title: 'Lista de compras',
        type: 'Compras',
        description: novosItens.join('\n'),
        dateTime: dateTime,
        repeat: 'unico',
        notification: '',
        perfil: perfil,
      ));
    }

    final itensFrase = novosItens.length == 1
        ? novosItens.first
        : '${novosItens.sublist(0, novosItens.length - 1).join(', ')} e ${novosItens.last}';
    final confirmacao = listaExistente != null
        ? '$itensFrase adicionado à sua lista de compras.'
        : 'Lista de compras criada com $itensFrase.';
    await VoiceService.speak(confirmacao);
  }

  /// Cria um lembrete a partir de um comando de voz já capturado.
  /// Interpreta data, hora e categoria da frase reconhecida (parser local).
  Future<void> _criarLembreteDoTexto(String raw) async {
    try {
      final dateTime = _parsearDataHora(raw);
      final tituloLimpo = _limparTitulo(raw);
      final tipo = _inferirTipo(raw);
      final repeat = _inferirRecorrencia(raw);
      final descricao = tipo == 'Compras' ? _extrairItensCompra(raw) : '';
      await _salvarLembrete(
        titulo: tituloLimpo,
        tipo: tipo,
        dateTime: dateTime,
        repeat: repeat,
        descricao: descricao,
      );
    } catch (e) {
      await _falar('Não consegui salvar o lembrete.');
    }
  }

  /// Cria um lembrete a partir dos campos já extraídos pela IA (backend),
  /// evitando rodar o parser local de novo em cima do texto.
  Future<void> _criarLembreteDeAcao(ComandoAction acao) async {
    try {
      final titulo = (acao.titulo?.trim().isNotEmpty ?? false)
          ? acao.titulo!.trim()
          : 'Lembrete';
      await _salvarLembrete(
        titulo: titulo,
        tipo: acao.tipo ?? 'Remedio',
        dateTime: acao.dataHora ?? DateTime.now().add(const Duration(minutes: 1)),
        repeat: acao.recorrencia ?? 'unico',
      );
    } catch (e) {
      await _falar('Não consegui salvar o lembrete.');
    }
  }

  /// Salva o lembrete, agenda a notificação e confirma por voz. Usado tanto
  /// pelo parser local (_criarLembreteDoTexto) quanto pela ação vinda da IA
  /// (_criarLembreteDeAcao).
  Future<void> _salvarLembrete({
    required String titulo,
    required String tipo,
    required DateTime dateTime,
    required String repeat,
    String descricao = '',
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final perfil = await ProfileService.getProfile() ?? '';

    final reminder = Reminder(
      id: '',
      userId: userId,
      title: titulo,
      type: tipo,
      description: descricao,
      dateTime: dateTime,
      repeat: repeat,
      notification: '',
      perfil: perfil,
    );
    await ReminderService.add(reminder);

    final notifId = (titulo.hashCode ^ dateTime.millisecondsSinceEpoch)
        .remainder(2147483647)
        .abs();

    if (repeat != 'unico') {
      await NotificationService.scheduleRepeatingReminder(
        id: notifId,
        title: tipo,
        body: titulo,
        scheduledDate: dateTime,
        repeat: repeat,
      );
    } else {
      await NotificationService.scheduleReminder(
        id: notifId,
        title: tipo,
        body: titulo,
        scheduledDate: dateTime,
      );
    }

    final diaStr = dateTime.day.toString().padLeft(2, '0');
    final mesStr = dateTime.month.toString().padLeft(2, '0');
    final horaFalada = _horaFalada(dateTime);
    final repeatFrase = repeat == 'diario'
        ? ', todo dia'
        : repeat == 'semanal'
            ? ', toda semana'
            : ', para $diaStr de $mesStr';
    final tipoLabel = const {
      'Remedio':    'de remédio',
      'Consulta':   'de consulta',
      'Aniversario':'de aniversário',
      'Mercado':    'de mercado',
      'Reuniao':    'de evento',
      'Tomar':      'de tomar',
    }[tipo];
    final tipoFrase = tipoLabel != null ? '$tipoLabel ' : '';
    await VoiceService.speak(
      'Lembrete ${tipoFrase}criado: $titulo$repeatFrase às $horaFalada.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        title: const Text('Modo Idoso', style: TextStyle(fontSize: 26)),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.family_restroom, size: 30),
            tooltip: 'Família',
            onPressed: () => Navigator.pushNamed(context, '/family'),
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 30),
            tooltip: 'Configurações',
            onPressed: () => Navigator.pushNamed(context, '/config'),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _registrarToque,
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _botaoGrande(
                icon: Icons.family_restroom,
                label: 'Chat Familiar',
                color: const Color(0xFF4A90D9),
                onPressed: () => FamilyContactSheet.show(context),
                height: 80,
              ),
              const SizedBox(height: 16),
              _botaoGrande(
                icon: _isListening ? Icons.mic : Icons.mic_none,
                label: _isListening ? 'Ouvindo...' : 'Falar Comando',
                color: _isListening ? Colors.orange : _primary,
                onPressed: _falarComando,
                height: 90,
                fontSize: 26,
              ),
              if (_textoReconhecido.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Você disse: $_textoReconhecido',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.black54),
                ),
              ] else ...[
                const SizedBox(height: 10),
                const Text(
                  'Toque e diga, por exemplo: "me lembra de tomar remédio às 8", '
                  '"quais são meus lembretes de hoje", "adiciona leite na lista '
                  'de compras" ou "meus alertas".',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 16),
              _botaoGrande(
                icon: Icons.list_alt,
                label: 'Meus Lembretes',
                color: const Color(0xFF5E35B1),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MeusLembretesScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _botaoGrande(
                icon: Icons.location_on,
                label: 'Minha Localizacao',
                color: const Color(0xFF1E88E5),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _botaoGrande(
                icon: Icons.directions_car,
                label: 'Meus Veiculos',
                color: const Color(0xFF1E88E5),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VehicleScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _botaoGrande(
                icon: Icons.warning_amber_rounded,
                label: 'SOS',
                color: _danger,
                onPressed: _acionarSOS,
                height: 90,
                fontSize: 32,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _botaoGrande({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    double height = 70,
    double fontSize = 24,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 36),
      label: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

}
