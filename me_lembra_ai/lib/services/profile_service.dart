import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const _keyPerfil = 'perfil';

  static Future<void> saveProfile(String perfil) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPerfil, perfil);
  }

  static Future<String?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPerfil);
  }

  // Chave derivada do perfil, ex: "nome_Adulto"
  static String _nameKey(String perfil) => 'nome_$perfil';

  static Future<void> saveNameForProfile(String perfil, String nome) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey(perfil), nome);
  }

  static Future<String?> getNameForProfile(String perfil) async {
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