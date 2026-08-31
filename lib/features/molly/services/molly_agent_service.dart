import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/reminder.dart';
import '../../../services/ai_command_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/reminder_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/sos_feed_service.dart';
import '../memory/short_term_memory.dart';
import '../models/molly_tool_result.dart';
import '../tools/molly_fala_utils.dart';
import 'molly_risk_policy.dart';
import 'offline_intent_service.dart';

/// Núcleo da MOLLY (TAREFA 2 do prompt mestre — ver
/// `docs/MOLLY_ARCHITECTURE_ANALYSIS.md`).
///
/// Recebe texto já transcrito (voz ou digitado). Primeiro tenta
/// [OfflineIntentService] (TAREFA 17) — comandos críticos que nunca
/// devem depender da IA (SOCORRO, "meus lembretes", "ligar para X", "que
/// horas são", "confirmar remédio"). Só se nada bater localmente é que
/// chama o backend de IA existente (`AiCommandService`, que já fala com
/// a Groq via VPS) e despacha a ação estruturada devolvida para
/// [MollyRiskPolicy] (TAREFA 3/4), que decide se executa direto ou pede
/// confirmação antes, e só então delega ao `MollyToolRegistry` — nunca
/// para o Firestore diretamente. Se a IA não responder, devolve um
/// resultado sinalizando isso.
///
/// `consultar_alertas` e `adicionar_item_lista` ainda são resolvidos aqui
/// dentro, não pelo registro de ferramentas: a TAREFA 3 do prompt mestre
/// não as lista no catálogo inicial de ferramentas, então formalizá-las
/// como `MollyToolDefinition` fica para quando isso for pedido
/// explicitamente, para não inflar o escopo desta tarefa.
///
/// **Gatilho de memória de longo prazo (sessão 24):** a IA pode sugerir,
/// junto de qualquer ação, uma preferência durável do usuário pra lembrar
/// (`ComandoAction.memoriaTipo`/`memoriaValor`). [processar] só repassa
/// essa sugestão adiante (via `MollyToolResult.comPropostaDeMemoria`) se
/// `SettingsService.getMollyMemoriaAutorizada()` estiver ligado — do
/// contrário descarta em silêncio, sem nunca perguntar nada. Mesmo com o
/// interruptor ligado, isto aqui NUNCA grava sozinho: quem chama precisa
/// perguntar em voz alta e ouvir um "sim" antes de chamar
/// `LongTermMemoryService.salvar()` (dupla trava da TAREFA 8/9).
///
/// Importante: esta classe **porta**, mas não substitui ainda, a lógica
/// hoje embutida em `elderly_screen.dart`. Trocar aquele código por
/// chamadas a este serviço é um passo separado e deliberado (ver plano de
/// migração no documento de análise), testado no aparelho físico antes de
/// remover a versão antiga — não é feito nesta tarefa.
///
/// A classe em si continua sem estado próprio (tudo estático): quem guarda
/// o estado entre turnos é o [ShortTermMemory] (TAREFA 7) que o chamador
/// passa em [processar] — este núcleo só lê e atualiza essa memória, nunca
/// a possui. A máquina de estados de conversa mais ampla (quando encerrar
/// por frase/silêncio, coleta de dia/hora com parser local) continua
/// sendo responsabilidade de uma camada de controller futura
/// (`molly_controller.dart`), não deste núcleo.
class MollyAgentService {
  /// Processa um turno da conversa. [texto] já deve vir transcrito (o
  /// STT/voz é responsabilidade de `MollyVoiceService`). [memoria], se
  /// fornecida, dá continuidade à conversa: seu histórico é mandado à IA
  /// para perguntas em linguagem natural que se referem a algo dito antes
  /// (ex.: "quando é minha consulta?" → "me lembra duas horas antes"), e a
  /// troca resultante é registrada nela automaticamente ao final — quem
  /// chama não precisa lembrar de atualizar a memória manualmente.
  /// [lembretesContexto] é o resumo leve dos lembretes reais do usuário —
  /// nunca o documento completo do Firestore — usado para grounding
  /// contra alucinação. Normalmente vem de
  /// `MollyContextService.montar().lembretesParaIA` (TAREFA 10), que já
  /// aplica o mesmo filtro/formato.
  static Future<MollyToolResult> processar({
    required String texto,
    ShortTermMemory? memoria,
    List<Map<String, dynamic>> lembretesContexto = const [],
  }) async {
    final textoLimpo = texto.trim();
    if (textoLimpo.isEmpty) {
      return MollyToolResult.esclarecimento('Não entendi. Pode repetir?');
    }

    // TAREFA 17: comandos críticos locais têm prioridade e nunca passam
    // pela IA — nem quando ela está disponível (mesmo fluxo pedido pelo
    // prompt mestre: detecção local primeiro, IA só se nada bater).
    final resultadoOffline = await OfflineIntentService.tentar(textoLimpo);
    if (resultadoOffline != null) {
      memoria?.registrarTroca(textoLimpo, resultadoOffline.fala);
      return resultadoOffline;
    }

    final acao = await AiCommandService.interpretar(
      textoLimpo,
      historico: memoria?.historicoParaIA ?? const [],
      lembretesContexto: lembretesContexto,
    );

    if (acao == null) {
      return MollyToolResult.semIA();
    }

    final resultado = await _executar(acao, memoria: memoria);
    memoria?.registrarTroca(textoLimpo, resultado.fala);

    // Proposta de memória de longo prazo (sessão 24): campo independente
    // de "acao" — a IA pode sugerir junto de qualquer outra resposta.
    // Checado aqui, e só aqui, se o interruptor geral "A Molly pode
    // lembrar minhas preferências?" está ligado — se não estiver, a
    // proposta é descartada em silêncio, sem nunca chegar a perguntar
    // nada ao usuário (mesmo espírito de `LongTermMemoryService.salvar`,
    // que também confere esse mesmo interruptor antes de gravar).
    if (acao.memoriaTipo != null &&
        acao.memoriaValor != null &&
        await SettingsService.getMollyMemoriaAutorizada()) {
      return resultado.comPropostaDeMemoria(
        tipo: acao.memoriaTipo!,
        valor: acao.memoriaValor!,
        confianca: acao.memoriaConfianca ?? 0.7,
      );
    }
    return resultado;
  }

