import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/settings_service.dart';
import '../models/molly_memory_entry.dart';

/// Memória de longo prazo da MOLLY (TAREFA 8 do prompt mestre).
///
/// Persistida em `users/{uid}/molly_memory/{id}` — diferente de
/// `ShortTermMemory` (TAREFA 7), que vive só durante uma conversa e nunca
/// toca o Firestore. Regra central, exigida explicitamente pelo prompt
/// mestre: **nunca salvar informação sensível automaticamente sem
/// autorização**. Isso é reforçado em duas camadas independentes:
///
/// 1. [salvar] recusa gravar qualquer coisa se [userApproved] não for
///    `true` — não há valor padrão que permita "esquecer" de passar isso.
/// 2. Mesmo com `userApproved: true`, também confere
///    `SettingsService.getMollyMemoriaAutorizada()` — o interruptor geral
///    "A MOLLY pode lembrar minhas preferências?" (TAREFA 9). Uma memória
///    individual autorizada não basta se o usuário desligou a memória por
///    completo depois.
///
/// A regra de segurança do Firestore (`firestore.rules`) restringe esta
/// coleção só ao dono — diferente de `reminders`, que a família também
/// pode ler. Preferências pessoais não são automaticamente algo que a
/// família deveria enxergar (ver `docs/MOLLY_ARCHITECTURE_ANALYSIS.md`,
/// risco 7).
class LongTermMemoryService {
  static final _db = FirebaseFirestore.instance;

  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _userId;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('molly_memory');
  }

  /// Grava uma memória nova. Devolve o ID do documento criado, ou `null`
  /// se a gravação foi recusada (sem autorização, em qualquer uma das
  /// duas camadas, ou sem usuário logado).
  static Future<String?> salvar({
    required String type,
    required String value,
    required String source,
    required bool userApproved,
    double confidence = 1.0,
  }) async {
    if (!userApproved) return null;
    if (!await SettingsService.getMollyMemoriaAutorizada()) return null;
    final col = _col;
    if (col == null) return null;
    if (type.trim().isEmpty || value.trim().isEmpty) return null;

    final doc = await col.add({
      'type': type.trim(),
      'value': value.trim(),
      'source': source.trim(),
      'confidence': confidence.clamp(0.0, 1.0),
      'userApproved': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Todas as memórias do usuário atual, mais recentes primeiro.
  static Stream<List<MollyMemoryEntry>> stream() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(MollyMemoryEntry.fromDoc).toList());
  }

  static Future<List<MollyMemoryEntry>> getAll() async {
    final col = _col;
    if (col == null) return const [];
    final snap = await col.orderBy('updatedAt', descending: true).get();
    return snap.docs.map(MollyMemoryEntry.fromDoc).toList();
  }

  /// Edita o valor de uma memória já existente (ex.: usuário corrigindo
  /// algo na tela "O que a Molly lembra", TAREFA 9). Não passa de novo
  /// pela checagem de autorização — editar uma memória que o usuário já
  /// aprovou é diferente de criar uma nova sem consentimento.
  static Future<void> atualizarValor(String id, String novoValor) async {
    final col = _col;
    if (col == null || id.isEmpty || novoValor.trim().isEmpty) return;
    await col.doc(id).update({
      'value': novoValor.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> excluir(String id) async {
    final col = _col;
    if (col == null || id.isEmpty) return;
    await col.doc(id).delete();
  }

  /// Apaga todas as memórias do usuário atual — usado pela opção "Apagar
  /// tudo" da tela "O que a Molly lembra" (TAREFA 9).
  static Future<void> excluirTudo() async {
    final col = _col;
    if (col == null) return;
    final snap = await col.get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
