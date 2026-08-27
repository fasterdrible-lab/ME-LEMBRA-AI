import '../../../services/ai_command_service.dart' show ConversaTurno;
import '../models/molly_message.dart';

/// Memória de curto prazo de **uma** conversa com a MOLLY (TAREFA 7 do
/// prompt mestre).
///
/// Guarda só o que a conversa ATUAL precisa pra continuar fazendo
/// sentido — nunca persiste em disco/Firestore (isso é
/// `long_term_memory.dart`, TAREFA 8, e só para preferências
/// explicitamente autorizadas). Instanciável de propósito, mesmo padrão
/// de `MollyVoiceService` (TAREFA 5): uma instância por conversa, criada
/// quando ela começa e reiniciada com [encerrar] quando termina — extrai
/// o que hoje são campos soltos em `elderly_screen.dart`
/// (`_historicoConversa`/`_turnosConversa`/`_coletandoLembrete`/
/// `_slotDia`/etc.) para uma classe própria e testável.
///
/// Duas responsabilidades distintas, deliberadamente juntas aqui por
/// nascerem e morrerem com a mesma conversa:
///
/// 1. **Histórico de trocas**, para dar continuidade a perguntas em
///    linguagem natural — ex.: "quando é minha consulta?" → "amanhã às
///    14h" → "me lembra duas horas antes": a segunda pergunta só faz
///    sentido com a primeira troca no histórico. Mandado à IA a cada
///    chamada, sempre limitado a [maxTrocas].
/// 2. **Slots de coleta de lembrete** (dia/hora), preenchidos localmente
///    e de forma determinística. Propositalmente **não** entram no
///    histórico mandado à IA: a sessão 22 (ver `docs/CURRENT_STATE.md`)
///    achou que o modelo "esquece" dado estruturado entre turnos mesmo
///    recebendo o histórico — por isso dia/hora viraram um estado à
///    parte, preenchido por parsers locais (fora desta classe; aqui só
///    guardamos o resultado).
class ShortTermMemory {
  /// Quantas trocas (usuário+assistente) manter no histórico mandado à
  /// IA. Mesmo valor de `elderly_screen.dart` (`_maxHistoricoTrocas`).
  static const int maxTrocas = 3;

  /// Quantos turnos a conversa pode ter antes de encerrar sozinha. Mesmo
  /// valor de `elderly_screen.dart` (`_maxTurnosConversa`).
  static const int maxTurnos = 6;

  final List<MollyMessage> _historico = [];
  int _turnos = 0;
  String? _primeiraFala;

  /// `true` assim que a IA sinaliza que falta dia/hora ("perguntar") —
  /// os turnos seguintes passam a preencher [slotDia]/[slotHora] etc.
  /// localmente, sem voltar à IA.
  bool coletandoLembrete = false;
  int? slotDia, slotMes, slotAno;
  int? slotHora, slotMinuto;

  int get turnos => _turnos;

  /// A primeira fala da conversa atual — fonte de título/tipo/recorrência
  /// (extraídos localmente por quem chama) quando a conversa entra em
  /// modo de coleta de dados do lembrete.
  String? get primeiraFala => _primeiraFala;

  bool get atingiuLimiteDeTurnos => _turnos >= maxTurnos;

  bool get temDia => slotDia != null;
  bool get temHora => slotHora != null;

  /// Registra a primeira fala da conversa, se ainda não houver uma
  /// guardada (chamadas seguintes não sobrescrevem). Chamar no início de
  /// cada turno, antes de decidir o que fazer com o texto.
  void registrarPrimeiraFalaSeNecessario(String texto) {
    if (_historico.isEmpty && !coletandoLembrete) {
      _primeiraFala ??= texto;
    }
  }

  /// Conta mais um turno da conversa — chamar uma vez por fala do
  /// usuário processada (não por sub-turno de confirmação de risco, que
  /// faz parte de resolver o mesmo pedido).
  void avancarTurno() => _turnos++;

  /// Adiciona uma troca ao histórico, descartando a mais antiga se passar
  /// de [maxTrocas].
  void registrarTroca(String usuario, String assistente) {
    _historico.add(MollyMessage.usuario(usuario));
    _historico.add(MollyMessage.assistente(assistente));
    const limiteDeMensagens = maxTrocas * 2; // cada troca = 2 mensagens
    while (_historico.length > limiteDeMensagens) {
      _historico.removeAt(0);
    }
  }

  /// Histórico pronto para `AiCommandService.interpretar` — pares
  /// (usuário, assistente), nunca mais que [maxTrocas].
  List<ConversaTurno> get historicoParaIA {
    final turnos = <ConversaTurno>[];
    String? pendenteUsuario;
    for (final m in _historico) {
      if (m.autor == MollyAutor.usuario) {
        pendenteUsuario = m.texto;
      } else if (pendenteUsuario != null) {
        turnos.add(ConversaTurno(pendenteUsuario, m.texto));
        pendenteUsuario = null;
      }
    }
    return turnos;
  }

  /// Mescla dia/hora já reconhecidos no estado de coleta, sem sobrescrever
  /// o que já tiver sido confirmado antes. A extração de texto em si
  /// (regex de data/hora) continua fora desta classe — é responsabilidade
  /// de um parser (hoje em `elderly_screen.dart`, futuramente
  /// `OfflineIntentService`, TAREFA 17); esta classe só guarda o
  /// resultado já interpretado.
  void mesclarSlots({
    required ({int dia, int mes, int ano})? data,
    required ({int hora, int minuto})? hora,
  }) {
    if (data != null) {
      slotDia = data.dia;
      slotMes = data.mes;
      slotAno = data.ano;
    }
    if (hora != null) {
      slotHora = hora.hora;
      slotMinuto = hora.minuto;
    }
  }

  /// Reseta tudo — chamar ao encerrar a conversa (frase de encerramento,
  /// silêncio, limite de turnos, toque manual, ou SOCORRO).
  void encerrar() {
    _historico.clear();
    _turnos = 0;
    _primeiraFala = null;
    coletandoLembrete = false;
    slotDia = slotMes = slotAno = null;
    slotHora = slotMinuto = null;
  }
}
