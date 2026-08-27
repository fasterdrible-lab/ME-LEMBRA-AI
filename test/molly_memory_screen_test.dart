import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/screens/molly_memory_screen.dart';
import 'package:me_lembra_ai/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/firebase_core_mocks.dart';

/// Testes de estrutura da TAREFA 9 ("O que a Molly lembra"). Sem usuário
/// logado no ambiente de teste, `LongTermMemoryService.stream()` devolve
/// uma lista vazia (não trava esperando dado) — dá pra testar o estado
/// "nenhuma memória guardada" e o interruptor de autorização de ponta a
/// ponta, sem precisar de mocks de Firestore.
void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildSubject() => const MaterialApp(home: MollyMemoryScreen());

  group('MollyMemoryScreen — estrutura', () {
    testWidgets('exibe titulo e o interruptor de autorizacao, desligado por padrao', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('O que a Molly lembra'), findsOneWidget);
      expect(find.text('A Molly pode lembrar minhas preferências?'), findsOneWidget);
      final interruptor = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(interruptor.value, isFalse);
    });

    testWidgets('mostra mensagem quando nao ha memorias guardadas', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('A Molly ainda não guardou nenhuma preferência sua.'), findsOneWidget);
    });

    testWidgets('botao Apagar tudo esta sempre presente', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Apagar tudo'), findsOneWidget);
    });

    testWidgets('ligar o interruptor autoriza e persiste em SettingsService', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(await SettingsService.getMollyMemoriaAutorizada(), isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final interruptor = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(interruptor.value, isTrue);
      expect(await SettingsService.getMollyMemoriaAutorizada(), isTrue);
    });
  });
}
