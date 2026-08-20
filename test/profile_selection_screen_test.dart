import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/profile_selection_screen.dart';
import 'package:me_lembra_ai/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/firebase_core_mocks.dart';

/// Regressao do BUG-001: cuidadores recem-cadastrados (login ou cadastro
/// -> selecao de perfil) nunca tinham o fcmToken salvo na primeira sessao,
/// porque FcmService.init() so era chamado em HomeScreen.initState() e o
/// fluxo de login/cadastro vai direto de ProfileSelectionScreen para a tela
/// do perfil, sem nunca passar por HomeScreen.
void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FcmService.debugOnInitCalled = null;
  });

  tearDown(() {
    FcmService.debugOnInitCalled = null;
  });

  Widget buildSubject() {
    return MaterialApp(
      home: const ProfileSelectionScreen(),
      routes: {
        '/elderly': (_) => const Scaffold(body: Text('elderly')),
        '/adult': (_) => const Scaffold(body: Text('adult')),
        '/child': (_) => const Scaffold(body: Text('child')),
        '/family': (_) => const Scaffold(body: Text('family')),
      },
    );
  }

  testWidgets(
    'BUG-001: entrar em um perfil dispara FcmService.init() '
    '(sem passar por HomeScreen)',
    (tester) async {
      var initCalled = false;
      FcmService.debugOnInitCalled = () => initCalled = true;

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      // "Adulto" ja fica visivel sem scroll no viewport padrao do teste.
      await tester.tap(find.text('Adulto'));
      await tester.pumpAndSettle();

      // Sem nome salvo ainda, o dialogo "Como posso te chamar?" aparece;
      // cancelar simula o usuario nao preenchendo o nome, mas o app deve
      // navegar para a tela do perfil (e inicializar o FCM) do mesmo jeito.
      if (find.text('Cancelar').evaluate().isNotEmpty) {
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
      }

      expect(find.text('adult'), findsOneWidget);
      expect(
        initCalled,
        isTrue,
        reason: 'FcmService.init() deve ser chamado ao entrar em um perfil, '
            'pois o fluxo de login/cadastro nunca constroi a HomeScreen '
            'nesta sessao (ver BUG-001).',
      );
    },
  );
}
