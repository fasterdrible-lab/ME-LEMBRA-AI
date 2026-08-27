import 'package:cloud_firestore/cloud_firestore.dart';

/// Uma memória de longo prazo da MOLLY sobre o usuário, persistida em
/// `users/{uid}/molly_memory/{id}` (TAREFA 8 do prompt mestre).
///
/// Exemplos de [type]: `nome_preferido`, `familiares`, `horario_almoco`,
/// `horario_cafe`, `preferencia_de_voz`, `preferencia_de_lembrete`,
/// `rotinas` — o prompt mestre dá esses como exemplo, não como enum
/// fechado; novas categorias podem aparecer sem exigir migração de schema.
///
/// [userApproved] é sempre `true` para qualquer registro que exista no
/// Firestore — `LongTermMemoryService.salvar()` recusa gravar quando
/// `false` (nunca salva por padrão, nunca por engano). O campo continua
/// no modelo/documento mesmo assim, por transparência: quem olha a tela
/// "O que a Molly lembra" (TAREFA 9) precisa poder confirmar que cada
/// memória foi de fato autorizada, não inferir isso pela mera existência
/// do documento.
class MollyMemoryEntry {
  final String id;
  final String type;
  final String value;

  /// De onde essa memória veio — ex.: `conversa`, `configuracoes`.
  final String source;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 0.0–1.0: o quão confiante a origem estava sobre esse valor. Um valor
  /// baixo é um sinal para a TAREFA 9 destacar a memória para revisão do
  /// usuário, não um mecanismo de descarte automático.
  final double confidence;

  final bool userApproved;

  const MollyMemoryEntry({
    required this.id,
    required this.type,
    required this.value,
    required this.source,
    this.createdAt,
    this.updatedAt,
    this.confidence = 1.0,
    required this.userApproved,
  });

  factory MollyMemoryEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    DateTime? paraData(dynamic v) => v is Timestamp ? v.toDate() : null;
    return MollyMemoryEntry(
      id: doc.id,
      type: (data['type'] as String?) ?? '',
      value: (data['value'] as String?) ?? '',
      source: (data['source'] as String?) ?? '',
      createdAt: paraData(data['createdAt']),
      updatedAt: paraData(data['updatedAt']),
      confidence: ((data['confidence'] as num?) ?? 1.0).toDouble().clamp(0.0, 1.0),
      userApproved: (data['userApproved'] as bool?) ?? false,
    );
  }
}
