import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'molly_safety_service.dart';
import 'molly_tool_registry.dart';
import 'offline_intent_service.dart';

/// Eventos da Molly (TAREFA 27 do prompt mestre). Lista fechada — nada de
/// nome de evento montado na hora.
enum MollyEvento {
  started('molly_started'),
  voiceUsed('molly_voice_used'),
  textUsed('molly_text_used'),
  toolExecuted('molly_tool_executed'),
  error('molly_error'),
  offlineCommand('molly_offline_command'),
  localReminder('molly_local_reminder'),
  aiUsed('molly_ai_used'),
  safetyBlock('molly_safety_block'),
  interrupted('molly_interrupted');

  final String nome;
  const MollyEvento(this.nome);
}

/// Telemetria da Molly: só contagem de uso, **nunca conteúdo**.
///
/// O resto do código chama só esta classe — trocar o Firebase Analytics por
/// outra coisa muda um arquivo. Regra central da tarefa ("nunca registrar
/// conversa completa"), garantida aqui e não na boa vontade de quem chama:
/// cada parâmetro só aceita valores de uma **lista fechada** (nome de
/// ferramenta do catálogo, comando offline, ação da IA, códigos fixos) ou
/// sim/não. Qualquer outra coisa — frase, nome de remédio, e até um nome
/// solto como "Ana" — é descartada (`test/molly_telemetria_test.dart`).
///
/// Build de desenvolvimento (debug) não envia nada, pra não misturar teste
/// com uso real. Sem ID de publicidade (AndroidManifest.xml).
class MollyTelemetria {
  /// Ações do backend (`ACOES_VALIDAS` em server/ai_command_server/app.py).
  static const _acoesDaIA = {
    'criar_lembrete', 'ouvir_lembretes', 'adicionar_item_lista', 'consultar_alertas', 'perguntar', 'responder',
  };
  static const _tiposDeErro = {'sem_ia', 'microfone', 'microfone_indisponivel', 'nao_ouviu'};

  static bool _valorPermitido(String chave, String valor) => switch (chave) {
        'ferramenta' => MollyToolRegistry.buscar(valor) != null,
        'comando' => OfflineIntent.values.any((i) => i.name == valor),
        'acao' => _acoesDaIA.contains(valor),
        'tipo' => _tiposDeErro.contains(valor) || MollySafetyIntent.values.any((i) => i.name == valor),
        'origem' => valor == 'tela' || valor == 'atalho',
        'modo' => valor == 'voz' || valor == 'toque',
        'resultado' => valor == 'criado' || valor == 'pergunta_hora',
        _ => false,
      };

  /// Parâmetros sim/não (os únicos não-texto).
  static const _chavesSimNao = {'sucesso', 'confirmada'};

  /// Nos testes, recebe o que seria enviado (e nada vai ao Firebase).
  @visibleForTesting
  static void Function(String evento, Map<String, Object> parametros)? capturarParaTeste;

  /// Liga/desliga a coleta automática do SDK (abertura do app etc.) junto
  /// com a nossa: debug nunca coleta. Chamado uma vez no `main()`.
  static Future<void> iniciar() async {
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(!kDebugMode);
    } catch (_) {}
  }

  static void registrar(MollyEvento evento, [Map<String, Object?> parametros = const {}]) {
    final limpos = limparParametros(parametros);
    final captura = capturarParaTeste;
    if (captura != null) {
      captura(evento.nome, limpos);
      return;
    }
    if (kDebugMode) return;
    // Nunca espera nem lança: telemetria não pode atrasar nem quebrar a Molly.
    unawaited(_enviar(evento.nome, limpos));
  }

  static Future<void> _enviar(String nome, Map<String, Object> parametros) async {
    try {
      await FirebaseAnalytics.instance.logEvent(name: nome, parameters: parametros.isEmpty ? null : parametros);
    } catch (_) {}
  }

  /// Só valores da lista fechada de cada parâmetro (ou sim/não); o resto é
  /// descartado.
  @visibleForTesting
  static Map<String, Object> limparParametros(Map<String, Object?> parametros) {
    final saida = <String, Object>{};
    parametros.forEach((chave, valor) {
      if (valor is bool && _chavesSimNao.contains(chave)) {
        saida[chave] = valor ? 'sim' : 'nao';
      } else if (valor is String && _valorPermitido(chave, valor)) {
        saida[chave] = valor;
      }
    });
    return saida;
  }
}
