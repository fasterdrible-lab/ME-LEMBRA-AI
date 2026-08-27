import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/reminder.dart';
import '../../../services/notification_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/reminder_service.dart';
import '../models/molly_risk_level.dart';
import '../models/molly_tool_definition.dart';
import '../models/molly_tool_result.dart';
import '../services/molly_prompt_service.dart';
import 'molly_fala_utils.dart';

/// Ferramentas de lembretes da MOLLY (TAREFA 3 do prompt mestre) —
/// wrappers finos sobre `ReminderService`/`NotificationService`, os únicos
/// pontos que falam com o Firestore/notificações locais.
class ReminderTool {
  static const _tiposValidos = {
    'Remedio', 'Consulta', 'Aniversario', 'Mercado', 'Reuniao', 'Tomar', 'Compras', 'Lembrete',
  };
  static const _recorrenciasValidas = {'unico', 'diario', 'semanal'};
  static const _tipoLabels = {
    'Remedio': 'de remédio',
    'Consulta': 'de consulta',
    'Aniversario': 'de aniversário',
    'Mercado': 'de mercado',
    'Reuniao': 'de evento',
    'Tomar': 'de tomar',
  };

  static const MollyToolDefinition createReminder = MollyToolDefinition(
    nome: 'createReminder',
    descricao: 'Cria um novo lembrete (remédio, consulta, aniversário, etc.).',
    risco: MollyRiskLevel.medium,
    parametros: [
      MollyToolParam(nome: 'titulo', tipo: 'string', descricao: 'Título curto do lembrete.'),
      MollyToolParam(nome: 'dataHora', tipo: 'datetime', descricao: 'Data/hora do lembrete (DateTime ou ISO 8601).'),
      MollyToolParam(
        nome: 'tipo',
        tipo: 'string',
        obrigatorio: false,
        descricao: 'Remedio, Consulta, Aniversario, Mercado, Reuniao, Tomar ou Compras.',
      ),
      MollyToolParam(nome: 'recorrencia', tipo: 'string', obrigatorio: false, descricao: 'unico, diario ou semanal.'),
      MollyToolParam(nome: 'descricao', tipo: 'string', obrigatorio: false),
    ],
    executar: _createReminder,
  );

