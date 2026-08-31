import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Uma troca (usuário + assistente) já concluída na conversa atual.
/// Usada para dar memória de curto prazo ao backend de IA entre turnos.
class ConversaTurno {
  final String usuario;
  final String assistente;
  const ConversaTurno(this.usuario, this.assistente);
}

/// Ação estruturada devolvida pelo backend de comando de voz por IA.
class ComandoAction {
  final String acao;
  final String? titulo;
  final String? tipo;
  final DateTime? dataHora;
  final String? recorrencia;
  final List<String> itens;
  final String fala;

  /// Campo opcional e independente de [acao] — a IA pode sugerir que uma
  /// preferência durável do usuário (não algo pontual) vale a pena
  /// lembrar (ex.: "pode me chamar de Seu Antônio"). Sempre `null`/`null`
  /// juntos ou preenchidos juntos; [memoriaConfianca] vem em 0.0–1.0.
  /// Nunca é gravado sozinho — ver `MollyToolResult.comPropostaDeMemoria`
  /// e `LongTermMemoryService.salvar` (dupla trava de autorização).
  final String? memoriaTipo;
  final String? memoriaValor;
  final double? memoriaConfianca;

  const ComandoAction({
    required this.acao,
    this.titulo,
    this.tipo,
    this.dataHora,
    this.recorrencia,
    this.itens = const [],
    this.fala = '',
    this.memoriaTipo,
    this.memoriaValor,
    this.memoriaConfianca,
  });

  factory ComandoAction.fromJson(Map<String, dynamic> json) {
    final dataHoraStr = json['data_hora'] as String?;
    final memoria = json['memoria'];
    final memoriaTipo = memoria is Map ? memoria['tipo'] as String? : null;
    final memoriaValor = memoria is Map ? memoria['valor'] as String? : null;
    final memoriaConfiancaRaw = memoria is Map ? memoria['confianca'] : null;
    return ComandoAction(
      acao: json['acao'] as String? ?? 'responder',
      titulo: json['titulo'] as String?,
      tipo: json['tipo'] as String?,
      dataHora: dataHoraStr != null ? DateTime.tryParse(dataHoraStr) : null,
      recorrencia: json['recorrencia'] as String?,
      itens: (json['itens'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      fala: json['fala'] as String? ?? '',
      // Só considera a proposta válida se tipo E valor vierem preenchidos —
      // metade da informação não é o bastante pra perguntar nada ao usuário.
      memoriaTipo: (memoriaTipo != null && memoriaValor != null) ? memoriaTipo : null,
      memoriaValor: (memoriaTipo != null && memoriaValor != null) ? memoriaValor : null,
      memoriaConfianca:
          (memoriaTipo != null && memoriaValor != null) ? (memoriaConfiancaRaw as num?)?.toDouble() : null,
    );
  }
}

/// Interpreta comandos de voz livres através de um backend próprio (na VPS)
/// que chama a API da Groq. Usado como complemento ao roteador local de
/// `_processarComando` em elderly_screen.dart — quando a frase não bate em
/// nenhuma regra rápida local, tenta aqui antes de cair no parser padrão.
///
/// Se o backend estiver fora do ar, sem internet, ou demorar demais,
/// `interpretar` retorna `null` e quem chamou deve usar o fallback local.
class AiCommandService {
  // Backend na VPS Hetzner (204.168.180.25), atrás de nginx + Let's Encrypt.
  // Ver docs/CURRENT_STATE.md, seção "Backend de comando de voz por IA",
  // para o passo a passo de deploy (DNS, systemd, nginx, certbot).
  static const String _baseUrl = 'https://api.melbrai.com.br';

  static Future<ComandoAction?> interpretar(
    String texto, {
    List<ConversaTurno> historico = const [],
    List<Map<String, dynamic>> lembretesContexto = const [],
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final idToken = await user.getIdToken();

      // Defesa extra além do cap que quem chama já deve manter — nunca
      // manda mais que as últimas 3 trocas pro backend.
      final historicoLimitado = historico.length > 3
          ? historico.sublist(historico.length - 3)
          : historico;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/interpretar-comando'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'texto': texto,
              'contexto': {
                'agora': DateTime.now().toIso8601String(),
                'lembretes': lembretesContexto,
              },
              'historico': historicoLimitado
                  .map((t) => {'usuario': t.usuario, 'assistente': t.assistente})
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        debugPrint(
            'AiCommandService: backend respondeu ${response.statusCode} — '
            'caindo no parser local. Corpo: ${response.body}');
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ComandoAction.fromJson(json);
    } catch (e) {
      // Sem internet, timeout, backend fora do ar, certificado TLS
      // inválido, etc. — cai no fallback local. Logado para diagnóstico
      // (ver docs/CURRENT_STATE.md, seção do backend de IA).
      debugPrint('AiCommandService: falha ao interpretar comando ($e) — '
          'caindo no parser local.');
      return null;
    }
  }
}
