import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/family_member.dart';
import '../../../models/reminder.dart';
import '../../../services/family_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/reminder_service.dart';

/// Cache da MOLLY (TAREFA 26 do prompt mestre): perfil, familiares,
/// lembretes e contexto mínimo continuam disponíveis sem internet.
///
/// O Firestore já guarda no aparelho uma cópia de tudo que leu (e das
/// escritas ainda não enviadas) — esta classe não duplica esses dados, só
/// os usa quando a rede não ajuda. Dois problemas reais que ela resolve:
///
/// 1. **Leitura que demora.** Com Wi-Fi conectado mas sem internet de
///    verdade, `get()` espera ~10 s antes de cair na cópia local, e a Molly
///    faz várias leituras por turno. Aqui cada leitura tem [prazoLeitura];
///    estourou, usa a cópia do aparelho e, por [pausaSemRede], nem tenta a
///    rede de novo (as próximas leituras do mesmo turno saem na hora).
/// 2. **Escrita que nunca termina.** `await add()/update()` só completa
///    quando o servidor confirma — sem internet, a Molly ficava presa em
///    "Pensando...". [escrever] espera no máximo [prazoEscrita]; depois
///    disso a escrita continua guardada no aparelho e o Firestore envia
///    sozinho quando a conexão voltar (inclusive depois de fechar o app).
///
/// Configurações já são locais (`SettingsService`, SharedPreferences) e não
/// precisam de nada daqui. Perfil e nome ganham uma cópia própria
/// ([_chavePerfil]/[_chaveNome]) porque o nome lido do Firestore nunca era
/// salvo no aparelho.
class MollyCache {
  static const prazoLeitura = Duration(seconds: 3);
  static const prazoEscrita = Duration(seconds: 3);
  static const pausaSemRede = Duration(seconds: 30);

  static const _chavePerfil = 'molly_cache_perfil';
  static const _chaveNome = 'molly_cache_nome';

  @visibleForTesting
  static DateTime Function() relogio = DateTime.now;

  static DateTime? _semRedeAte;

  /// A última leitura/escrita indicou que não há internet (vale por
  /// [pausaSemRede]).
  static bool get semRede {
    final ate = _semRedeAte;
    return ate != null && relogio().isBefore(ate);
  }

  @visibleForTesting
  static void reiniciar() => _semRedeAte = null;

  // ── Dados ────────────────────────────────────────────────────────────

  static Future<List<Reminder>> lembretes() => lerComReserva<List<Reminder>>(
        rede: ReminderService.getAll,
        local: ReminderService.getAllDoAparelho,
        vazio: const [],
      );

  static Future<List<FamilyMember>> familiares() => lerComReserva<List<FamilyMember>>(
        rede: () => FamilyService.stream().first,
        local: FamilyService.listarDoAparelho,
        vazio: const [],
      );

  static Future<String?> perfil() => lerComReserva<String?>(
        rede: () async {
          final p = await ProfileService.getProfile();
          if (p != null) await _guardar(_chavePerfil, p);
          return p;
        },
        local: () async => await _lerGuardado(_chavePerfil) ?? await ProfileService.getProfileLocal(),
        vazio: null,
      );

  static Future<String?> nome() => lerComReserva<String?>(
        rede: () async {
          final n = await ProfileService.getNameForSelectedProfile();
          if (n != null && n.trim().isNotEmpty) await _guardar(_chaveNome, n);
          return n;
        },
        local: () => _lerGuardado(_chaveNome),
        vazio: null,
      );

  // ── Mecanismo (puro, testável sem Firebase) ──────────────────────────

  /// Tenta [rede] com prazo; se estourar ou falhar, usa [local]; se esse
  /// também falhar, [vazio]. Nunca lança exceção.
  static Future<T> lerComReserva<T>({
    required Future<T> Function() rede,
    required Future<T> Function() local,
    required T vazio,
    Duration prazo = prazoLeitura,
  }) async {
    if (!semRede) {
      try {
        final valor = await rede().timeout(prazo);
        _semRedeAte = null;
        return valor;
      } on TimeoutException {
        _marcarSemRede();
      } catch (_) {
        // Erro de verdade (permissão, sem cópia local...): tenta o aparelho.
      }
    }
    try {
      return await local();
    } catch (_) {
      return vazio;
    }
  }

  /// Faz a escrita e espera a confirmação do servidor por no máximo
  /// [prazo]. `true` = enviada; `false` = sem internet, ficou guardada no
  /// aparelho e vai sozinha quando a conexão voltar. Um erro de verdade
  /// (antes do prazo) é repassado a quem chamou.
  static Future<bool> escrever(Future<void> Function() escrita, {Duration prazo = prazoEscrita}) async {
    try {
      await escrita().timeout(prazo);
      _semRedeAte = null;
      return true;
    } on TimeoutException {
      _marcarSemRede();
      return false;
    }
  }

  static void _marcarSemRede() => _semRedeAte = relogio().add(pausaSemRede);

  static Future<void> _guardar(String chave, String valor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(chave, valor);
    } catch (_) {}
  }

  static Future<String?> _lerGuardado(String chave) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(chave);
  }
}
