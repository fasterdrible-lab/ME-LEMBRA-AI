import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Ação estruturada devolvida pelo backend de comando de voz por IA.
class ComandoAction {
  final String acao;
  final String? titulo;
  final String? tipo;
  final DateTime? dataHora;
  final String? recorrencia;
  final List<String> itens;
  final String fala;

  const ComandoAction({
    required this.acao,
    this.titulo,
    this.tipo,
    this.dataHora,
    this.recorrencia,
    this.itens = const [],
    this.fala = '',
  });

  factory ComandoAction.fromJson(Map<String, dynamic> json) {
    final dataHoraStr = json['data_hora'] as String?;
    return ComandoAction(
      acao: json['acao'] as String? ?? 'responder',
      titulo: json['titulo'] as String?,
      tipo: json['tipo'] as String?,
      dataHora: dataHoraStr != null ? DateTime.tryParse(dataHoraStr) : null,
      recorrencia: json['recorrencia'] as String?,
      itens: (json['itens'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      fala: json['fala'] as String? ?? '',
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
  // TODO: trocar pelo domínio real da VPS depois de configurar o DNS e o
  // certificado HTTPS (ver docs/ARCHITECTURE.md, seção "Backend de comando
  // de voz por IA"). Sem isso, o serviço sempre retorna null (fallback local).
  static const String _baseUrl = 'https://SEU_DOMINIO_AQUI';

  static Future<ComandoAction?> interpretar(String texto) async {
    if (_baseUrl.contains('SEU_DOMINIO_AQUI')) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final idToken = await user.getIdToken();

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
              },
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ComandoAction.fromJson(json);
    } catch (_) {
      // Sem internet, timeout, backend fora do ar, etc. — cai no fallback local.
      return null;
    }
  }
}
