import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/family_member.dart';
import 'profile_service.dart';

/// Serviço de vínculos familiares.
///
/// Estrutura no Firestore:
/// - `users/{uid}` contém `inviteCode` (gerado sob demanda).
/// - `invites/{code}` mapeia código → uid do dono (busca rápida).
/// - `users/{uid}/family/{otherUid}` representa o vínculo bilateral.
class FamilyService {
  static final _db = FirebaseFirestore.instance;

  static User? get _user => FirebaseAuth.instance.currentUser;

  /// Retorna (gerando se necessário) o código de convite do usuário atual.
  static Future<String> getOrCreateInviteCode() async {
    final user = _user;
    if (user == null) throw StateError('Usuário não autenticado.');

    final userRef = _db.collection('users').doc(user.uid);
    final snap = await userRef.get();
    final data = snap.data();
    final existing = data?['inviteCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    final code = _generateCode();
    await userRef.set({'inviteCode': code}, SetOptions(merge: true));
    await _db.collection('invites').doc(code).set({
      'uid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  /// Vincula o usuário atual ao dono do [code]. O usuário atual passa a
  /// ser "cuidador" do dono do código (e o dono passa a ser "monitorado").
  static Future<FamilyMember> linkWithCode(String code) async {
    final user = _user;
    if (user == null) throw StateError('Usuário não autenticado.');
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) throw ArgumentError('Código vazio.');

    final inviteSnap = await _db.collection('invites').doc(normalized).get();
    final inviteData = inviteSnap.data();
    if (!inviteSnap.exists || inviteData == null) {
      throw Exception('Código inválido.');
    }
    final ownerUid = inviteData['uid'] as String?;
    if (ownerUid == null || ownerUid == user.uid) {
      throw Exception('Você não pode vincular a si mesmo.');
    }

    final ownerSnap = await _db.collection('users').doc(ownerUid).get();
    final ownerData = ownerSnap.data() ?? {};
    final ownerNome = (ownerData['nome'] as String?) ?? 'Familiar';
    final ownerPerfil = (ownerData['perfil'] as String?) ?? '';

    final selfPerfil = await ProfileService.getProfile() ?? '';
    final selfNome = await ProfileService.getNameForSelectedProfile() ?? 'Familiar';

    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();
    batch.set(
      _db.collection('users').doc(user.uid).collection('family').doc(ownerUid),
      {
        'nome': ownerNome,
        'perfil': ownerPerfil,
        'papel': 'monitorado',
        'vinculadoEm': now,
      },
    );
    batch.set(
      _db.collection('users').doc(ownerUid).collection('family').doc(user.uid),
      {
        'nome': selfNome,
        'perfil': selfPerfil,
        'papel': 'cuidador',
        'vinculadoEm': now,
      },
    );
    await batch.commit();

    return FamilyMember(
      uid: ownerUid,
      nome: ownerNome,
      perfil: ownerPerfil,
      papel: 'monitorado',
      vinculadoEm: DateTime.now(),
    );
  }

  /// Remove o vínculo bilateral.
  static Future<void> unlink(String otherUid) async {
    final user = _user;
    if (user == null) return;
    final batch = _db.batch();
    batch.delete(
      _db.collection('users').doc(user.uid).collection('family').doc(otherUid),
    );
    batch.delete(
      _db.collection('users').doc(otherUid).collection('family').doc(user.uid),
    );
    await batch.commit();
  }

  /// Stream de vínculos do usuário atual.
  static Stream<List<FamilyMember>> stream() {
    final user = _user;
    if (user == null) return Stream.value(const []);
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('family')
        .snapshots()
        .map((qs) => qs.docs
            .map((d) => FamilyMember.fromMap(d.id, d.data()))
            .toList());
  }

  /// Lista apenas os monitorados (idosos/crianças sob cuidado do atual).
  static Stream<List<FamilyMember>> streamMonitored() {
    return stream().map(
      (l) => l.where((m) => m.papel == 'monitorado').toList(),
    );
  }

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
