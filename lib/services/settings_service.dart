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

  static const _kSosNumeros = 'cfg_sos_numeros';

  static Future<List<String>> getSosNumeros() async {
    final prefs = await SharedPreferences.getInstance();
    // Uma vez que a lista nova foi salva (mesmo vazia), ela é a fonte da
    // verdade — não voltar a usar o campo antigo, senão um número obsoleto
    // reaparece sempre que o usuário limpa a lista atual.
    if (prefs.containsKey(_kSosNumeros)) {
      return prefs.getStringList(_kSosNumeros) ?? [];
    }
    // migração do campo antigo (single string), só antes da 1ª gravação nova
    final antigo = prefs.getString(_kSosNumero) ?? '';
    if (antigo.trim().isNotEmpty) return [antigo.trim()];
    return [];
  }

  static Future<void> setSosNumeros(List<String> v) async =>
      (await SharedPreferences.getInstance()).setStringList(_kSosNumeros, v);

  // Compat: lê/grava o primeiro da lista
  static Future<String> getSosNumero() async {
    final lista = await getSosNumeros();
    return lista.isNotEmpty ? lista.first : '';
  }

  static Future<void> setSosNumero(String v) async {
    final lista = await getSosNumeros();
    if (lista.isEmpty) {
      await setSosNumeros([v]);
    } else {
      lista[0] = v;
      await setSosNumeros(lista);
    }
  }

  static const _kModoEscuro = 'cfg_modo_escuro';
  static Future<bool> getModoEscuro() async =>
      (await SharedPreferences.getInstance()).getBool(_kModoEscuro) ?? false;
  static Future<void> setModoEscuro(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kModoEscuro, v);

  static const _kModoProtecao = 'cfg_modo_protecao';
  static Future<bool> getModoProtecao() async =>
      (await SharedPreferences.getInstance()).getBool(_kModoProtecao) ?? false;
  static Future<void> setModoProtecao(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kModoProtecao, v);

  static const _kVolumeSos = 'cfg_volume_sos';
  static Future<bool> getVolumeSos() async =>
      (await SharedPreferences.getInstance()).getBool(_kVolumeSos) ?? false;
  static Future<void> setVolumeSos(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kVolumeSos, v);

  // TAREFA 8/9 do prompt mestre da MOLLY: consentimento explícito para a
  // memória de longo prazo ("A MOLLY pode lembrar minhas preferências?").
  // Padrão `false` — opt-in, nunca o contrário. `LongTermMemoryService`
  // confere esta flag antes de gravar qualquer coisa, além do
  // `userApproved` de cada memória individual.
  static const _kMollyMemoriaAutorizada = 'cfg_molly_memoria_autorizada';
  static Future<bool> getMollyMemoriaAutorizada() async =>
      (await SharedPreferences.getInstance()).getBool(_kMollyMemoriaAutorizada) ?? false;
  static Future<void> setMollyMemoriaAutorizada(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kMollyMemoriaAutorizada, v);

  // TAREFA 15 do prompt mestre da MOLLY: "Modo Companhia", opcional e
  // desligado por padrão — conversa mais próxima/acolhedora (contar uma
  // história, fazer companhia quando o usuário diz que está sozinho),
  // nunca substituindo acompanhamento médico ou psicológico. Sem tela
  // própria ainda (isso é a TAREFA 24, molly_settings_screen.dart).
  static const _kMollyModoCompanhia = 'cfg_molly_modo_companhia';
  static Future<bool> getMollyModoCompanhia() async =>
      (await SharedPreferences.getInstance()).getBool(_kMollyModoCompanhia) ?? false;
  static Future<void> setMollyModoCompanhia(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kMollyModoCompanhia, v);

  // TAREFA 16 do prompt mestre da MOLLY: ativação por voz ("wake word")
  // dizendo "Molly". Padrão `false` — a implementação real (Picovoice
  // Porcupine) não existe ainda (ver pesquisa em
  // `lib/features/molly/services/wake_word_service.dart`), essa flag só
  // existe pra já preparar o terreno, como o prompt mestre pede
  // explicitamente ("implementar primeiro como feature flag").
  static const _kWakeWordEnabled = 'cfg_wake_word_enabled';
  static Future<bool> getWakeWordEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_kWakeWordEnabled) ?? false;
  static Future<void> setWakeWordEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kWakeWordEnabled, v);

  // TAREFA 18 do prompt mestre da MOLLY: contagem regressiva cancelável
  // antes de disparar o SOS quando a MOLLY reconhece uma frase de
  // "possível emergência" (não o gatilho explícito "SOCORRO", que
  // continua disparando na hora). Mesmo espírito do countdown do botão
  // SOS manual (TASK-25, 5s), mas configurável por texto do prompt
  // mestre ("contagem curta configurável"). Sem tela pra mudar ainda
  // (isso é a TAREFA 24).
  static const _kSosCountdownSegundos = 'cfg_sos_countdown_segundos';
  static Future<int> getSosCountdownSegundos() async =>
      (await SharedPreferences.getInstance()).getInt(_kSosCountdownSegundos) ?? 5;
  static Future<void> setSosCountdownSegundos(int v) async =>
      (await SharedPreferences.getInstance()).setInt(_kSosCountdownSegundos, v);
}
