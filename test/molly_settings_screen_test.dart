import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/screens/molly_settings_screen.dart';
import 'package:me_lembra_ai/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TAREFA 24 (Configurações da Molly). Só SharedPreferences (mockável) —
/// não toca nos interruptores de velocidade da voz nem de "Bom dia às 8h",
/// que chamam plugins nativos (TTS / notificações) sem mock no projeto.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildSubject() => const MaterialApp(home: MollySettingsScreen());

  // Tela alta o bastante pra ListView montar todos os itens de uma vez.
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 4000);
    view.devicePixelRatio = 1.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  bool valorDe(WidgetTester tester, String titulo) =>
      tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, titulo)).value;

  Future<void> tocar(WidgetTester tester, String titulo) async {
    final alvo = find.widgetWithText(SwitchListTile, titulo);
    await tester.ensureVisible(alvo);
    await tester.tap(alvo);
    await tester.pumpAndSettle();
  }

  testWidgets('padroes = comportamento de antes da tela existir', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Configurações da Molly'), findsOneWidget);
    expect(valorDe(tester, 'Molly ativa'), isTrue);
    expect(valorDe(tester, 'Resposta por voz'), isTrue);
    expect(valorDe(tester, 'Memória'), isFalse);
    expect(valorDe(tester, 'Modo companhia'), isFalse);
    expect(valorDe(tester, 'Avisos da Molly'), isTrue);
    expect(valorDe(tester, 'Bom dia às 8h'), isTrue);
  });

  testWidgets('cada interruptor grava na hora em SettingsService', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tocar(tester, 'Molly ativa');
    await tocar(tester, 'Resposta por voz');
    await tocar(tester, 'Memória');
    await tocar(tester, 'Modo companhia');
    await tocar(tester, 'Avisos da Molly');

    expect(await SettingsService.getMollyAtiva(), isFalse);
    expect(await SettingsService.getMollyRespostaPorVoz(), isFalse);
    expect(await SettingsService.getMollyMemoriaAutorizada(), isTrue);
    expect(await SettingsService.getMollyModoCompanhia(), isTrue);
    expect(await SettingsService.getMollyAvisosProativos(), isFalse);
  });

  testWidgets('carrega valores ja salvos', (tester) async {
    SharedPreferences.setMockInitialValues({
      'cfg_molly_ativa': false,
      'cfg_molly_modo_companhia': true,
    });
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(valorDe(tester, 'Molly ativa'), isFalse);
    expect(valorDe(tester, 'Modo companhia'), isTrue);
  });
}