  static Future<MollyToolResult> _executar(ComandoAction acao, {ShortTermMemory? memoria}) async {
    switch (acao.acao) {
      case 'ouvir_lembretes':
        return MollyRiskPolicy.executar('getTodayReminders', const {});
      case 'consultar_alertas':
        return _falarResumoAlertas();
      case 'adicionar_item_lista':
        return _adicionarItensNaLista(acao.itens);
      case 'criar_lembrete':
        final titulo =
            (acao.titulo?.trim().isNotEmpty ?? false) ? acao.titulo!.trim() : 'Lembrete';
        // createReminder é MEDIUM: por ora sempre roda direto (ambiguo:
        // false) porque, ao chegar aqui, a própria IA já decidiu que tinha
        // dado suficiente (senão a ação teria sido 'perguntar'). Se um dia
        // este dispatch ganhar um sinal de ambiguidade próprio, basta
        // repassá-lo para `ambiguo` — a política já sabe o que fazer com
        // ele.
        return MollyRiskPolicy.executar('createReminder', {
          'titulo': titulo,
          'dataHora': acao.dataHora ?? DateTime.now().add(const Duration(minutes: 1)),
          'tipo': acao.tipo,
          'recorrencia': acao.recorrencia,
        });
      case 'perguntar':
        // A IA pediu esclarecimento — marca a memória para que o próximo
        // turno vire coleta local determinística de dia/hora (achado da
        // sessão 22: a IA "esquece" dado estruturado entre turnos). Os
        // extratores de data/hora em si (`_extrairData`/`_extrairHora`)
        // ainda moram só em `elderly_screen.dart` — a TAREFA 17
        // (`OfflineIntentService`) cobriu os cinco comandos críticos do
        // prompt mestre, não esses parsers; quem chama [processar] hoje
        // sem checar `memoria.coletandoLembrete` antes de novo turno só
        // volta a chamar a IA, sem esse atalho local.
        memoria?.coletandoLembrete = true;
        return MollyToolResult.esclarecimento(acao.fala);
      case 'responder':
      default:
        return MollyToolResult.sucesso(
          acao.fala.isNotEmpty ? acao.fala : 'Não entendi. Pode repetir?',
        );
    }
  }

  static Future<MollyToolResult> _falarResumoAlertas() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return MollyToolResult.sucesso(
        'Não consegui verificar seus alertas agora.',
        acao: 'consultar_alertas',
      );
    }
    final alertas = await SosFeedService.streamOwnAlerts(uid).first;
    if (alertas.isEmpty) {
      return MollyToolResult.sucesso(
        'Você não tem nenhum alerta de SOS registrado.',
        acao: 'consultar_alertas',
      );
    }
    final total = alertas.length;
    final ultimo = alertas.first;
    final visto = ultimo.viewedBy.length;
    final agora = DateTime.now();
    final dt = ultimo.createdAt;
    final quandoStr = dt == null
        ? 'agora há pouco'
        : (dt.year == agora.year && dt.month == agora.month && dt.day == agora.day)
            ? 'hoje às ${horaFalada(dt)}'
            : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} às ${horaFalada(dt)}';
    final vistoFrase =
        visto > 0 ? 'visto por $visto familiar${visto > 1 ? 'es' : ''}' : 'ainda não visto por ninguém';
    final qtdFrase = total == 1
        ? 'Você tem 1 alerta de SOS registrado.'
        : 'Você tem $total alertas de SOS registrados.';
    return MollyToolResult.sucesso(
      '$qtdFrase O mais recente foi $quandoStr, $vistoFrase.',
      acao: 'consultar_alertas',
    );
  }

  /// Adiciona item(ns) a um lembrete de Compras existente, ou cria um novo
  /// card — mesma regra de `elderly_screen.dart`: procura só pelo tipo
  /// exato `'Compras'`, nunca por texto solto no título.
  static Future<MollyToolResult> _adicionarItensNaLista(List<String> novosItens) async {
    if (novosItens.isEmpty) {
      return MollyToolResult.sucesso(
        'Não entendi o item. Tente novamente.',
        acao: 'adicionar_item_lista',
      );
    }

    // Herdado de elderly_screen.dart: defesa contra chamar este fluxo sem
    // sessão ativa. Não deveria acontecer no caminho normal do app (é
    // preciso logar antes de chegar à tela do idoso), mantido por
    // fidelidade ao comportamento original — não é uma decisão nova desta
    // tarefa.
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final perfil = await ProfileService.getProfile() ?? '';

    final todos = await ReminderService.getAll();
    Reminder? listaExistente;
    for (final r in todos) {
      if (r.type == 'Compras') {
        listaExistente = r;
        break;
      }
    }

    if (listaExistente != null) {
      final itensAtuais = listaExistente.description.trim().isNotEmpty
          ? listaExistente.description
              .trim()
              .split('\n')
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];
      final tudo = [...itensAtuais, ...novosItens];
      await ReminderService.update(listaExistente.copyWith(description: tudo.join('\n')));
    } else {
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
    return MollyToolResult.sucesso(confirmacao, acao: 'adicionar_item_lista');
  }
}
