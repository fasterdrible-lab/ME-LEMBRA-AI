import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/wake_word_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Testes puros da TAREFA 16 (preparação da wake word) — sem Firebase,
/// sem plugins nativos (não existe integração real ainda, só a
/// abstração e o stub indisponível).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UnavailableWakeWordService', () {
    test('comeca indisponivel e nunca reporta sucesso ao iniciar', () async {
      final service = UnavailableWakeWordService();
      expect(service.estado.value, WakeWordState.unavailable);

      var detectou = false;
      final iniciou = await service.iniciar(aoDetectarPalavraChave: () => detectou = true);

      expect(iniciou, isFalse);
      expect(detectou, isFalse);
      expect(service.estado.value, WakeWordState.unavailable);

      service.dispose();
    });

    test('parar nao lanca mesmo sem nunca ter iniciado', () async {
      final service = UnavailableWakeWordService();
      await service.parar();
      service.dispose();
    });
  });

  group('WakeWordService.criar', () {
    test('sempre devolve a implementacao indisponivel, com a flag desligada', () async {
      final service = await WakeWordService.criar();
      expect(service, isA<UnavailableWakeWordService>());
      expect(service.estado.value, WakeWordState.unavailable);
    });

    test('sempre devolve a implementacao indisponivel, mesmo com a flag ligada', () async {
      SharedPreferences.setMockInitialValues({'cfg_wake_word_enabled': true});
      final service = await WakeWordService.criar();
      expect(service, isA<UnavailableWakeWordService>());
    });
  });
}
