import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  static const _keyPerfil = 'perfil';

  static User? get _currentUser => FirebaseAuth.instance.currentUser;

  static DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  static Future<void> saveProfile(String perfil) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPerfil, perfil);
    final doc = _userDoc;
    if (doc != null) {
      await doc.set({'perfil': perfil}, SetOptions(merge: true));
    }
  }

  /// Sessão 24: o perfil antes rotulado "Vovô / Vovó" passou a se chamar
  /// "Melhor Idade" em toda a interface. Contas que já tinham o valor
  /// antigo salvo (Firestore ou SharedPreferences) continuam funcionando
  /// sem precisar escolher o perfil de novo — mesmo espírito da migração
  /// transparente já usada para o campo legado `cfg_sos_numero`
  /// (`settings_service.dart`). O valor armazenado só passa a ser gravado
  /// como "Melhor Idade" na próxima escrita (`saveProfile`); esta função
  /// só normaliza o que é lido.
  static const _perfilIdosoAntigo = 'Vovô / Vovó';
  static const _perfilIdosoAtual = 'Melhor Idade';

  static String _normalizarPerfil(String perfil) =>
      perfil == _perfilIdosoAntigo ? _perfilIdosoAtual : perfil;

  static Future<String?> getProfile() async {
    final doc = _userDoc;
    if (doc != null) {
      try {
        final snapshot = await doc.get();
        final data = snapshot.data();
        if (data != null && data['perfil'] is String) {
          return _normalizarPerfil(data['perfil'] as String);
        }
      } catch (_) {
        // Firestore indisponível — usa SharedPreferences como fallback
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString(_keyPerfil);
    return salvo == null ? null : _normalizarPerfil(salvo);
  }

  // Chave derivada do perfil, ex: "nome_Adulto"
  static String _nameKey(String perfil) => 'nome_$perfil';

  static Future<void> saveNameForProfile(String perfil, String nome) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey(perfil), nome);
    final doc = _userDoc;
    if (doc != null) {
      // Armazena perfil e nome juntos para manter consistência no Firestore
      await doc.set({'perfil': perfil, 'nome': nome}, SetOptions(merge: true));
    }
  }

  static Future<String?> getNameForProfile(String perfil) async {
    final doc = _userDoc;
    if (doc != null) {
      try {
        final snapshot = await doc.get();
        final data = snapshot.data();
        // Retorna o nome do Firestore somente se o perfil armazenado corresponde
        // ao solicitado — normaliza o valor armazenado antes de comparar, pra uma
        // conta legada ("Vovô / Vovó" no Firestore) continuar achando o nome já
        // salvo quando consultada com o rótulo atual ("Melhor Idade").
        if (data != null &&
            data['perfil'] is String &&
            _normalizarPerfil(data['perfil'] as String) == perfil &&
            data['nome'] is String) {
          return data['nome'] as String;
        }
      } catch (_) {
        // Firestore indisponível — usa SharedPreferences como fallback
      }
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey(perfil));
  }

  /// Retorna o nome salvo para o perfil atualmente selecionado (ou null).
  static Future<String?> getNameForSelectedProfile() async {
    final perfil = await getProfile();
    if (perfil == null) return null;
    return getNameForProfile(perfil);
  }
}