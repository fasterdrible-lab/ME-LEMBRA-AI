import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/reminder.dart';
import '../../services/fall_detector_service.dart';
import '../../services/notification_service.dart';
import '../../services/profile_service.dart';
import '../../services/reminder_service.dart';
import '../../services/settings_service.dart';
import '../../services/sos_service.dart';
import '../../services/voice_service.dart';
import '../family/family_contact_sheet.dart';
import '../family/sos_history_screen.dart';
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
  String _mensagem = 'Bem-vindo!';
  String _textoReconhecido = '';

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

  Future<void> _alternarEscuta() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final disponivel = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
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

    setState(() => _isListening = true);
    _speech.listen(
      localeId: 'pt_BR',
      onResult: (result) {
        final texto = result.recognizedWords;
        setState(() {
          _textoReconhecido = texto;
          if (texto.isNotEmpty) _mensagem = texto;
        });
        if (texto.toUpperCase().contains('SOCORRO') && !_sosDisparado) {
          _sosDisparado = true;
          _speech.stop();
          if (mounted) setState(() => _isListening = false);
          _acionarSOS();
          // Libera novo disparo após 10s
          Future<void>.delayed(const Duration(seconds: 10), () {
            if (mounted) _sosDisparado = false;
          });
        }
      },
    );
  }

  Future<void> _acionarSOS() async {
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
    if (numeros.length > 1 && mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Contatos adicionais',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: const Text('Ligar para outro contato de emergência?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18)),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ...numeros.skip(1).map((n) => Padding(
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
                  label: Text(n),
                  onPressed: () {
                    Navigator.pop(ctx);
                    SosService.callNumber(n);
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
    return 'Remedio';
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
        t.contains('colocar') || t.contains('coloca') ||
        t.contains('incluir') || t.contains('inclui') ||
        t.contains('botar') || t.contains('bota') ||
        t.contains('acrescentar') || t.contains('põe') ||
        t.contains('poe');
    final temLista = t.contains('lista') || t.contains('compra') ||
        t.contains('mercado');
    return temVerbo && temLista;
  }

  /// Extrai o nome do(s) item(ns) de "adicionar [item] na lista de compras".
  List<String> _extrairItensDoComando(String texto) {
    var t = texto.toLowerCase();
    // Remove o verbo inicial
    for (final v in [
      'acrescentar ', 'adicionar ', 'adiciona ', 'colocar ', 'coloca ',
      'incluir ', 'inclui ', 'botar ', 'bota ', 'põe ', 'poe ',
    ]) {
      final idx = t.indexOf(v);
      if (idx >= 0) { t = t.substring(idx + v.length); break; }
    }
    // Remove destino "na / à / a minha lista (de compras)" e variações
    t = t
        .replaceAll(RegExp(r'\s+(n[ao]|à|a)\s+minha\s+lista.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+(n[ao]|à|a)\s+lista.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+de\s+compras.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+no\s+mercado.*', caseSensitive: false), '')
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
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final perfil = await ProfileService.getProfile() ?? '';

    final novosItens = _extrairItensDoComando(raw);
    if (novosItens.isEmpty) {
      await _falar('Não entendi o item. Tente novamente.');
      return;
    }

    // Busca lembrete de Compras já existente
    final todos = await ReminderService.getAll();
    Reminder? listaExistente;
    for (final r in todos) {
      final t = '${r.title} ${r.type}'.toLowerCase();
      if (t.contains('compra') || t.contains('mercado') ||
          t.contains('supermercado') || r.type == 'Compras') {
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

  /// Cria um lembrete a partir de um comando de voz.
  /// Interpreta data, hora e categoria da frase reconhecida.
  Future<void> _criarLembretePorVoz() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    final disponivel = await _speech.initialize();
    if (!disponivel) {
      await _falar('Reconhecimento de voz indisponível.');
      return;
    }

    await _falar('Me diga o lembrete depois do sinal.');
    setState(() => _isListening = true);

    String captura = '';
    _speech.listen(
      localeId: 'pt_BR',
      listenFor: const Duration(seconds: 8),
      onResult: (result) {
        captura = result.recognizedWords;
        setState(() => _textoReconhecido = captura);
      },
    );

    await Future<void>.delayed(const Duration(seconds: 9));
    await _speech.stop();
    if (!mounted) return;
    setState(() => _isListening = false);

    final raw = captura.trim();
    if (raw.isEmpty) {
      await _falar('Não entendi. Tente novamente.');
      return;
    }

    // ── Comando especial: adicionar item à lista de compras ───────────────
    if (_isAdicionarNaLista(raw)) {
      await _adicionarItemNaListaDeCompras(raw);
      return;
    }

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final perfil = await ProfileService.getProfile() ?? '';
      final dateTime = _parsearDataHora(raw);
      final tituloLimpo = _limparTitulo(raw);
      final tipo = _inferirTipo(raw);
      final repeat = _inferirRecorrencia(raw);
      final descricao = tipo == 'Compras' ? _extrairItensCompra(raw) : '';

      final reminder = Reminder(
        id: '',
        userId: userId,
        title: tituloLimpo,
        type: tipo,
        description: descricao,
        dateTime: dateTime,
        repeat: repeat,
        notification: '',
        perfil: perfil,
      );
      await ReminderService.add(reminder);

      final notifId = (tituloLimpo.hashCode ^ dateTime.millisecondsSinceEpoch)
          .remainder(2147483647)
          .abs();

      if (repeat != 'unico') {
        await NotificationService.scheduleRepeatingReminder(
          id: notifId,
          title: tipo,
          body: tituloLimpo,
          scheduledDate: dateTime,
          repeat: repeat,
        );
      } else {
        await NotificationService.scheduleReminder(
          id: notifId,
          title: tipo,
          body: tituloLimpo,
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
        'Lembrete ${tipoFrase}criado: $tituloLimpo$repeatFrase às $horaFalada.',
      );
    } catch (e) {
      await _falar('Não consegui salvar o lembrete.');
    }
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
                label: _isListening ? 'Ouvindo...' : 'Falar comando',
                color: _isListening ? Colors.orange : _primary,
                onPressed: _alternarEscuta,
              ),
              if (_textoReconhecido.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Você disse: $_textoReconhecido',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 16),
              _botaoGrande(
                icon: Icons.volume_up,
                label: 'Ouvir lembretes de hoje',
                color: Colors.teal,
                onPressed: _lerLembretesDoDia,
              ),
              const SizedBox(height: 16),
              _botaoGrande(
                icon: Icons.add_alert,
                label: 'Criar lembrete por voz',
                color: const Color(0xFF6A1B9A),
                onPressed: _criarLembretePorVoz,
              ),
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
                icon: Icons.history,
                label: 'Meus Alertas SOS',
                color: const Color(0xFFEF5350),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SosHistoryScreen()),
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
