import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/screens/molly_screen.dart';

import 'support/firebase_core_mocks.dart';

/// Testes de estrutura da TAREFA 6 (tela da MOLLY) — só a UI estática,
/// sem tocar o microfone: `speech_to_text` é um plugin de plataforma sem
/// mock neste projeto (mesmo gap documentado para `molly_voice_service.dart`
/// na sessão anterior), então nenhum teste aqui toca o botão de
/// microfone. Cobre só o que a TAREFA 6 pede: título, indicador de estado,
/// botão de microfone grande e acessível, e o botão SOS sempre visível.
void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Widget buildSubject() => const MaterialApp(home: MollyScreen());

  group('MollyScreen — estrutura', () {
    testWidgets('exibe titulo MOLLY, indicador de estado ocioso e mensagem inicial', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('MOLLY'), findsOneWidget);
      expect(find.text('Toque no microfone para falar'), findsOneWidget);
      expect(find.text('Como posso ajudar?'), findsOneWidget);
    });

    testWidgets('botao de microfone grande esta presente e acessivel', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.bySemanticsLabel('Falar com a Molly'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('botao SOS esta sempre visivel', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.widgetWithText(ElevatedButton, 'SOS'), findsOneWidget);
    });

    testWidgets('secao "Hoje" existe para listar lembretes do dia', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Hoje'), findsOneWidget);
    });
  });
}
