import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/login_screen.dart';

void main() {
  Widget buildSubject() => const MaterialApp(home: LoginScreen());

  group('LoginScreen — estrutura', () {
    testWidgets('exibe campos de e-mail e senha', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('exibe titulo, botao Entrar e botao Criar conta', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('ME LEMBRA AI'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Criar conta'), findsOneWidget);
    });

    testWidgets('exibe link Esqueci minha senha', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Esqueci minha senha'), findsOneWidget);
    });
  });

  group('LoginScreen — validacao', () {
    testWidgets('campos vazios mostram snackbar de erro', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pump();
      expect(find.text('Preencha e-mail e senha.'), findsOneWidget);
    });

    testWidgets('redefinir senha com e-mail vazio mostra snackbar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pump();
      expect(
        find.text('Digite seu e-mail para redefinir a senha.'),
        findsOneWidget,
      );
    });
  });

  group('LoginScreen — navegacao', () {
    testWidgets('botao Criar conta abre RegisterScreen', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.widgetWithText(OutlinedButton, 'Criar conta'));
      await tester.pumpAndSettle();
      expect(find.text('Criar conta'), findsAtLeastNWidgets(1));
    });
  });
}