  static Future<MollyToolResult> _createReminder(Map<String, dynamic> p) async {
    final titulo = (p['titulo'] as String).trim();
    final dataHora = _lerDataHora(p['dataHora']);
    if (dataHora == null) {
      return MollyToolResult.falha('Não entendi a data ou hora do lembrete.', acao: 'createReminder');
    }
    final tipoRaw = (p['tipo'] as String?)?.trim();
    final tipo = (tipoRaw != null && _tiposValidos.contains(tipoRaw)) ? tipoRaw : 'Lembrete';
    final recorrenciaRaw = (p['recorrencia'] as String?)?.trim();
    final recorrencia =
        (recorrenciaRaw != null && _recorrenciasValidas.contains(recorrenciaRaw)) ? recorrenciaRaw : 'unico';
    final descricao = (p['descricao'] as String?)?.trim() ?? '';

    if (FirebaseAuth.instance.currentUser == null) {
      return MollyToolResult.falha('Você precisa estar conectado para criar um lembrete.', acao: 'createReminder');
    }

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final perfil = await ProfileService.getProfile() ?? '';

      final reminder = Reminder(
        id: '',
        userId: userId,
        title: titulo,
        type: tipo,
        description: descricao,
        dateTime: dataHora,
        repeat: recorrencia,
        notification: '',
        perfil: perfil,
      );
      await ReminderService.add(reminder);
      await _agendarNotificacao(titulo: titulo, tipo: tipo, dataHora: dataHora, recorrencia: recorrencia);

      final diaStr = dataHora.day.toString().padLeft(2, '0');
      final mesStr = dataHora.month.toString().padLeft(2, '0');
      final repeatFrase = recorrencia == 'diario'
          ? ', todo dia'
          : recorrencia == 'semanal'
              ? ', toda semana'
              : ', para $diaStr de $mesStr';
      final tipoFrase = _tipoLabels[tipo] != null ? '${_tipoLabels[tipo]} ' : '';
      return MollyToolResult.sucesso(
        'Lembrete ${tipoFrase}criado: $titulo$repeatFrase às ${horaFalada(dataHora)}.',
        acao: 'createReminder',
      );
    } catch (_) {
      return MollyToolResult.falha('Não consegui salvar o lembrete.', acao: 'createReminder');
    }
  }

  static Future<void> _agendarNotificacao({
    required String titulo,
    required String tipo,
    required DateTime dataHora,
    required String recorrencia,
  }) async {
    final notifId =
        (titulo.hashCode ^ dataHora.millisecondsSinceEpoch).remainder(2147483647).abs();
    if (recorrencia != 'unico') {
      await NotificationService.scheduleRepeatingReminder(
        id: notifId,
        title: tipo,
        body: titulo,
        scheduledDate: dataHora,
        repeat: recorrencia,
      );
    } else {
      await NotificationService.scheduleReminder(
        id: notifId,
        title: tipo,
        body: titulo,
        scheduledDate: dataHora,
      );
    }
  }

  static final MollyToolDefinition getTodayReminders = MollyToolDefinition(
    nome: 'getTodayReminders',
    descricao: 'Lista os lembretes do usuário para hoje.',
    risco: MollyRiskLevel.low,
    parametros: const [],
    executar: (_) => _remindersDoDia(
      DateTime.now(),
      acao: 'getTodayReminders',
      semLembretesFrase: 'Você não tem lembretes para hoje.',
    ),
  );

  static final MollyToolDefinition getTomorrowReminders = MollyToolDefinition(
    nome: 'getTomorrowReminders',
    descricao: 'Lista os lembretes do usuário para amanhã.',
    risco: MollyRiskLevel.low,
    parametros: const [],
    executar: (_) => _remindersDoDia(
      DateTime.now().add(const Duration(days: 1)),
      acao: 'getTomorrowReminders',
      semLembretesFrase: 'Você não tem lembretes para amanhã.',
    ),
  );

  static Future<MollyToolResult> _remindersDoDia(
    DateTime referencia, {
    required String acao,
    required String semLembretesFrase,
  }) async {
    final lembretes = await ReminderService.getAll();
    final doDia = lembretes
        .where((r) =>
            r.dateTime.year == referencia.year &&
            r.dateTime.month == referencia.month &&
            r.dateTime.day == referencia.day)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (doDia.isEmpty) {
      return MollyToolResult.sucesso(semLembretesFrase, acao: acao);
    }
    // TAREFA 12 do prompt mestre: resposta em 1-3 frases, nunca lendo os
    // lembretes item por item (isso já foi uma "lista extensa falada" com
    // muitos lembretes — corrigido aqui). A lista completa continua
    // disponível em `dados['lembretes']` pra quem quiser mostrar na tela.
    final fala = MollyPromptService.resumoCurto<Reminder>(
      itens: doDia,
      nomeSingular: 'lembrete',
      nomePlural: 'lembretes',
      descrever: (r) => '${r.title.isNotEmpty ? r.title : r.type}, às ${horaFalada(r.dateTime)}',
    );
    return MollyToolResult.sucesso(fala, acao: acao, dados: {'lembretes': doDia});
  }

  static const MollyToolDefinition updateReminder = MollyToolDefinition(
    nome: 'updateReminder',
    descricao: 'Altera um lembrete já existente (título, data/hora, tipo ou recorrência).',
    risco: MollyRiskLevel.medium,
    parametros: [
      MollyToolParam(nome: 'id', tipo: 'string', descricao: 'ID do lembrete a alterar.'),
      MollyToolParam(nome: 'titulo', tipo: 'string', obrigatorio: false),
      MollyToolParam(nome: 'dataHora', tipo: 'datetime', obrigatorio: false),
      MollyToolParam(nome: 'tipo', tipo: 'string', obrigatorio: false),
      MollyToolParam(nome: 'recorrencia', tipo: 'string', obrigatorio: false),
      MollyToolParam(nome: 'descricao', tipo: 'string', obrigatorio: false),
    ],
    executar: _updateReminder,
  );

  static Future<MollyToolResult> _updateReminder(Map<String, dynamic> p) async {
    final id = (p['id'] as String).trim();
    final todos = await ReminderService.getAll();
    Reminder? atual;
    for (final r in todos) {
      if (r.id == id) {
        atual = r;
        break;
      }
    }
    if (atual == null) {
      return MollyToolResult.falha('Não encontrei esse lembrete.', acao: 'updateReminder');
    }

    DateTime? novaDataHora;
    if (p['dataHora'] != null) {
      novaDataHora = _lerDataHora(p['dataHora']);
      if (novaDataHora == null) {
        return MollyToolResult.falha('Não entendi a nova data ou hora.', acao: 'updateReminder');
      }
    }
    final novoTipoRaw = (p['tipo'] as String?)?.trim();
    final novoTipo = (novoTipoRaw != null && _tiposValidos.contains(novoTipoRaw)) ? novoTipoRaw : null;
    final novaRecorrenciaRaw = (p['recorrencia'] as String?)?.trim();
    final novaRecorrencia =
        (novaRecorrenciaRaw != null && _recorrenciasValidas.contains(novaRecorrenciaRaw)) ? novaRecorrenciaRaw : null;
    final novoTitulo = (p['titulo'] as String?)?.trim();
    final novaDescricao = (p['descricao'] as String?)?.trim();

    final atualizado = atual.copyWith(
      title: (novoTitulo != null && novoTitulo.isNotEmpty) ? novoTitulo : null,
      dateTime: novaDataHora,
      type: novoTipo,
      repeat: novaRecorrencia,
      description: novaDescricao,
    );
    try {
      await ReminderService.update(atualizado);
      return MollyToolResult.sucesso('Lembrete atualizado.', acao: 'updateReminder');
    } catch (_) {
      return MollyToolResult.falha('Não consegui atualizar o lembrete.', acao: 'updateReminder');
    }
  }

  static const MollyToolDefinition deleteReminder = MollyToolDefinition(
    nome: 'deleteReminder',
    descricao: 'Exclui definitivamente um lembrete do usuário.',
    // CRITICAL: exclusão é irreversível — mais perto de "apagar dados
    // sensíveis" (TAREFA 4) do que de "alterar lembrete" (MEDIUM). Um
    // pedido de exclusão em massa por voz (cenário de teste da TAREFA 29,
    // "exclua todos os meus lembretes") nunca deve rodar sem confirmação
    // explícita — a política de "sempre confirmar" do CRITICAL cobre isso.
    risco: MollyRiskLevel.critical,
    parametros: [
      MollyToolParam(nome: 'id', tipo: 'string', descricao: 'ID do lembrete a excluir.'),
    ],
    executar: _deleteReminder,
  );

  static Future<MollyToolResult> _deleteReminder(Map<String, dynamic> p) async {
    final id = (p['id'] as String).trim();
    try {
      await ReminderService.delete(id);
      return MollyToolResult.sucesso('Lembrete excluído.', acao: 'deleteReminder');
    } catch (_) {
      return MollyToolResult.falha('Não consegui excluir esse lembrete.', acao: 'deleteReminder');
    }
  }

  static const MollyToolDefinition confirmReminder = MollyToolDefinition(
    nome: 'confirmReminder',
    descricao: 'Marca um lembrete como feito (ex.: remédio tomado) e avisa a família.',
    risco: MollyRiskLevel.medium,
    parametros: [
      MollyToolParam(nome: 'id', tipo: 'string', descricao: 'ID do lembrete a confirmar.'),
    ],
    executar: _confirmReminder,
  );

  static Future<MollyToolResult> _confirmReminder(Map<String, dynamic> p) async {
    final id = (p['id'] as String).trim();
    try {
      await ReminderService.confirm(id);
      return MollyToolResult.sucesso('Lembrete confirmado.', acao: 'confirmReminder');
    } catch (_) {
      return MollyToolResult.falha('Não consegui confirmar esse lembrete.', acao: 'confirmReminder');
    }
  }

  static const MollyToolDefinition getReminderHistory = MollyToolDefinition(
    nome: 'getReminderHistory',
    descricao: 'Lista os lembretes confirmados (feitos) nos últimos dias.',
    risco: MollyRiskLevel.low,
    parametros: [
      MollyToolParam(nome: 'dias', tipo: 'int', obrigatorio: false, descricao: 'Quantos dias olhar para trás (padrão 30).'),
    ],
    executar: _getReminderHistory,
  );

  static Future<MollyToolResult> _getReminderHistory(Map<String, dynamic> p) async {
    final dias = (p['dias'] as int?) ?? 30;
    final limite = DateTime.now().subtract(Duration(days: dias));
    final todos = await ReminderService.getAll();
    final confirmados = todos.where((r) => r.confirmed && r.dateTime.isAfter(limite)).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    if (confirmados.isEmpty) {
      return MollyToolResult.sucesso(
        'Não encontrei lembretes confirmados nos últimos $dias dias.',
        acao: 'getReminderHistory',
      );
    }
    final qtd = confirmados.length;
    final resumo = qtd == 1
        ? 'Você confirmou 1 lembrete nos últimos $dias dias.'
        : 'Você confirmou $qtd lembretes nos últimos $dias dias.';
    return MollyToolResult.sucesso(resumo, acao: 'getReminderHistory', dados: {'lembretes': confirmados});
  }

  static DateTime? _lerDataHora(dynamic valor) {
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }
}
