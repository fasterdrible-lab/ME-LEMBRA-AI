import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const _key = 'perfil';

  // salvar perfil
  static Future<void> saveProfile(String perfil) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, perfil);
  }

  // pegar perfil
  static Future<String?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }
}