import 'package:shared_preferences/shared_preferences.dart';

/// Persistência local das preferências do usuário (SharedPreferences).
class SettingsService {
  static const _kLocalizacao = 'cfg_localizacao';
  static const _kSos = 'cfg_sos';
  static const _kChat = 'cfg_chat';
  static const _kNotificacoes = 'cfg_notificacoes';
  static const _kSosNumero = 'cfg_sos_numero';

  static Future<bool> getLocalizacao() async =>
      (await SharedPreferences.getInstance()).getBool(_kLocalizacao) ?? false;
  static Future<void> setLocalizacao(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kLocalizacao, v);

  static Future<bool> getSos() async =>
      (await SharedPreferences.getInstance()).getBool(_kSos) ?? false;
  static Future<void> setSos(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kSos, v);

  static Future<bool> getChat() async =>
      (await SharedPreferences.getInstance()).getBool(_kChat) ?? false;
  static Future<void> setChat(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kChat, v);

  static Future<bool> getNotificacoes() async =>
      (await SharedPreferences.getInstance()).getBool(_kNotificacoes) ?? true;
  static Future<void> setNotificacoes(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kNotificacoes, v);

  static Future<String> getSosNumero() async =>
      (await SharedPreferences.getInstance()).getString(_kSosNumero) ?? '';
  static Future<void> setSosNumero(String v) async =>
      (await SharedPreferences.getInstance()).setString(_kSosNumero, v);

  static const _kModoEscuro = 'cfg_modo_escuro';
  static Future<bool> getModoEscuro() async =>
      (await SharedPreferences.getInstance()).getBool(_kModoEscuro) ?? false;
  static Future<void> setModoEscuro(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kModoEscuro, v);
}
