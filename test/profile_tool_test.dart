import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/offline_intent_service.dart';
import 'package:me_lembra_ai/features/molly/tools/profile_tool.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Quem é meu contato de emergência?" — critério de aceitação da TAREFA 37
/// do prompt mestre. A fala é pura ([ProfileTool.falaContatosEmergencia]);
/// o caminho completo via `OfflineIntentService.tentar` só toca
/// SharedPreferences (mockável), nunca Firebase.
void main() {
  group('ProfileTool.numeroFalado', () {
    test('celular com DDD vira grupos de digitos separados', () {
      expect(ProfileTool.numeroFalado('11987654321'), '1 1, 9 8 7 6 5, 4 3 2 1');
    });

    test('ignora +55 e formatacao', () {
      expect(ProfileTool.numeroFalado('+55 (11) 98765-4321'), '1 1, 9 8 7 6 5, 4 3 2 1');
    });

    test('fixo com DDD (10 digitos)', () {
      expect(ProfileTool.numeroFalado('1132654321'), '1 1, 3 2 6 5, 4 3 2 1');
    });
  });

  group('ProfileTool.falaContatosEmergencia', () {
    test('nenhum contato orienta onde cadastrar', () {
      final fala = ProfileTool.falaContatosEmergencia(const [], sosAtivo: true);
      expect(fala, contains('ainda não cadastrou'));
      expect(fala, contains('Botão de Pânico'));
    });

    test('um contato fala o numero', () {
      expect(
        ProfileTool.falaContatosEmergencia(const ['11987654321'], sosAtivo: true),
        'Seu contato de emergência é o número 1 1, 9 8 7 6 5, 4 3 2 1.',
      );
    });

    test('varios contatos: diz quantos e destaca so o primeiro (respostas curtas)', () {
      final fala = ProfileTool.falaContatosEmergencia(
        const ['11987654321', '11911112222', '1132654321'],
        sosAtivo: true,
      );
      expect(fala, startsWith('Você tem 3 contatos de emergência.'));
      expect(fala, contains('1 1, 9 8 7 6 5, 4 3 2 1'));
      expect(fala, isNot(contains('1 1 1 1')));
    });

    test('avisa quando o botao SOS esta desligado', () {
      final fala = ProfileTool.falaContatosEmergencia(const ['11987654321'], sosAtivo: false);
      expect(fala, contains('o botão SOS está desligado'));
    });

    test('entradas vazias nao contam como contato', () {
      final fala = ProfileTool.falaContatosEmergencia(const ['', '  '], sosAtivo: true);
      expect(fala, contains('ainda não cadastrou'));
    });
  });

  group('OfflineIntentService.tentar — contato de emergencia', () {
    test('funciona sem IA e sem Firebase, lendo so as preferencias locais', () async {
      SharedPreferences.setMockInitialValues({});
      final resultado = await OfflineIntentService.tentar('Molly, quem é meu contato de emergência?');
      expect(resultado, isNotNull);
      expect(resultado!.sucesso, isTrue);
      expect(resultado.acao, 'getEmergencyContacts');
      expect(resultado.precisaConfirmacao, isFalse);
    });
  });
}
