import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_risk_policy.dart';
import 'package:me_lembra_ai/features/molly/services/molly_telemetria.dart';
import 'package:me_lembra_ai/features/molly/services/offline_intent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TAREFA 27 — telemetria sem conteúdo. Nada vai ao Firebase aqui: os
/// eventos são capturados por `capturarParaTeste`.
void main() {
  final capturados = <(String, Map<String, Object>)>[];

  setUp(() {
    capturados.clear();
    MollyTelemetria.capturarParaTeste = (evento, parametros) => capturados.add((evento, parametros));
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => MollyTelemetria.capturarParaTeste = null);

  group('nunca conteúdo: só valores da lista fechada', () {
    test('valores conhecidos passam; sim/não vira texto', () {
      expect(
        MollyTelemetria.limparParametros({'ferramenta': 'createReminder', 'sucesso': true, 'confirmada': false}),
        {'ferramenta': 'createReminder', 'sucesso': 'sim', 'confirmada': 'nao'},
      );
      expect(MollyTelemetria.limparParametros({'comando': 'confirmarRemedio'}), {'comando': 'confirmarRemedio'});
      expect(MollyTelemetria.limparParametros({'acao': 'criar_lembrete'}), {'acao': 'criar_lembrete'});
      expect(MollyTelemetria.limparParametros({'tipo': 'sem_ia'}), {'tipo': 'sem_ia'});
    });

    test('frase, nome de remédio, nome de familiar e chave desconhecida são descartados', () {
      expect(
        MollyTelemetria.limparParametros({
          'ferramenta': 'Ana', // um nome "simples" também não passa
          'comando': 'Losartana',
          'tipo': 'me lembra do remédio às 8',
          'acao': 'apagar_tudo',
          'texto': 'que horas são',
          'sucesso': 'sim', // texto no lugar de sim/não
        }),
        isEmpty,
      );
    });

    test('nomes de evento no formato e tamanho que o Analytics aceita', () {
      for (final e in MollyEvento.values) {
        expect(e.nome, matches(RegExp(r'^molly_[a-z_]+$')));
        expect(e.nome.length, lessThanOrEqualTo(40));
      }
    });
  });

  group('os pontos reais registram sem conteúdo', () {
    test('comando offline: o nome do comando, nunca a frase', () async {
      await OfflineIntentService.tentar('Molly, que horas são agora?');
      expect(capturados, hasLength(1));
      expect(capturados.single.$1, 'molly_offline_command');
      expect(capturados.single.$2, {'comando': 'queHoras'});
    });

    test('ferramenta executada: nome e resultado, nunca os parâmetros', () async {
      await MollyRiskPolicy.executar('getEmergencyContacts', const {});
      expect(capturados, hasLength(1));
      expect(capturados.single.$1, 'molly_tool_executed');
      expect(capturados.single.$2, {'ferramenta': 'getEmergencyContacts', 'sucesso': 'sim', 'confirmada': 'nao'});
    });

    test('ferramenta que pede confirmação não conta como executada', () async {
      await MollyRiskPolicy.executar('callFamilyMember', {'nomeFamiliar': 'Ana'});
      expect(capturados, isEmpty);
    });
  });
}
